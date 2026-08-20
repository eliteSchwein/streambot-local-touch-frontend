import QtQuick

import "../md3"

Rectangle {
    id: root

    signal clicked()

    implicitWidth: 30
    implicitHeight: 30

    radius: 15

    color:
        tap.pressed
        ? Md3Theme.surfaceContainerHigh
        : "transparent"

    MdiIcon {
        anchors.centerIn: parent

        name: "link-variant"
        size: 18
    }

    TapHandler {
        id: tap

        onTapped:
            root.clicked()
    }
}
