import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool wifiEnabled: false
    property var wifiNetworks: []
    property var ethernetDevices: []
    property string primaryIp: ""

    signal error(string message)

    function refresh() {
        wifiStateProcess.exec([
            "nmcli",
            "-t",
            "-f",
            "WIFI",
            "general"
        ])

        wifiListProcess.exec([
            "nmcli",
            "-t",
            "--escape",
            "yes",
            "-f",
            "IN-USE,SSID,SIGNAL,SECURITY",
            "device",
            "wifi",
            "list",
            "--rescan",
            "yes"
        ])

        ethernetProcess.exec([
            "nmcli",
            "-t",
            "-f",
            "DEVICE,TYPE,STATE,CONNECTION",
            "device",
            "status"
        ])

        primaryIpProcess.exec([
            "sh",
            "-c",
            "ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") {print $(i+1); exit}}'"
        ])
    }

    function setWifiEnabled(enabled) {
        wifiToggleProcess.exec([
            "nmcli",
            "radio",
            "wifi",
            enabled ? "on" : "off"
        ])
    }

    function connectWifi(ssid, password) {
        if (!ssid)
            return

        const args = [
            "nmcli",
            "device",
            "wifi",
            "connect",
            ssid
        ]

        if (password)
            args.push("password", password)

        wifiConnectProcess.exec(args)
    }

    function connectDevice(device) {
        deviceProcess.exec([
            "nmcli",
            "device",
            "connect",
            device
        ])
    }

    function disconnectDevice(device) {
        deviceProcess.exec([
            "nmcli",
            "device",
            "disconnect",
            device
        ])
    }

    property Process wifiStateProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled =
                    text.trim().toLowerCase() === "enabled"
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[network] wifi state:", text.trim())
            }
        }
    }

    property Process wifiListProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const networks = []
                const seen = {}

                for (const line of text.trim().split("\n")) {
                    if (!line)
                        continue

                    const parts = line.split(":")

                    if (parts.length < 4)
                        continue

                    const active = parts[0] === "*"
                    const ssid = parts[1]

                    if (!ssid || seen[ssid])
                        continue

                    seen[ssid] = true

                    networks.push({
                        active: active,
                        ssid: ssid,
                        signal: parseInt(parts[2]) || 0,
                        security: parts.slice(3).join(":")
                    })
                }

                networks.sort((a, b) => {
                    if (a.active !== b.active)
                        return a.active ? -1 : 1

                    return b.signal - a.signal
                })

                root.wifiNetworks = networks
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[network] wifi list:", text.trim())
            }
        }
    }

    property Process ethernetProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const devices = []

                for (const line of text.trim().split("\n")) {
                    if (!line)
                        continue

                    const parts = line.split(":")

                    if (parts.length < 4)
                        continue

                    if (parts[1] !== "ethernet")
                        continue

                    devices.push({
                        device: parts[0],
                        state: parts[2],
                        connection: parts.slice(3).join(":")
                    })
                }

                root.ethernetDevices = devices
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[network] ethernet:", text.trim())
            }
        }
    }

    property Process primaryIpProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.primaryIp = text.trim()
            }
        }
    }

    property Process wifiToggleProcess: Process {
        onExited: root.refresh()
    }

    property Process wifiConnectProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    console.warn(
                        "[network] wifi connect:",
                        text.trim()
                    )

                    root.error(text.trim())
                }
            }
        }

        onExited: root.refresh()
    }

    property Process deviceProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.error(text.trim())
            }
        }

        onExited: root.refresh()
    }

    Component.onCompleted: refresh()
}
