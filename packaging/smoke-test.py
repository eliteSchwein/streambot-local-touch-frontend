"""Launch the packaged kiosk on Xvfb and exercise backend startup and reconnect."""
import asyncio
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile

from aiohttp import web


async def smoke_test(binary, config_dir, display):
    ready = asyncio.Event()
    sessions = 0
    cava_connected = asyncio.Event()

    async def status(request):
        return web.json_response({"data": {"ready": True, "bootup_stage": "finished"}})

    async def stream(request):
        nonlocal sessions
        socket = web.WebSocketResponse()
        await socket.prepare(request)
        register = await socket.receive_json()
        assert register["method"] == "register_endpoints"
        assert "notify_audio_outputs_update" in register["params"]
        status_request = await socket.receive_json()
        assert status_request["params"] == {"action": "status"}
        await socket.send_json({"id": status_request["id"], "method": "result_speedtest",
                                "params": {"speedtest": {"stage": "finished", "ping_ms": 5}}})
        await socket.send_json({"method": "notify_music_update", "params": {"title": "Smoke test"}})
        sessions += 1
        if sessions == 2:
            ready.set()
            await socket.receive()
        await socket.close()
        return socket

    async def cava(request):
        socket = web.WebSocketResponse()
        await socket.prepare(request)
        await socket.send_json({"params": {"target": "music_preview", "raw": "10;20;30;40;50;"}})
        cava_connected.set()
        await socket.receive()
        return socket

    server = web.Application()
    server.add_routes([web.get("/api/status", status), web.get("/", stream),
                       web.get("/cava/music_preview", cava)])
    runner = web.AppRunner(server)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    port = runner.addresses[0][1]
    config = config_dir / "connection.cfg"
    config.write_text(f"[connection]\nhost: 127.0.0.1\nrestPort: {port}\nwebsocketPort: {port}\n")
    env = dict(os.environ, DISPLAY=display, XDG_CONFIG_HOME=str(config_dir),
               SLINT_BACKEND="winit-software", WINIT_UNIX_BACKEND="x11")
    env.pop("WAYLAND_DISPLAY", None)
    process = await asyncio.create_subprocess_exec(binary, "--app-config", str(config), env=env)
    try:
        await asyncio.wait_for(asyncio.gather(ready.wait(), cava_connected.wait()), timeout=20)
        process.send_signal(signal.SIGUSR1)
        await asyncio.sleep(0.25)
        assert process.returncode is None, "kiosk exited while opening the power menu"
    finally:
        if process.returncode is None:
            process.terminate()
        await process.wait()
        await runner.cleanup()


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as temp:
        with subprocess.Popen(["Xvfb", "-displayfd", "1", "-screen", "0", "800x480x24",
                               "-nolisten", "tcp"], stdout=subprocess.PIPE, text=True) as xserver:
            try:
                display = xserver.stdout.readline().strip()
                if not display.isdecimal():
                    raise RuntimeError("Xvfb failed to create a display")
                asyncio.run(smoke_test(sys.argv[1], Path(temp), ":" + display))
            finally:
                xserver.terminate()
