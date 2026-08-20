import QtQuick
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property string name
    required property var macro
    required property var websocket

    property string runState: "idle"
    property int requestId: -1

    implicitHeight: 54

    radius: Md3Theme.radiusMedium
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    function triggerMacro() {
        if (
            runState === "loading"
            || !websocket.connected
        ) {
            return
        }

        runState = "loading"

        requestId = websocket.sendRpc(
            "trigger_macro",
            {
                macro: name
            }
        )

        if (requestId < 0) {
            runState = "error"
            resetTimer.restart()
            return
        }

        responseTimeout.restart()
    }

    function responseFailed(data) {
        if (!data)
            return false

        if (data.error !== undefined)
            return true

        const result =
            data.result
            ?? data.params
            ?? data.data
            ?? data.payload
            ?? null

        if (
            result
            && typeof result === "object"
            && result.success === false
        ) {
            return true
        }

        return false
    }

    Connections {
        target: root.websocket

        function onRpcResponse(id, data) {
            if (
                root.requestId < 0
                || id !== root.requestId
            ) {
                return
            }

            responseTimeout.stop()
            root.requestId = -1

            root.runState =
                root.responseFailed(data)
                ? "error"
                : "success"

            resetTimer.restart()
        }
    }

    Timer {
        id: responseTimeout

        interval: 10000
        repeat: false

        onTriggered: {
            root.requestId = -1
            root.runState = "error"
            resetTimer.restart()
        }
    }

    Timer {
        id: resetTimer

        interval: 2500
        repeat: false

        onTriggered:
            root.runState = "idle"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 8

        spacing: 10

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: root.name
            color: Md3Theme.surfaceContent

            font.pixelSize: 13
            font.weight: Font.DemiBold

            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter

            implicitWidth: 44
            implicitHeight: 44

            radius: 22

            color: {
                if (root.runState === "success")
                    return Md3Theme.success

                if (root.runState === "error")
                    return Md3Theme.error

                if (root.runState === "loading")
                    return Md3Theme.surfaceContainerHigh

                return Md3Theme.primary
            }

            MdiIcon {
                anchors.centerIn: parent

                name: {
                    if (root.runState === "success")
                        return "check"

                    if (root.runState === "error")
                        return "alert-circle"

                    return "play"
                }

                size: 21
                selected:
                    root.runState !== "loading"
            }

            TapHandler {
                enabled:
                    root.runState !== "loading"

                onTapped:
                    root.triggerMacro()
            }
        }
    }
}
