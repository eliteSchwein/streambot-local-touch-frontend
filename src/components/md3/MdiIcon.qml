import QtQuick

Item {
    id: root

    required property string name

    property int size: 20
    property bool selected: false
    property bool selectedAssetAvailable: true

    implicitWidth: size
    implicitHeight: size

    onNameChanged:
        selectedAssetAvailable = true

    onSelectedChanged: {
        if (selected)
            selectedAssetAvailable = true
    }

    readonly property url normalSource:
        Qt.resolvedUrl(
            "../../icons/mdi/"
            + root.name
            + ".svg"
        )

    readonly property url selectedSource:
        Qt.resolvedUrl(
            "../../icons/mdi-selected/"
            + root.name
            + ".svg"
        )

    Image {
        id: iconImage
        anchors.centerIn: parent

        width: root.size
        height: root.size

        source:
                root.selected
            && root.selectedAssetAvailable
            ? root.selectedSource
            : root.normalSource

        sourceSize.width: root.size
        sourceSize.height: root.size

        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true

        onStatusChanged: {
            if (
                status === Image.Error
                && root.selected
                && root.selectedAssetAvailable
            ) {
                root.selectedAssetAvailable = false
            }
        }
    }
}
