import QtQuick
import QtQuick.Layouts

import "../md3"

Item {
    id: root

    required property string name
    required property var macro
    required property var websocket

    property string runState: "idle"
    property int requestId: -1

    implicitHeight: 54

    Md3GlassSurface {
        anchors.fill: parent
        radius: Md3Theme.radiusMedium
        tintColor: Md3Theme.surfaceContainer
        tintOpacity: 0.94
    }

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

    Rectangle {
        anchors.fill: parent
        radius: Md3Theme.radiusMedium

        color:
            rowTap.pressed
            ? Md3Theme.surfaceContainerHigh
            : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14

        spacing: 10

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: root.name
            color: Md3Theme.surfaceContent

            font.pixelSize: 12
            font.weight: Font.DemiBold

            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter

            MdiIcon {
                anchors.centerIn: parent

                name: {
                    if (root.runState === "success")
                        return "check"

                    if (root.runState === "error")
                        return "alert-circle"

                    return "play"
                }

                size: 20
                selected:
                    root.runState === "success"
                    || root.runState === "error"
            }
        }
    }

    TapHandler {
        id: rowTap

        enabled:
            root.runState !== "loading"
            && root.websocket.connected

        onTapped:
            root.triggerMacro()
    }
}
