import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "md3"

Item {
    id: root

    required property var i18n
    required property var config
    required property var network

    property bool open: false

    anchors.fill: parent
    z: 1000

    readonly property string commanderUrl:
        network.primaryIp !== ""
        ? "http://" + network.primaryIp + ":" + config.restPort + "/commander"
        : ""

    readonly property string qrPath:
        Quickshell.cachePath("commander-qr.png")

    function refreshQr() {
        if (commanderUrl === "")
            return

        qrProcess.exec([
            "qrencode",
            "-o",
            qrPath,
            "-s",
            "6",
            "-m",
            "2",
            commanderUrl
        ])
    }

    onCommanderUrlChanged: refreshQr()

    property Process qrProcess: Process {
        onExited: {
            qrImage.revision++
        }
    }

    Rectangle {
        id: drawer

        width: parent.width
        height: parent.height

        y: root.open
            ? 0
            : -height + 34

        color: Md3Theme.background

        Behavior on y {
            enabled: !drawerDrag.active

            NumberAnimation {
                duration: 220
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

                    onClicked: {
                        root.open = false
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // LEFT COLUMN: Ethernet above Wi-Fi.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 145

                        title: root.i18n.text("ethernet")

                        Repeater {
                            model: root.network.ethernetDevices

                            RowLayout {
                                required property var modelData

                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true

                                    text:
                                        modelData.device
                                        + " — "
                                        + modelData.state

                                    color: Md3Theme.surfaceContent
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Md3Button {
                                    text: modelData.state === "connected"
                                        ? root.i18n.text("disconnect")
                                        : root.i18n.text("connect")

                                    outlined: true

                                    onClicked: {
                                        if (modelData.state === "connected")
                                            root.network.disconnectDevice(modelData.device)
                                        else
                                            root.network.connectDevice(modelData.device)
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

                                text: root.network.wifiEnabled
                                    ? root.i18n.text("connected")
                                    : root.i18n.text("disconnected")

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

                        ListView {
                            id: wifiList

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            clip: true
                            spacing: 6

                            model: root.network.wifiNetworks

                            delegate: Rectangle {
                                required property var modelData

                                width: wifiList.width
                                height: 44
                                radius: Md3Theme.radiusMedium

                                color: modelData.active
                                    ? Md3Theme.surfaceContainerHigh
                                    : Md3Theme.surfaceContainerHighest

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 9

                                    Text {
                                        Layout.fillWidth: true

                                        text: modelData.ssid
                                        color: Md3Theme.surfaceContent

                                        font.pixelSize: 13
                                        font.weight: modelData.active
                                            ? Font.DemiBold
                                            : Font.Normal

                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.signal + "%"
                                        color: Md3Theme.surfaceVariantContent
                                        font.pixelSize: 11
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

                // RIGHT COLUMN: Language switcher above QR.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 145

                        title: root.i18n.text("language")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Md3Button {
                                Layout.fillWidth: true

                                text: root.i18n.text("english")
                                outlined: root.config.language !== "en"

                                onClicked: {
                                    // UI-only switch for now.
                                    // Config.qml still reads the real value from
                                    // streambot-settings.json on reload.
                                    root.config.language = "en"
                                }
                            }

                            Md3Button {
                                Layout.fillWidth: true

                                text: root.i18n.text("german")
                                outlined: root.config.language !== "de"

                                onClicked: {
                                    root.config.language = "de"
                                }
                            }
                        }
                    }

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        title: root.i18n.text("commander")

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            spacing: 12

                            Image {
                                id: qrImage

                                property int revision: 0

                                Layout.preferredWidth: Math.min(
                                    135,
                                    parent.height - 24
                                )

                                Layout.preferredHeight:
                                    Layout.preferredWidth

                                fillMode: Image.PreserveAspectFit
                                cache: false

                                source: root.commanderUrl !== ""
                                    ? "file://" + root.qrPath + "?v=" + revision
                                    : ""
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true

                                    text: root.commanderUrl !== ""
                                        ? root.commanderUrl
                                        : root.i18n.text("no_ip")

                                    color: Md3Theme.surfaceVariantContent

                                    font.pixelSize: 10

                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text:
                                        root.i18n.text("primary_ip")
                                        + ": "
                                        + (
                                            root.network.primaryIp !== ""
                                            ? root.network.primaryIp
                                            : "-"
                                        )

                                    color: Md3Theme.surfaceVariantContent
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: dragHandle

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
                    id: drawerDrag

                    target: drawer

                    yAxis.minimum: -drawer.height + 34
                    yAxis.maximum: 0

                    onActiveChanged: {
                        if (!active) {
                            root.open =
                                drawer.y > -drawer.height * 0.55

                            drawer.y = Qt.binding(function() {
                                return root.open
                                    ? 0
                                    : -drawer.height + 34
                            })
                        }
                    }
                }

                TapHandler {
                    onTapped: {
                        root.open = !root.open
                    }
                }
            }
        }
    }

    Dialog {
        id: wifiDialog

        property string ssid: ""
        property string security: ""

        anchors.centerIn: parent
        modal: true

        title: ssid

        standardButtons:
            Dialog.Ok | Dialog.Cancel

        contentItem: ColumnLayout {
            width: 300
            spacing: 8

            Text {
                text: wifiDialog.ssid
                color: Md3Theme.surfaceContent
                font.pixelSize: 15
            }

            TextField {
                id: wifiPassword

                Layout.fillWidth: true

                placeholderText:
                    root.i18n.text("password")

                echoMode: TextInput.Password

                visible:
                    wifiDialog.security !== ""
                    && wifiDialog.security !== "--"
            }
        }

        onAccepted: {
            root.network.connectWifi(
                ssid,
                wifiPassword.text
            )

            wifiPassword.text = ""
        }
    }
}
