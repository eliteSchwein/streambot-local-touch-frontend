import QtQuick
import QtQuick.Layouts
import "../md3"

Rectangle {
    id: root
    required property var i18n
    required property var managers
    required property var websocket

    radius: Md3Theme.radiusLarge
    color: "transparent"
    border.width: 0

    Md3GlassSurface {
        anchors.fill: parent
        tintColor: Md3Theme.surfaceContainer
        tintOpacity: 0.94
        radius: root.radius
    }

    function items() {
        const out = [], src = managers ?? ({})
        for (const name in src)
            out.push({ name: name, manager: src[name] })

        out.sort((a, b) =>
                a.name === "system"
                ? 1
                : b.name === "system"
                    ? -1
                    : a.name.localeCompare(b.name)
        )

        return out
    }

    readonly property var list: items()
    readonly property bool checking: list.some(e => e.manager?.checking === true)
    readonly property bool updating: list.some(e => e.manager?.updating === true)
    readonly property bool hasUpdates:
        list.some(e => e.manager?.update_available === true)

    property var updateAllQueue: []
    property string updateAllCurrent: ""
    property bool updateAllSeenRunning: false
    property int updateAllRequestId: -1
    property bool updateAllActive: false
    property int updateAllIdleTicks: 0

    function startUpdateAll() {
        if (updateAllActive || updating || !hasUpdates)
            return

        const names = list
            .filter(e =>
                e.manager?.update_available === true
                && e.manager?.checking !== true
                && e.manager?.updating !== true
            )
            .map(e => e.name)

        // Updating the backend can restart the service, so always do it last.
        names.sort((a, b) => {
            if (a === "backend")
                return 1
            if (b === "backend")
                return -1
            return 0
        })

        if (names.length === 0)
            return

        updateAllQueue = names
        updateAllActive = true
        updateAllCurrent = ""
        updateAllSeenRunning = false
        updateAllIdleTicks = 0
        Qt.callLater(runNextUpdate)
    }

    function runNextUpdate() {
        if (!updateAllActive || updateAllCurrent !== "" || updating)
            return

        if (updateAllQueue.length === 0) {
            updateAllActive = false
            return
        }

        const queue = Array.from(updateAllQueue)
        updateAllCurrent = queue.shift()
        updateAllQueue = queue
        updateAllSeenRunning = false
        updateAllIdleTicks = 0

        updateAllRequestId = websocket.sendRpc(
            "update",
            { name: updateAllCurrent }
        )

        if (updateAllRequestId < 0) {
            updateAllCurrent = ""
            updateAllActive = false
            return
        }

        updateAllTimer.restart()
    }

    function finishCurrentUpdate() {
        updateAllCurrent = ""
        updateAllSeenRunning = false
        updateAllRequestId = -1
        updateAllIdleTicks = 0

        if (updateAllQueue.length === 0) {
            updateAllActive = false
            return
        }

        Qt.callLater(runNextUpdate)
    }

    Connections {
        target: root.websocket

        function onRpcResponse(id, data) {
            if (
                !root.updateAllActive
                || id !== root.updateAllRequestId
            ) {
                return
            }

            if (data?.error !== undefined) {
                root.finishCurrentUpdate()
            }
        }
    }

    Timer {
        id: updateAllTimer
        interval: 300
        repeat: true

        onTriggered: {
            if (
                !root.updateAllActive
                || root.updateAllCurrent === ""
            ) {
                stop()
                return
            }

            const manager =
                root.managers?.[root.updateAllCurrent]

            if (manager?.updating === true) {
                root.updateAllSeenRunning = true
                root.updateAllIdleTicks = 0
                return
            }

            // Normal path: wait until the manager has entered and then left
            // its updating state before starting the next manager.
            if (root.updateAllSeenRunning) {
                stop()
                root.finishCurrentUpdate()
                return
            }

            // Fallback for very fast/no-op updaters where the updating
            // notification can be missed between two UI frames.
            root.updateAllIdleTicks++

            if (
                root.updateAllIdleTicks >= 10
                && manager?.update_available !== true
            ) {
                stop()
                root.finishCurrentUpdate()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34

            Text {
                Layout.fillWidth: true
                text: root.i18n.text("system_updates")
                color: Md3Theme.surfaceContent
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Rectangle {
                implicitWidth: updateAllText.implicitWidth + 24
                width: implicitWidth
                height: 32
                radius: 16

                color:
                    root.hasUpdates
                    && !root.updating
                    && !root.updateAllActive
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                opacity:
                    root.hasUpdates
                    && !root.updating
                    && !root.updateAllActive
                    ? 1
                    : 0.55

                Text {
                    id: updateAllText
                    anchors.centerIn: parent

                    text:
                        root.updateAllActive
                        ? root.i18n.text("system_updates_updating")
                        : root.i18n.text("system_updates_update_all")

                    color:
                        root.hasUpdates
                        && !root.updating
                        && !root.updateAllActive
                        ? Md3Theme.primaryContent
                        : Md3Theme.surfaceVariantContent

                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                TapHandler {
                    enabled:
                        root.hasUpdates
                        && !root.updating
                        && !root.updateAllActive

                    onTapped:
                        root.startUpdateAll()
                }
            }

            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: refreshTap.pressed
                    ? Md3Theme.surfaceContainerHigh
                    : "transparent"

                MdiIcon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: 18

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.checking
                    }
                }

                TapHandler {
                    id: refreshTap
                    enabled: !root.updating
                    onTapped: root.websocket.sendRpc("update_refresh")
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.list.length === 0
            text: root.i18n.text("system_updates_no_state")
            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.list.length > 0
            clip: true
            spacing: 2
            model: root.list

            delegate: UpdateManagerRow {
                required property var modelData

                width: listView.width
                managerName: modelData.name
                manager: modelData.manager
                allManagers: root.managers
                websocket: root.websocket
                i18n: root.i18n
            }
        }
    }
}
