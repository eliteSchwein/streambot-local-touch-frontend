import QtQuick
import QtQuick.Layouts
import "../md3"

Rectangle {
    id: root
    required property var i18n
    required property var storage

    radius: Md3Theme.radiusLarge
    color: Md3Theme.surfaceContainer
    border.width: 1
    border.color: Md3Theme.outlineVariant

    function fmt(v) {
        let n = Number(v ?? 0)
        if (!Number.isFinite(n)) return "—"
        const u=["B","KB","MB","GB","TB"]; let i=0
        while (n>=1024 && i<u.length-1) { n/=1024; i++ }
        return n.toFixed(i===0?0:1)+" "+u[i]
    }

    readonly property real usedPercent: {
        const total=Number(storage?.total??0), used=Number(storage?.used??0)
        return total>0 ? Math.max(0,Math.min(1,used/total)) : 0
    }

    function firstNumber(values) {
        for (const value of values) {
            if (
                value === undefined
                || value === null
                || value === ""
            ) {
                continue
            }

            const n = Number(value)

            if (Number.isFinite(n))
                return n
        }

        return 0
    }

    function rows() {
        const s = storage ?? ({})
        const f = s.folders ?? ({})

        return [
            [
                "system_media_used",
                firstNumber([
                    f.media,
                    f.assets,
                    s.mediaUsed,
                    s.assetUsed,
                    s.assetsUsed
                ]),
                "#2196F3"
            ],
            [
                "system_asset_config_used",
                firstNumber([
                    f.asset_configs,
                    f.assetConfigs,
                    s.assetConfigUsed,
                    s.assetConfigsUsed
                ]),
                "#9C27B0"
            ],
            [
                "system_overlay_used",
                firstNumber([
                    f.overlays,
                    f.overlay,
                    s.overlayUsed,
                    s.overlaysUsed
                ]),
                "#00BCD4"
            ],
            [
                "system_music_used",
                firstNumber([
                    f.music,
                    s.musicUsed
                ]),
                "#4CAF50"
            ],
            [
                "system_macro_used",
                firstNumber([
                    f.macros,
                    f.macro,
                    s.macroUsed,
                    s.macrosUsed
                ]),
                "#FFC107"
            ],
            [
                "system_auto_macro_used",
                firstNumber([
                    f.auto_macros,
                    f.autoMacros,
                    f.auto_macro,
                    s.autoMacroUsed,
                    s.autoMacrosUsed
                ]),
                "#FF5722"
            ],
            [
                "system_channel_point_used",
                firstNumber([
                    f.channel_points,
                    f.channelPoints,
                    f.channel_points_configs,
                    s.channelPointUsed,
                    s.channelPointsUsed
                ]),
                "#E91E63"
            ],
            [
                "system_command_used",
                firstNumber([
                    f.commands,
                    f.commands_configs,
                    s.commands,
                    s.commandUsed,
                    s.commandsUsed
                ]),
                "#009688"
            ],
            [
                "system_rotating_scene_used",
                firstNumber([
                    f.rotating_scenes,
                    f.rotatingScenes,
                    f.rotating_scene,
                    s.rotatingSceneUsed,
                    s.rotatingScenesUsed
                ]),
                "#CDDC39"
            ],
            [
                "system_ollama_used",
                firstNumber([
                    f.ollama,
                    s.ollamaUsed
                ]),
                "#3F51B5"
            ]
        ].filter(row => Number(row[1]) > 0)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: root.i18n.text("system_storage")
            color: Md3Theme.surfaceContent
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.fillWidth:true
            Layout.preferredHeight:8
            radius:4
            color:Md3Theme.surfaceContainerHighest
            Rectangle {
                width:parent.width*root.usedPercent
                height:parent.height
                radius:4
                color:Md3Theme.primary
                Behavior on width { NumberAnimation { duration:300 } }
            }
        }

        GridLayout {
            Layout.fillWidth:true
            columns:2
            columnSpacing:10
            rowSpacing:3
            Repeater {
                model:[
                    [root.i18n.text("system_storage_used"),root.storage?.used],
                    [root.i18n.text("system_storage_free"),root.storage?.free],
                    [root.i18n.text("system_storage_total"),root.storage?.total]
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.columnSpan:2
                    Layout.fillWidth:true
                    Text { Layout.fillWidth:true; text:modelData[0]; color:Md3Theme.surfaceVariantContent; font.pixelSize:9 }
                    Text { text:root.fmt(modelData[1]); color:Md3Theme.surfaceContent; font.pixelSize:9; font.weight:Font.Medium }
                }
            }
        }

        Rectangle { Layout.fillWidth:true; Layout.preferredHeight:1; color:Md3Theme.outlineVariant }

        ListView {
            id:list
            Layout.fillWidth:true
            Layout.fillHeight:true
            clip:true
            spacing:2
            model:root.rows()
            delegate: RowLayout {
                required property var modelData

                width: list.width
                height: 20
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    Layout.alignment: Qt.AlignVCenter

                    radius: 3
                    color: modelData[2]
                }

                Text {
                    Layout.fillWidth: true

                    text: root.i18n.text(modelData[0])
                    color: Md3Theme.surfaceVariantContent

                    font.pixelSize: 8
                    elide: Text.ElideRight
                }

                Text {
                    text: root.fmt(modelData[1])
                    color: Md3Theme.surfaceContent

                    font.pixelSize: 8
                    font.weight: Font.Medium
                }
            }
        }
    }
}
