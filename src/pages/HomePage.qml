import QtQuick
import QtQuick.Layouts
import "../components/md3"
Item {
    required property var i18n
    required property var websocket
    ColumnLayout {
        anchors.fill:parent; anchors.margins:16; spacing:12
        Text { text:i18n.text("page_home"); color:Md3Theme.onSurface; font.pixelSize:24; font.weight:Font.DemiBold }
        RowLayout {
            Layout.fillWidth:true; Layout.fillHeight:true; spacing:12
            Md3Card { Layout.fillWidth:true; Layout.fillHeight:true; title:i18n.text("websocket")
                Text { text:websocket.connected?i18n.text("connected"):i18n.text("disconnected"); color:Md3Theme.onSurface; font.pixelSize:16 }
            }
            Md3Card { Layout.fillWidth:true; Layout.fillHeight:true; title:i18n.text("alerts")
                Text { text:i18n.text("no_alerts"); color:Md3Theme.onSurfaceVariant; font.pixelSize:14 }
            }
        }
    }
}
