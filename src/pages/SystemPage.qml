import QtQuick
import QtQuick.Layouts
import "../components/md3"
Item {
    required property var i18n
    required property var config
    ColumnLayout {
        anchors.fill:parent; anchors.margins:16; spacing:12
        Text { text:i18n.text("page_system"); color:Md3Theme.onSurface; font.pixelSize:24; font.weight:Font.DemiBold }
        Md3Card { Layout.fillWidth:true; Layout.fillHeight:true; title:i18n.text("system")
            Text { text:i18n.text("host")+": "+config.host; color:Md3Theme.onSurface; font.pixelSize:14 }
            Text { text:i18n.text("websocket")+": "+config.websocketUrl; color:Md3Theme.onSurfaceVariant; font.pixelSize:13 }
            Text { text:i18n.text("rest_api")+": "+config.restUrl; color:Md3Theme.onSurfaceVariant; font.pixelSize:13 }
            Text { text:i18n.text("language")+": "+config.language; color:Md3Theme.onSurfaceVariant; font.pixelSize:13 }
        }
    }
}
