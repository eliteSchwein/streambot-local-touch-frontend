import QtQuick
import QtQuick.Layouts
import "../md3"

Rectangle {
    id: root
    required property string managerName
    required property var manager
    required property var allManagers
    required property var websocket
    required property var i18n

    readonly property bool backendUpdating:
        allManagers?.backend?.updating === true

    readonly property bool anotherManagerUpdating: {
        const src = allManagers ?? ({})
        for (const name in src) {
            if (name !== managerName && src[name]?.updating === true)
                return true
        }
        return false
    }

    readonly property bool blockedByUpdate:
        managerName === "backend"
            ? anotherManagerUpdating
            : backendUpdating

    readonly property bool canUpdate:
        manager.update_available === true
        && manager.checking !== true
        && manager.updating !== true
        && !blockedByUpdate

    implicitHeight:
            managerName === "system"
        && Array.isArray(manager.updates)
        && manager.updates.length > 0
        ? 70
        : 52

    radius: Md3Theme.radiusMedium
    color: manager.update_available === true
        ? Md3Theme.surfaceContainerHigh
        : "transparent"

    function versionText() {
        if (managerName === "system") {
            const c = Array.isArray(manager.updates)
                ? manager.updates.length
                : 0

            return i18n.text("system_updates_package_count")
                .replace("{count}", c)
        }

        const cur = manager.current_version ?? manager.commit ?? "—"
        const latest = manager.latest_version ?? manager.latest_commit ?? cur

        return manager.update_available === true && cur !== latest
            ? String(cur) + " → " + String(latest)
            : String(cur)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 6

        MdiIcon {
            name: root.manager.type === "git"
                ? "git"
                : "package-variant"
            size: 18
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.managerName
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    implicitWidth: statusText.implicitWidth + 14
                    implicitHeight: 20
                    radius: 10
                    color: root.manager.updating === true
                        ? Md3Theme.primary
                        : root.manager.update_available === true
                            ? Md3Theme.error
                            : Md3Theme.surfaceContainerHighest

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: root.manager.updating === true
                            ? root.i18n.text("system_updates_updating")
                            : root.manager.update_available === true
                                ? root.i18n.text("system_updates_available")
                                : root.i18n.text("system_updates_up_to_date")
                        color: root.manager.updating === true
                            ? Md3Theme.primaryContent
                            : root.manager.update_available === true
                                ? Md3Theme.errorContent
                                : Md3Theme.surfaceVariantContent
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.manager.error
                    ? String(root.manager.error)
                    : root.versionText()
                color: root.manager.error
                    ? Md3Theme.error
                    : Md3Theme.surfaceVariantContent
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }

            Text {
                Layout.fillWidth: true
                visible:
                    root.managerName === "system"
                    && Array.isArray(root.manager.updates)
                    && root.manager.updates.length > 0
                text:
                    root.manager.updates.slice(0, 3)
                        .map(p => p.package)
                        .join(", ")
                    + (root.manager.updates.length > 3
                        ? " +" + (root.manager.updates.length - 3)
                        : "")
                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Rectangle {
            implicitWidth: 72
            width: 72
            implicitHeight: 28
            height: 28
            radius: 14
            color: root.canUpdate
                ? Md3Theme.primary
                : Md3Theme.surfaceContainerHighest
            opacity: root.canUpdate ? 1 : 0.55

            Text {
                anchors.centerIn: parent
                visible: root.manager.updating !== true
                text: root.i18n.text("system_updates_update")
                color: root.canUpdate
                    ? Md3Theme.primaryContent
                    : Md3Theme.surfaceVariantContent
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            MdiIcon {
                anchors.centerIn: parent
                visible: root.manager.updating === true
                name: "loading"
                size: 16
                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.manager.updating === true
                }
            }

            TapHandler {
                enabled: root.canUpdate
                onTapped: root.websocket.sendRpc(
                    "update",
                    { name: root.managerName }
                )
            }
        }
    }
}
