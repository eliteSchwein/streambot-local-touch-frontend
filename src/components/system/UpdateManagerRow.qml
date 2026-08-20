import QtQuick
import QtQuick.Layouts
import "../md3"

Rectangle {
    id:root
    required property string managerName
    required property var manager
    required property var websocket
    required property var i18n

    implicitHeight: managerName==="system" && Array.isArray(manager.updates) && manager.updates.length>0 ? 70 : 52
    radius:Md3Theme.radiusMedium
    color:manager.update_available===true ? Md3Theme.surfaceContainerHigh : "transparent"

    function versionText() {
        if (managerName==="system") {
            const c=Array.isArray(manager.updates)?manager.updates.length:0
            return i18n.text("system_updates_package_count").replace("{count}",c)
        }
        const cur=manager.current_version??manager.commit??"—"
        const latest=manager.latest_version??manager.latest_commit??cur
        return manager.update_available===true && cur!==latest ? cur+" → "+latest : String(cur)
    }

    RowLayout {
        anchors.fill:parent
        anchors.margins:6
        spacing:8

        MdiIcon { name:manager.type==="git"?"git":"package-variant"; size:18 }

        ColumnLayout {
            Layout.fillWidth:true
            spacing:1
            RowLayout {
                Layout.fillWidth:true
                Text { text:root.managerName; color:Md3Theme.surfaceContent; font.pixelSize:11; font.weight:Font.DemiBold }
                Rectangle {
                    implicitWidth:statusText.implicitWidth+12
                    implicitHeight:18
                    radius:9
                    color:root.manager.update_available===true?Md3Theme.error:Md3Theme.surfaceContainerHighest
                    Text {
                        id:statusText
                        anchors.centerIn:parent
                        text:root.manager.update_available===true?root.i18n.text("system_updates_available"):root.i18n.text("system_updates_up_to_date")
                        color:root.manager.update_available===true?Md3Theme.errorContent:Md3Theme.surfaceVariantContent
                        font.pixelSize:7
                        font.weight:Font.DemiBold
                    }
                }
            }
            Text {
                Layout.fillWidth:true
                text:root.manager.error?String(root.manager.error):root.versionText()
                color:root.manager.error?Md3Theme.error:Md3Theme.surfaceVariantContent
                font.pixelSize:8
                elide:Text.ElideMiddle
            }
            Text {
                Layout.fillWidth:true
                visible:root.managerName==="system" && Array.isArray(root.manager.updates) && root.manager.updates.length>0
                text:root.manager.updates.slice(0,3).map(p=>p.package).join(", ")+(root.manager.updates.length>3?" +"+(root.manager.updates.length-3):"")
                color:Md3Theme.surfaceVariantContent
                font.pixelSize:7
                elide:Text.ElideRight
            }
        }

        Rectangle {
            implicitWidth:64
            implicitHeight:30
            radius:15
            color:root.manager.update_available===true && !root.manager.checking && !root.manager.updating?Md3Theme.primary:Md3Theme.surfaceContainerHighest
            opacity:root.manager.update_available===true && !root.manager.checking && !root.manager.updating?1:0.55
            Text {
                anchors.centerIn:parent
                text:root.manager.updating?"…":root.i18n.text("system_updates_update")
                color:root.manager.update_available===true && !root.manager.checking && !root.manager.updating?Md3Theme.primaryContent:Md3Theme.surfaceVariantContent
                font.pixelSize:8
                font.weight:Font.DemiBold
            }
            TapHandler {
                enabled:root.manager.update_available===true && !root.manager.checking && !root.manager.updating
                onTapped:root.websocket.sendRpc("update",{name:root.managerName})
            }
        }
    }
}
