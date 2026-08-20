import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

import "md3"
import "../dialogs"

Item {
    id: root

    required property var i18n
    required property var config
    required property var network

    property bool open: false

    anchors.fill: parent
    z: 1000

    readonly property string runtimeDir:
        Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    readonly property string qrPath:
        runtimeDir + "/streambot-touch-commander.png"

    readonly property string commanderUrl:
        network.primaryIp !== ""
        ? "http://" + network.primaryIp + ":"
            + config.restPort + "/commander"
        : ""

    function refreshQr() {
        if (commanderUrl === "")
            return

        qrProcess.exec([
            "qrencode",
            "-o",
            qrPath,
            "-s",
            "8",
            "-m",
            "1",
            commanderUrl
        ])
    }

    onCommanderUrlChanged: refreshQr()

    onOpenChanged: {
        network.setWifiScanning(open)

        if (open) {
            network.refreshPrimaryIp()
            refreshQr()
        }
    }

    property Process qrProcess: Process {
        onExited: code => {
            if (code === 0)
                qrImage.revision++
            else
                console.warn("[qr] qrencode failed:", code)
        }
    }

    // Android-like pull-down activation area.
    Item {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        height: root.open ? 0 : 44
        z: 20

        DragHandler {
            target: null

            property real startY: 0

            onActiveChanged: {
                if (active) {
                    startY = centroid.position.y
                } else if (
                    centroid.position.y - startY > 36
                ) {
                    root.open = true
                }
            }
        }

        TapHandler {
            onTapped: root.open = true
        }
    }

    Rectangle {
        width: parent.width
        height: parent.height

        y: root.open ? 0 : -height

        color: Md3Theme.background

        Behavior on y {
            NumberAnimation {
                duration: 210
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // LEFT
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight:
                            Math.max(115, ethernetColumn.implicitHeight + 28)

                        title: root.i18n.text("ethernet")

                        ColumnLayout {
                            id: ethernetColumn

                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: root.network.ethernetDevices

                                RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: modelData.name
                                            color: Md3Theme.surfaceContent
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            text:
                                                modelData.connected
                                                ? root.i18n.text("connected")
                                                : root.i18n.text("disconnected")

                                            color:
                                                modelData.connected
                                                ? Md3Theme.success
                                                : Md3Theme.surfaceVariantContent

                                            font.pixelSize: 11
                                        }
                                    }

                                    Md3Switch {
                                        checked:
                                            modelData.connected
                                            || modelData.autoconnect

                                        onClicked: {
                                            root.network.setEthernetEnabled(
                                                modelData,
                                                !(
                                                    modelData.connected
                                                    || modelData.autoconnect
                                                )
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        title: root.i18n.text("wifi")

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true

                                text:
                                    !root.network.wifiHardwareEnabled
                                    ? root.i18n.text("disabled")
                                    : (
                                        root.network.wifiEnabled
                                        ? root.i18n.text("enabled")
                                        : root.i18n.text("disabled")
                                    )

                                color: Md3Theme.surfaceVariantContent
                                font.pixelSize: 12
                            }

                            Md3Switch {
                                checked: root.network.wifiEnabled

                                onClicked: {
                                    root.network.setWifiEnabled(
                                        !root.network.wifiEnabled
                                    )
                                }
                            }
                        }

                        ListView {
                            id: wifiList

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            clip: true
                            spacing: 5

                            model: root.network.wifiNetworks

                            delegate: Rectangle {
                                required property var modelData

                                width: wifiList.width
                                height: 46

                                radius: Md3Theme.radiusMedium

                                color:
                                    modelData.connected
                                    ? Md3Theme.surfaceContainerHigh
                                    : Md3Theme.surfaceContainerHighest

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 9
                                    spacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true

                                            text: modelData.name
                                            color: Md3Theme.surfaceContent

                                            font.pixelSize: 12
                                            font.weight:
                                                modelData.connected
                                                ? Font.DemiBold
                                                : Font.Normal

                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true

                                            text:
                                                modelData.known
                                                ? root.i18n.text("known")
                                                : (
                                                    modelData.security
                                                    === WifiSecurityType.Open
                                                    ? root.i18n.text("open_network")
                                                    : root.i18n.text("secured")
                                                )

                                            color: Md3Theme.surfaceVariantContent
                                            font.pixelSize: 9
                                        }
                                    }

                                    Text {
                                        text:
                                            Math.round(
                                                modelData.signalStrength * 100
                                            )
                                            + "%"

                                        color: Md3Theme.surfaceVariantContent
                                        font.pixelSize: 10
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        if (modelData.connected) {
                                            modelData.disconnect()
                                            return
                                        }

                                        // Known networks use their saved NM profile.
                                        if (modelData.known) {
                                            modelData.connect()
                                            return
                                        }

                                        // Open networks don't require a dialog.
                                        if (
                                            modelData.security
                                            === WifiSecurityType.Open
                                        ) {
                                            modelData.connect()
                                            return
                                        }

                                        wifiDialog.network = modelData
                                        wifiDialog.open()
                                    }
                                }
                            }
                        }
                    }
                }

                // RIGHT
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 118

                        title: root.i18n.text("language")

                        Md3Select {
                            Layout.fillWidth: true

                            model: [
                                root.i18n.text("english"),
                                root.i18n.text("german")
                            ]

                            currentIndex:
                                root.config.language === "de"
                                ? 1
                                : 0

                            onActivated: index => {
                                root.config.setLanguage(
                                    index === 1 ? "de" : "en"
                                )
                            }
                        }
                    }

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        title: root.i18n.text("web_access")

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Image {
                                    id: qrImage

                                    property int revision: 0

                                    anchors.centerIn: parent

                                    width: Math.min(
                                        190,
                                        parent.width - 16,
                                        parent.height - 16
                                    )

                                    height: width

                                    fillMode: Image.PreserveAspectFit
                                    cache: false

                                    source:
                                        root.commanderUrl !== ""
                                        ? "file://" + root.qrPath
                                            + "?v=" + revision
                                        : ""
                                }
                            }

                            Text {
                                Layout.fillWidth: true

                                text:
                                    root.commanderUrl !== ""
                                    ? root.commanderUrl
                                    : root.i18n.text("no_ip")

                                color: Md3Theme.surfaceVariantContent
                                font.pixelSize: 13

                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WrapAnywhere

                                maximumLineCount: 2
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }

            // Simple upward close gesture.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                Rectangle {
                    width: 48
                    height: 5
                    radius: 3

                    anchors.centerIn: parent

                    color: Md3Theme.surfaceVariantContent
                }

                DragHandler {
                    target: null

                    property real startY: 0

                    onActiveChanged: {
                        if (active) {
                            startY = centroid.position.y
                        } else if (
                            centroid.position.y - startY < -28
                        ) {
                            root.open = false
                        }
                    }
                }

                TapHandler {
                    onTapped: root.open = false
                }
            }
        }
    }

    WifiConnectDialog {
        id: wifiDialog

        i18n: root.i18n
    }
}
