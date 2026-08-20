import QtQuick
import QtQuick.Layouts

import "../components/md3"

Md3Dialog {
    id: root

    z: 600000

    required property var i18n

    property string message: ""
    property string confirmText: root.i18n.text("delete")
    property bool destructive: false

    signal confirmed()

    supportingText: root.message

    actions: [
        Md3Button {
            text: root.i18n.text("cancel")
            outlined: true

            onClicked: root.close()
        },

        Md3Button {
            text: root.confirmText

            onClicked: {
                root.close()
                root.confirmed()
            }
        }
    ]
}
