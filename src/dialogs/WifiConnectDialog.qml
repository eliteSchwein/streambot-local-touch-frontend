import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../components/md3"

Popup {
    id: root

    required property var i18n
    required property var network

    property string ssid: ""
    property string security: ""

    modal: true
    focus: true

    width: 360
    padding: 0

    anchors.centerIn: Overlay.overlay

    closePolicy: Popup.CloseOnEscape

    background: Rectangle {
        radius: Md3Theme.radiusExtraLarge
        color: Md3Theme.surfaceContainerHigh
        border.width: 1
        border.color: Md3Theme.outlineVariant
    }

    contentItem: ColumnLayout {
        spacing: 16
        anchors.margins: 20

        Text {
            Layout.fillWidth: true
            text: root.i18n.text("wifi_connect")
            color: Md3Theme.surfaceContent
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        Text {
            Layout.fillWidth: true
            text: root.ssid
            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        TextField {
            id: passwordField

            Layout.fillWidth: true
            implicitHeight: 48

            visible: root.security !== "" && root.security !== "--"
            placeholderText: root.i18n.text("wifi_password_hint")
            echoMode: TextInput.Password

            color: Md3Theme.surfaceContent
            placeholderTextColor: Md3Theme.surfaceVariantContent

            background: Rectangle {
                radius: Md3Theme.radiusMedium
                color: Md3Theme.surfaceContainerHighest
                border.width: passwordField.activeFocus ? 2 : 1
                border.color: passwordField.activeFocus
                    ? Md3Theme.primary
                    : Md3Theme.outline
            }

            leftPadding: 14
            rightPadding: 14
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.fillWidth: true
            }

            Md3Button {
                text: root.i18n.text("cancel")
                outlined: true

                onClicked: {
                    passwordField.text = ""
                    root.close()
                }
            }

            Md3Button {
                text: root.i18n.text("connect")

                onClicked: {
                    root.network.connectWifi(
                        root.ssid,
                        passwordField.text
                    )

                    passwordField.text = ""
                    root.close()
                }
            }
        }
    }
}
