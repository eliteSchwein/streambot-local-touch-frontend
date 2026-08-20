import QtQuick
import QtQuick.Controls

ComboBox {
    id: root
    implicitHeight: 44

    contentItem: Text {
        leftPadding: 14
        rightPadding: 36
        text: root.displayText
        color: Md3Theme.surfaceContent
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Md3Theme.radiusExtraLarge
        color: Md3Theme.surfaceContainerHigh
        border.width: 1
        border.color: root.activeFocus ? Md3Theme.primary : Md3Theme.outline
    }

    indicator: Text {
        x: root.width - width - 14
        anchors.verticalCenter: parent.verticalCenter
        text: "▼"
        color: Md3Theme.surfaceVariantContent
        font.pixelSize: 11
    }

    delegate: ItemDelegate {
        width: root.width
        height: 44
        contentItem: Text {
            text: modelData
            color: Md3Theme.surfaceContent
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 13
        }
        background: Rectangle {
            color: highlighted ? Md3Theme.surfaceContainerHigh : Md3Theme.surfaceContainer
        }
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: contentItem.implicitHeight + 8
        padding: 4

        contentItem: ListView {
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }

        background: Rectangle {
            radius: Md3Theme.radiusMedium
            color: Md3Theme.surfaceContainer
            border.width: 1
            border.color: Md3Theme.outlineVariant
        }
    }
}
