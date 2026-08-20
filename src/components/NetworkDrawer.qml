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

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string qrPath: runtimeDir + "/streambot-touch-commander.png"
    readonly property string commanderUrl: network.primaryIp !== ""
        ? "http://" + network.primaryIp + ":" + config.restPort + "/commander" : ""

    function refreshQr() {
        if (!commanderUrl) return
        qrProcess.exec(["qrencode", "-o", qrPath, "-s", "6", "-m", "2", commanderUrl])
    }

    onCommanderUrlChanged: refreshQr()

    Process {
        id: qrProcess
        onExited: code => {
            if (code === 0) qrImage.revision++
            else console.warn("[qr] qrencode failed:", code)
        }
    }

    // Android-like top edge gesture: detect downward movement, then snap open.
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.open ? 0 : 42
        z: 20

        DragHandler {
            id: openGesture
            target: null
            property real startY: 0
            onActiveChanged: {
                if (active) startY = centroid.position.y
                else if (centroid.position.y - startY > 36) root.open = true
            }
        }
        TapHandler { onTapped: root.open = true }
    }

    Rectangle {
        id: drawer
        width: parent.width
        height: parent.height
        y: root.open ? 0 : -height
        color: Md3Theme.background

        Behavior on y {
            NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
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
                    onClicked: { root.network.refresh(); root.refreshQr() }
                }
                Md3Button { text: "×"; outlined: true; onClicked: root.open = false }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 135
                        title: root.i18n.text("ethernet")

                        Repeater {
                            model: root.network.ethernetDevices
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.device + " — " + modelData.state
                                    color: Md3Theme.surfaceContent
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                Md3Button {
                                    text: modelData.state === "connected"
                                        ? root.i18n.text("disconnect") : root.i18n.text("connect")
                                    outlined: true
                                    onClicked: modelData.state === "connected"
                                        ? root.network.disconnectDevice(modelData.device)
                                        : root.network.connectDevice(modelData.device)
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
                                text: root.i18n.text("wifi")
                                color: Md3Theme.surfaceVariantContent
                                font.pixelSize: 12
                            }
                            Md3Switch {
                                checked: root.network.wifiEnabled
                                onToggled: root.network.setWifiEnabled(checked)
                            }
                        }

                        Text {
                            text: config.language === "de" ? "Gespeichert" : "Saved"
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
                                    onClicked: root.network.activateConnection(modelData.name)
                                }
                            }
                        }

                        Text {
                            text: config.language === "de" ? "Verfügbar" : "Available"
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

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 125
                        title: root.i18n.text("language")

                        Md3Select {
                            id: languageSelect
                            Layout.fillWidth: true
                            model: [root.i18n.text("english"), root.i18n.text("german")]
                            currentIndex: root.config.language === "de" ? 1 : 0
                            onActivated: index => root.config.language = index === 1 ? "de" : "en"
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
                                Layout.preferredWidth: Math.min(145, parent.height - 18)
                                Layout.preferredHeight: Layout.preferredWidth
                                fillMode: Image.PreserveAspectFit
                                cache: false
                                source: root.commanderUrl !== ""
                                    ? "file://" + root.qrPath + "?v=" + revision : ""
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: root.commanderUrl || root.i18n.text("no_ip")
                                    color: Md3Theme.surfaceVariantContent
                                    font.pixelSize: 10
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.i18n.text("primary_ip") + ": "
                                        + (root.network.primaryIp || "-")
                                    color: Md3Theme.surfaceVariantContent
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }

            // Swipe upward here to close, or tap it.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                Rectangle {
                    width: 48; height: 5; radius: 3
                    anchors.centerIn: parent
                    color: Md3Theme.surfaceVariantContent
                }

                DragHandler {
                    target: null
                    property real startY: 0
                    onActiveChanged: {
                        if (active) startY = centroid.position.y
                        else if (centroid.position.y - startY < -28) root.open = false
                    }
                }
                TapHandler { onTapped: root.open = false }
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
        standardButtons: Dialog.Ok | Dialog.Cancel

        contentItem: TextField {
            id: wifiPassword
            width: 300
            placeholderText: root.i18n.text("password")
            echoMode: TextInput.Password
            visible: wifiDialog.security !== "" && wifiDialog.security !== "--"
        }

        onAccepted: {
            root.network.connectWifi(ssid, wifiPassword.text)
            wifiPassword.text = ""
        }
    }
}
