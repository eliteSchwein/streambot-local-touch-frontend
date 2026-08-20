import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../components/md3"

Md3Dialog {
    id: root

    required property var i18n
    required property var network

    property string ssid: ""
    property string security: ""

    title: root.i18n.text("wifi_connect")

    onOpened: {
        if (passwordField.visible)
            Qt.callLater(passwordField.forceActiveFocus)
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
        implicitHeight: 52

        visible:
            root.security !== ""
            && root.security !== "--"

        placeholderText:
            root.i18n.text("wifi_password_hint")

        echoMode: TextInput.Password

        color: Md3Theme.surfaceContent
        placeholderTextColor: Md3Theme.surfaceVariantContent
        selectionColor: Md3Theme.primary
        selectedTextColor: Md3Theme.primaryContent

        leftPadding: 16
        rightPadding: 16

        background: Rectangle {
            radius: Md3Theme.radiusMedium
            color: Md3Theme.surfaceContainerHighest

            border.width:
                passwordField.activeFocus ? 2 : 1

            border.color:
                passwordField.activeFocus
                ? Md3Theme.primary
                : Md3Theme.outline
        }
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
