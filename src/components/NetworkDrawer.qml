import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

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
        ? "http://" + network.primaryIp + ":" + config.restPort + "/commander"
        : ""

    function refreshQr() {
        if (commanderUrl === "")
            return

        qrProcess.exec([
            "qrencode",
            "-o",
            qrPath,
            "-s",
            "10",
            "-m",
            "1",
            commanderUrl
        ])
    }

    onCommanderUrlChanged: refreshQr()

    property Process qrProcess: Process {
        onExited: code => {
            if (code === 0)
                qrImage.revision++
            else
                console.warn("[qr] qrencode failed:", code)
        }
    }

    // Closed state: only this thin top strip listens for a downward pull.
    Item {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        height: root.open ? 0 : 44
        z: 20

        DragHandler {
            id: openGesture
            target: null

            property real startY: 0

            onActiveChanged: {
                if (active) {
                    startY = centroid.position.y
                } else if (centroid.position.y - startY > 36) {
                    root.open = true
                }
            }
        }

        TapHandler {
            onTapped: root.open = true
        }
    }

    Rectangle {
        id: drawer

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

                Text {
                    Layout.fillWidth: true
                    text: root.i18n.text("network")
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Md3Button {
                    text: root.i18n.text("refresh")

                    onClicked: {
                        root.network.refresh()
                        root.refreshQr()
                    }
                }

                Md3Button {
                    text: "×"
                    outlined: true
                    onClicked: root.open = false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // LEFT: Ethernet then Wi-Fi.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 128

                        title: root.i18n.text("ethernet")

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: root.network.ethernetEnabled
                                        ? root.i18n.text("enabled")
                                        : root.i18n.text("disabled")

                                    color: Md3Theme.surfaceVariantContent
                                    font.pixelSize: 12
                                }

                                Repeater {
                                    model: root.network.ethernetDevices

                                    Text {
                                        required property var modelData

                                        Layout.fillWidth: true

                                        text:
                                            modelData.device
                                            + " — "
                                            + modelData.state

                                        color: Md3Theme.surfaceContent
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Md3Switch {
                                checked: root.network.ethernetEnabled

                                onToggled: {
                                    root.network.setEthernetEnabled(checked)
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

                                text: root.network.wifiEnabled
                                    ? root.i18n.text("enabled")
                                    : root.i18n.text("disabled")

                                color: Md3Theme.surfaceVariantContent
                                font.pixelSize: 12
                            }

                            Md3Switch {
                                checked: root.network.wifiEnabled

                                onToggled: {
                                    root.network.setWifiEnabled(checked)
                                }
                            }
                        }

                        Text {
                            text: root.i18n.text("saved")
                            color: Md3Theme.surfaceContent
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: root.network.savedWifiConnections

                            RowLayout {
                                required property var modelData

                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true

                                    text: modelData.name
                                    color: Md3Theme.surfaceContent

                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: modelData.device !== ""

                                    text: root.i18n.text("connected")
                                    color: Md3Theme.success
                                    font.pixelSize: 10
                                }

                                Md3Button {
                                    visible: modelData.device === ""

                                    text: root.i18n.text("connect")
                                    outlined: true

                                    onClicked: {
                                        root.network.activateConnection(
                                            modelData.name
                                        )
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.i18n.text("available")
                            color: Md3Theme.surfaceContent
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
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
                                height: 42
                                radius: Md3Theme.radiusMedium

                                color: modelData.active
                                    ? Md3Theme.surfaceContainerHigh
                                    : Md3Theme.surfaceContainerHighest

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8

                                    Text {
                                        Layout.fillWidth: true

                                        text: modelData.ssid
                                        color: Md3Theme.surfaceContent

                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.signal + "%"
                                        color: Md3Theme.surfaceVariantContent
                                        font.pixelSize: 10
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        wifiDialog.ssid = modelData.ssid
                                        wifiDialog.security = modelData.security
                                        wifiDialog.open()
                                    }
                                }
                            }
                        }
                    }
                }

                // RIGHT: Language then big QR.
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
                                root.config.language === "de" ? 1 : 0

                            onActivated: index => {
                                root.config.language =
                                    index === 1 ? "de" : "en"
                            }
                        }
                    }

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        title: root.i18n.text("commander")

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
                                        parent.width - 12,
                                        parent.height - 12
                                    )

                                    height: width

                                    fillMode: Image.PreserveAspectFit
                                    cache: false

                                    source: root.commanderUrl !== ""
                                        ? "file://" + root.qrPath
                                            + "?v=" + revision
                                        : ""
                                }
                            }

                            Text {
                                Layout.fillWidth: true

                                text: root.commanderUrl !== ""
                                    ? root.commanderUrl
                                    : root.i18n.text("no_ip")

                                color: Md3Theme.surfaceVariantContent
                                font.pixelSize: 10

                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WrapAnywhere

                                maximumLineCount: 2
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }

            // Open drawer: swipe up on this Android-style handle to close.
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
        network: root.network
    }
}
