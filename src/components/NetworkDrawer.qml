import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "md3"

Item {
    id: root
    required property var i18n
    required property var config
    required property var network
    property bool open: false
    anchors.fill: parent
    z: 1000
    readonly property string commanderUrl: network.primaryIp ? "http://" + network.primaryIp + ":" + config.restPort + "/commander" : ""
    readonly property string qrPath: Quickshell.cachePath("commander-qr.png")
    function refreshQr() { if (commanderUrl) qr.exec(["qrencode","-o",qrPath,"-s","6","-m","2",commanderUrl]) }
    onCommanderUrlChanged: refreshQr()
    property Process qr: Process { onExited: qrImage.revision++ }

    Rectangle {
        id: drawer
        width: parent.width; height: parent.height
        y: root.open ? 0 : -height + 34
        color: Md3Theme.background
        Behavior on y { enabled: !drag.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth:true; text:root.i18n.text("network"); color:Md3Theme.onSurface; font.pixelSize:22; font.weight:Font.DemiBold }
                Button { text:root.i18n.text("refresh"); onClicked:{ root.network.refresh(); root.refreshQr() } }
                Button { text:"×"; onClicked:root.open=false }
            }
            RowLayout {
                Layout.fillWidth:true; Layout.fillHeight:true; spacing:12
                Rectangle {
                    Layout.fillWidth:true; Layout.fillHeight:true; radius:16; color:Md3Theme.surfaceContainer
                    ColumnLayout {
                        anchors.fill:parent; anchors.margins:14; spacing:8
                        RowLayout {
                            Layout.fillWidth:true
                            Text { Layout.fillWidth:true; text:"Wi-Fi"; color:Md3Theme.onSurface; font.pixelSize:18; font.weight:Font.DemiBold }
                            Switch { checked:root.network.wifiEnabled; onToggled:root.network.setWifiEnabled(checked) }
                        }
                        ListView {
                            id:wifi; Layout.fillWidth:true; Layout.fillHeight:true; spacing:6; clip:true; model:root.network.wifiNetworks
                            delegate: Rectangle {
                                required property var modelData
                                width:wifi.width; height:46; radius:12
                                color:modelData.active?Md3Theme.surfaceContainerHigh:"#23262A"
                                RowLayout {
                                    anchors.fill:parent; anchors.margins:10
                                    Text { Layout.fillWidth:true; text:modelData.ssid; color:Md3Theme.onSurface; font.pixelSize:14 }
                                    Text { text:modelData.signal+"%"; color:Md3Theme.onSurfaceVariant; font.pixelSize:12 }
                                }
                                TapHandler { onTapped:{ wifiDialog.ssid=modelData.ssid; wifiDialog.security=modelData.security; wifiDialog.open() } }
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth:true; Layout.fillHeight:true; spacing:12
                    Rectangle {
                        Layout.fillWidth:true; Layout.preferredHeight:150; radius:16; color:Md3Theme.surfaceContainer
                        ColumnLayout {
                            anchors.fill:parent; anchors.margins:14
                            Text { text:"Ethernet"; color:Md3Theme.onSurface; font.pixelSize:18; font.weight:Font.DemiBold }
                            Repeater {
                                model:root.network.ethernetDevices
                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth:true
                                    Text { Layout.fillWidth:true; text:modelData.device+" — "+modelData.state; color:Md3Theme.onSurface; font.pixelSize:14 }
                                    Button { text:modelData.state==="connected"?root.i18n.text("disconnect"):root.i18n.text("connect"); onClicked:modelData.state==="connected"?root.network.disconnectDevice(modelData.device):root.network.connectDevice(modelData.device) }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth:true; Layout.fillHeight:true; radius:16; color:Md3Theme.surfaceContainer
                        RowLayout {
                            anchors.centerIn:parent; spacing:16
                            Image { id:qrImage; property int revision:0; width:170; height:170; cache:false; source:root.commanderUrl?"file://"+root.qrPath+"?v="+revision:"" }
                            ColumnLayout {
                                Text { text:root.i18n.text("commander"); color:Md3Theme.onSurface; font.pixelSize:18; font.weight:Font.DemiBold }
                                Text { Layout.maximumWidth:260; text:root.commanderUrl||root.i18n.text("no_ip"); color:Md3Theme.onSurfaceVariant; font.pixelSize:13; wrapMode:Text.WrapAnywhere }
                            }
                        }
                    }
                }
            }
            Rectangle { Layout.alignment:Qt.AlignHCenter; width:52; height:5; radius:3; color:Md3Theme.onSurfaceVariant }
        }
        MouseArea {
            id:drag; anchors.fill:parent; drag.target:drawer; drag.axis:Drag.YAxis; drag.minimumY:-drawer.height+34; drag.maximumY:0
            onReleased:root.open=drawer.y > -drawer.height*0.55
        }
    }
    Dialog {
        id:wifiDialog; property string ssid:""; property string security:""; anchors.centerIn:parent; modal:true; title:ssid; standardButtons:Dialog.Ok|Dialog.Cancel
        TextField { id:pw; width:280; placeholderText:root.i18n.text("password"); echoMode:TextInput.Password; visible:wifiDialog.security!==""&&wifiDialog.security!=="--" }
        onAccepted:{ root.network.connectWifi(ssid,pw.text); pw.text="" }
    }
}
