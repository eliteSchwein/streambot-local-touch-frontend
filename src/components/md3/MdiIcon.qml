import QtQuick

Item {
    id: root

    required property string name

    property int size: 20
    property bool selected: false

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.centerIn: parent

        width: root.size
        height: root.size

        source:
            Qt.resolvedUrl(
                "../../icons/"
                + (root.selected ? "mdi-selected/" : "mdi/")
                + root.name
                + ".svg"
            )

        sourceSize.width: root.size
        sourceSize.height: root.size

        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
}
