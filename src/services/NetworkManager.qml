import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

QtObject {
    id: root

    // Native reactive Quickshell models.
    readonly property var devices: Networking.devices

    readonly property var wifiDevices:
        Networking.devices.values.filter(
            device => device.type === DeviceType.Wifi
        )

    readonly property var ethernetDevices:
        Networking.devices.values.filter(
            device => device.type === DeviceType.Wired
        )

    readonly property var wifiDevice:
        wifiDevices.length > 0
        ? wifiDevices[0]
        : null

    readonly property bool wifiEnabled:
        Networking.wifiEnabled

    readonly property bool wifiHardwareEnabled:
        Networking.wifiHardwareEnabled

    readonly property var wifiNetworks:
        wifiDevice !== null
        ? wifiDevice.networks.values
        : []

    readonly property var knownWifiNetworks:
        wifiNetworks.filter(
            network => network.known
        )

    property string primaryIp: ""

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled
    }

    function setWifiScanning(enabled) {
        if (wifiDevice !== null)
            wifiDevice.scannerEnabled = enabled
    }

    function connectWifi(network) {
        if (network === null || network === undefined)
            return

        network.connect()
    }

    function connectWifiWithPsk(network, psk) {
        if (network === null || network === undefined)
            return

        network.connectWithPsk(psk)
    }

    function disconnectWifi(network) {
        if (network === null || network === undefined)
            return

        network.disconnect()
    }

    function setEthernetEnabled(device, enabled) {
        if (device === null || device === undefined)
            return

        if (enabled) {
            device.autoconnect = true

            if (
                device.network !== null
                && !device.network.connected
            ) {
                device.network.connect()
            }
        } else {
            device.autoconnect = false
            device.disconnect()
        }
    }

    function refreshPrimaryIp() {
        primaryIpProcess.exec([
            "sh",
            "-c",
            "ip -4 route get 1.1.1.1 2>/dev/null | "
            + "awk '{for(i=1;i<=NF;i++) "
            + "if($i==\"src\") {print $(i+1); exit}}'"
        ])
    }

    // Quickshell.Networking is reactive, so no polling or nmcli monitor is needed.
    // Scanner is enabled while this service exists so APs stay current.
    Component.onCompleted: {
        setWifiScanning(true)
        refreshPrimaryIp()
    }

    property Process primaryIpProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.primaryIp = text.trim()
            }
        }
    }

    // Re-evaluate PRIMARYIP occasionally because the native QS 0.3 API does
    // not expose IPv4 addresses. This is only for the Web access QR URL.
    property Timer primaryIpTimer: Timer {
        interval: 5000
        repeat: true
        running: true

        onTriggered: root.refreshPrimaryIp()
    }
}
