import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

import "../components/md3"
import "../services"

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

    Md3TextField {
        id: passwordField

        Layout.fillWidth: true

        visible:
            root.network !== null
            && root.network.security !== WifiSecurityType.Open

        placeholderText:
            root.i18n.text("wifi_password_hint")

        echoMode: TextInput.Password
    }

    actions: [
        Md3Button {
            text: root.i18n.text("cancel")
            outlined: true

            onClicked: {
                passwordField.focus = false
                passwordField.focus = false
                KeyboardController.clearFocus()
                root.close()
            }
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
