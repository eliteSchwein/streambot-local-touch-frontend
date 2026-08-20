import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components/md3"
Item {
    required property var i18n
    required property var websocket
    ColumnLayout {
        anchors.fill:parent; anchors.margins:16; spacing:12
        Text { text:i18n.text("page_controls"); color:Md3Theme.onSurface; font.pixelSize:24; font.weight:Font.DemiBold }
        RowLayout {
            Layout.fillWidth:true; Layout.fillHeight:true; spacing:12
            Md3Card { Layout.fillWidth:true; Layout.fillHeight:true; title:i18n.text("audio")
                Text { text:i18n.text("music"); color:Md3Theme.onSurface; font.pixelSize:14 }
                Slider { Layout.fillWidth:true; from:0; to:1; value:.25 }
                Text { text:i18n.text("tts"); color:Md3Theme.onSurface; font.pixelSize:14 }
                Slider { Layout.fillWidth:true; from:0; to:1; value:.12 }
            }
            Md3Card { Layout.fillWidth:true; Layout.fillHeight:true; title:i18n.text("actions")
                Button { Layout.fillWidth:true; implicitHeight:48; text:i18n.text("reconnect"); onClicked:websocket.reconnect() }
            }
        }
    }
}
