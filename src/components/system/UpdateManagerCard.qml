import QtQuick
import QtQuick.Layouts
import "../md3"

Rectangle {
    id:root
    required property var i18n
    required property var managers
    required property var websocket

    radius:Md3Theme.radiusLarge
    color:Md3Theme.surfaceContainer
    border.width:1
    border.color:Md3Theme.outlineVariant

    function items() {
        const out=[], src=managers??({})
        for (const name in src) out.push({name:name,manager:src[name]})
        out.sort((a,b)=>a.name==="system"?1:b.name==="system"?-1:a.name.localeCompare(b.name))
        return out
    }
    readonly property var list:items()
    readonly property bool checking:list.some(e=>e.manager?.checking===true)
    readonly property bool updating:list.some(e=>e.manager?.updating===true)

    ColumnLayout {
        anchors.fill:parent
        anchors.margins:10
        spacing:5

        RowLayout {
            Layout.fillWidth:true
            Layout.preferredHeight:34
            Text {
                Layout.fillWidth:true
                text:root.i18n.text("system_updates")
                color:Md3Theme.surfaceContent
                font.pixelSize:13
                font.weight:Font.DemiBold
            }
            Rectangle {
                width:34;height:34;radius:17
                color:refreshTap.pressed?Md3Theme.surfaceContainerHigh:"transparent"
                MdiIcon {
                    anchors.centerIn:parent
                    name:"refresh";size:18
                    RotationAnimator on rotation { from:0;to:360;duration:900;loops:Animation.Infinite;running:root.checking }
                }
                TapHandler {
                    id:refreshTap
                    enabled:!root.updating
                    onTapped:root.websocket.sendRpc("update_refresh")
                }
            }
        }

        Text {
            Layout.fillWidth:true
            Layout.fillHeight:true
            visible:root.list.length===0
            text:root.i18n.text("system_updates_no_state")
            color:Md3Theme.surfaceVariantContent
            font.pixelSize:10
            horizontalAlignment:Text.AlignHCenter
            verticalAlignment:Text.AlignVCenter
        }

        ListView {
            id:listView
            Layout.fillWidth:true
            Layout.fillHeight:true
            visible:root.list.length>0
            clip:true
            spacing:3
            model:root.list
            delegate:UpdateManagerRow {
                required property var modelData
                width:listView.width
                managerName:modelData.name
                manager:modelData.manager
                websocket:root.websocket
                i18n:root.i18n
            }
        }
    }
}
