import QtQuick
import Quickshell.Io
QtObject {
    id: root
    property bool wifiEnabled: false
    property var wifiNetworks: []
    property var ethernetDevices: []
    property string primaryIp: ""
    function refresh() { wifiState.running=true; wifiList.running=true; ethernet.running=true; primary.running=true }
    function setWifiEnabled(v) { wifiToggle.exec(["nmcli","radio","wifi",v?"on":"off"]) }
    function connectWifi(ssid,password) {
        let a=["nmcli","device","wifi","connect",ssid]
        if (password) a.push("password",password)
        wifiConnect.exec(a)
    }
    function connectDevice(d) { deviceProc.exec(["nmcli","device","connect",d]) }
    function disconnectDevice(d) { deviceProc.exec(["nmcli","device","disconnect",d]) }
    property Process wifiState: Process {
        command:["nmcli","-t","-f","WIFI","general"]
        stdout: StdioCollector { onStreamFinished: root.wifiEnabled=text.trim().toLowerCase()==="enabled" }
    }
    property Process wifiList: Process {
        command:["nmcli","-t","-f","IN-USE,SSID,SIGNAL,SECURITY","device","wifi","list","--rescan","yes"]
        stdout: StdioCollector { onStreamFinished: {
            let arr=[], seen={}
            for (const l of text.trim().split("\n")) {
                const p=l.split(":"); if (p.length<4 || !p[1] || seen[p[1]]) continue
                seen[p[1]]=true; arr.push({active:p[0]==="*",ssid:p[1],signal:parseInt(p[2])||0,security:p.slice(3).join(":")})
            }
            arr.sort((a,b)=>a.active!==b.active?(a.active?-1:1):b.signal-a.signal); root.wifiNetworks=arr
        }}
    }
    property Process ethernet: Process {
        command:["nmcli","-t","-f","DEVICE,TYPE,STATE,CONNECTION","device","status"]
        stdout: StdioCollector { onStreamFinished: {
            let arr=[]
            for (const l of text.trim().split("\n")) { const p=l.split(":"); if(p.length>=4&&p[1]==="ethernet") arr.push({device:p[0],state:p[2],connection:p.slice(3).join(":")}) }
            root.ethernetDevices=arr
        }}
    }
    property Process primary: Process {
        command:["sh","-c","ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") {print $(i+1); exit}}'"]
        stdout: StdioCollector { onStreamFinished: root.primaryIp=text.trim() }
    }
    property Process wifiToggle: Process { onExited: root.refresh() }
    property Process wifiConnect: Process { onExited: root.refresh() }
    property Process deviceProc: Process { onExited: root.refresh() }
    Component.onCompleted: refresh()
}
