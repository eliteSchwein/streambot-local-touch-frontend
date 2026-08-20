import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

import "../components/md3"

Md3Dialog {
    id: root

    required property var i18n

    property var network: null

    title: root.i18n.text("wifi_connect")

    supportingText:
        root.network !== null
        ? root.network.name
        : ""

    onOpened: {
        passwordField.text = ""

        if (passwordField.visible)
            Qt.callLater(passwordField.forceActiveFocus)
    }

    TextField {
        id: passwordField

        Layout.fillWidth: true
        implicitHeight: 52

        visible:
            root.network !== null
            && root.network.security !== WifiSecurityType.Open

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

    actions: [
        Md3Button {
            text: root.i18n.text("cancel")
            outlined: true

            onClicked: root.close()
        },

        Md3Button {
            text: root.i18n.text("connect")

            onClicked: {
                if (root.network === null)
                    return

                // Saved/known networks should first try their stored NM settings.
                if (root.network.known) {
                    root.network.connect()
                } else if (
                    root.network.security === WifiSecurityType.Open
                ) {
                    root.network.connect()
                } else {
                    root.network.connectWithPsk(
                        passwordField.text
                    )
                }

                root.close()
            }
        }
    ]
}
