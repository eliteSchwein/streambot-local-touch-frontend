#!/usr/bin/env python3
import fcntl
import glob
import os
import struct
import subprocess
import sys
import threading
import time

KEY_POWER = 116
EV_KEY = 0x01
EVIOCGRAB = 0x40044590
DEBOUNCE_SECONDS = 0.4

# Native Linux input_event:
# struct timeval { long tv_sec; long tv_usec; };
# unsigned short type, code; signed int value.
EVENT_STRUCT = struct.Struct("@llHHi")
BITS_PER_WORD = struct.calcsize("@L") * 8


def log(message):
    print(f"[power-key] {message}", flush=True)


def supports_key_power(path):
    event_name = os.path.basename(path)
    cap_path = f"/sys/class/input/{event_name}/device/capabilities/key"

    try:
        raw = open(cap_path, "r", encoding="utf-8").read().strip()
    except OSError:
        return False

    words = raw.split()
    word_index = KEY_POWER // BITS_PER_WORD
    bit_index = KEY_POWER % BITS_PER_WORD

    if word_index >= len(words):
        return False

    # sysfs prints the highest word first. This matches the old Rust code.
    word = words[-1 - word_index]

    try:
        value = int(word, 16)
    except ValueError:
        return False

    return ((value >> bit_index) & 1) == 1


def open_power_menu():
    env = os.environ.copy()

    command = [
        "/usr/bin/qs",
        "--path",
        "/usr/share/streambot-touch",
        "ipc",
        "call",
        "streambot-touch",
        "openPowerMenu",
    ]

    try:
        result = subprocess.run(
            command,
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            timeout=2,
        )

        if result.returncode != 0:
            err = (result.stderr or "").strip()
            log(f"IPC failed ({result.returncode}): {err}")
    except Exception as exc:
        log(f"IPC failed: {exc}")


def listen_device(path):
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError as exc:
        log(f"failed to open {path}: {exc}")
        return

    try:
        fcntl.ioctl(fd, EVIOCGRAB, 1)
    except OSError as exc:
        log(f"failed to grab {path}: {exc}")
        os.close(fd)
        return

    log(f"intercepting KEY_POWER on {path}")

    last_press = 0.0

    try:
        while True:
            data = os.read(fd, EVENT_STRUCT.size)

            if len(data) != EVENT_STRUCT.size:
                continue

            _sec, _usec, event_type, code, value = EVENT_STRUCT.unpack(data)

            if event_type != EV_KEY or code != KEY_POWER or value != 1:
                continue

            now = time.monotonic()

            if now - last_press < DEBOUNCE_SECONDS:
                continue

            last_press = now
            log("KEY_POWER pressed")
            open_power_menu()
    except OSError as exc:
        log(f"read failed on {path}: {exc}")
    finally:
        try:
            fcntl.ioctl(fd, EVIOCGRAB, 0)
        except OSError:
            pass

        os.close(fd)


def main():
    devices = [
        path
        for path in sorted(glob.glob("/dev/input/event*"))
        if supports_key_power(path)
    ]

    if not devices:
        log("no KEY_POWER input devices found")
        return 1

    threads = []

    for path in devices:
        thread = threading.Thread(
            target=listen_device,
            args=(path,),
            daemon=False,
        )
        thread.start()
        threads.append(thread)

    for thread in threads:
        thread.join()

    return 0


if __name__ == "__main__":
    sys.exit(main())
