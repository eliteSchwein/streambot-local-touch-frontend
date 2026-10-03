import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

import "md3"
import "../dialogs"
import "../services"

Item {
    id: root

    required property var i18n
    required property var config
    required property var network
    required property var bluetooth

    property bool open: false

    z: 1000

    readonly property string runtimeDir:
        Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    readonly property string qrPath:
        runtimeDir + "/streambot-touch-commander.png"

    readonly property string commanderUrl:
            network.primaryIp !== ""
        ? "http://" + network.primaryIp + ":"
        + config.restPort + "/commander"
        : ""

    function openPowerMenu() {
        powerMenuDialog.open()
    }

    function refreshQr() {
        if (commanderUrl === "")
            return

        qrProcess.exec([
            "qrencode",
            "-o",
            qrPath,
            "-s",
            "8",
            "-m",
            "1",
            commanderUrl
        ])
    }

    onCommanderUrlChanged: refreshQr()

    onOpenChanged: {
        network.setWifiScanning(open)
        bluetooth.setAutoRefresh(open)

        if (open) {
            network.refreshPrimaryIp()
            refreshQr()
        }
    }

    property Process qrProcess: Process {
        onExited: code => {
            if (code === 0)
                qrImage.revision++
        }
    }

    function settleDrawer(openState) {
        root.open = openState
        settleAnimation.stop()
        settleAnimation.to = openState ? 0 : -drawer.height
        settleAnimation.restart()
    }

    // Android-style edge pull: the drawer itself follows the finger 1:1.
    Item {
        id: openGestureArea

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        height: root.open ? 0 : 20
        z: 30

        DragHandler {
            id: openDrag

            enabled: !root.open && !KeyboardController.visible
            target: drawer
            dragThreshold: 0
            snapMode: DragHandler.NoSnap

            xAxis.enabled: false
            yAxis.minimum: -drawer.height
            yAxis.maximum: 0

            property real lastVelocityY: 0

            onActiveChanged: {
                if (active) {
                    settleAnimation.stop()
                    lastVelocityY = 0
                } else {
                    const fastDown = lastVelocityY > 850
                    const farEnough = drawer.y > -drawer.height * 0.72
                    root.settleDrawer(fastDown || farEnough)
                }
            }

            onActiveTranslationChanged:
                lastVelocityY = centroid.velocity.y
        }
    }

    Rectangle {
        id: drawer

        width: parent.width
        height: parent.height

        y: -height
        z: 10

        color: Md3Theme.background

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // LEFT COLUMN
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight:
                            Math.max(
                                100,
                                ethernetList.implicitHeight + 28
                            )

                        title: root.i18n.text("ethernet")

                        ColumnLayout {
                            id: ethernetList

                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: root.network.ethernetDevices

                                RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true

                                            text: modelData.name
                                            color: Md3Theme.surfaceContent

                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold

                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true

                                            text:
                                                modelData.connected
                                                    ? root.i18n.text("connected")
                                                    : root.i18n.text("disconnected")

                                            color:
                                                modelData.connected
                                                    ? Md3Theme.success
                                                    : Md3Theme.surfaceVariantContent

                                            font.pixelSize: 10
                                        }
                                    }

                                    Md3Switch {
                                        checked:
                                            modelData.connected
                                            || modelData.autoconnect

                                        onClicked: {
                                            root.network.setEthernetEnabled(
                                                modelData,
                                                !(
                                                    modelData.connected
                                                    || modelData.autoconnect
                                                )
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        title: ""

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true

                                text: root.i18n.text("wifi")
                                color: Md3Theme.surfaceContent

                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }

                            Md3Button {
                                text: root.i18n.text("saved_wifi")
                                implicitHeight: 34
                                leftPadding: 10
                                rightPadding: 10
                                outlined: true

                                onClicked: {
                                    savedWifiDialog.open()
                                }
                            }

                            Md3Switch {
                                checked: root.network.wifiEnabled

                                onClicked: {
                                    root.network.setWifiEnabled(
                                        !root.network.wifiEnabled
                                    )
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.centerIn: parent

                                visible:
                                    !root.network.wifiEnabled

                                text: root.i18n.text("wifi_disabled")
                                color: Md3Theme.surfaceVariantContent

                                font.pixelSize: 13
                            }

                            Text {
                                anchors.centerIn: parent

                                visible:
                                    root.network.wifiEnabled
                                    && root.network.wifiNetworks.length === 0

                                text: root.i18n.text("no_wifi_networks")
                                color: Md3Theme.surfaceVariantContent

                                font.pixelSize: 13
                            }

                            ListView {
                                id: wifiList

                                anchors.fill: parent

                                visible:
                                    root.network.wifiEnabled
                                    && root.network.wifiNetworks.length > 0

                                clip: true
                                spacing: 5

                                model: root.network.wifiNetworks

                                delegate: Rectangle {
                                    required property var modelData

                                    width: wifiList.width
                                    height: 46

                                    radius: Md3Theme.radiusMedium

                                    color:
                                        modelData.connected
                                            ? Md3Theme.primaryContainer
                                            : Md3Theme.surfaceContainerHighest

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true

                                                text: modelData.name
                                                color: Md3Theme.surfaceContent

                                                font.pixelSize: 12
                                                font.weight:
                                                    modelData.connected
                                                        ? Font.DemiBold
                                                        : Font.Normal

                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true

                                                text:
                                                    modelData.connected
                                                        ? root.i18n.text("connected")
                                                        : modelData.known
                                                            ? root.i18n.text("saved")
                                                            : ""

                                                visible: text !== ""

                                                color:
                                                    modelData.connected
                                                        ? Md3Theme.primary
                                                        : Md3Theme.surfaceVariantContent

                                                font.pixelSize: 9
                                                font.weight:
                                                    modelData.connected
                                                        ? Font.DemiBold
                                                        : Font.Normal
                                            }
                                        }

                                        Text {
                                            text:
                                                Math.round(
                                                    modelData.signalStrength * 100
                                                )
                                                + "%"

                                            color:
                                                Md3Theme.surfaceVariantContent

                                            font.pixelSize: 10
                                        }
                                    }

                                    TapHandler {
                                        onTapped: {
                                            if (modelData.connected) {
                                                modelData.disconnect()
                                                return
                                            }

                                            if (modelData.known) {
                                                modelData.connect()
                                                return
                                            }

                                            if (
                                                modelData.security
                                                === WifiSecurityType.Open
                                            ) {
                                                modelData.connect()
                                                return
                                            }

                                            wifiDialog.network = modelData
                                            wifiDialog.open()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // RIGHT COLUMN
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 244

                        title: ""

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true

                                    text: root.i18n.text("bluetooth")
                                    color: Md3Theme.surfaceContent

                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }

                                Md3Button {
                                    text:
                                        root.bluetooth.scanning
                                        ? root.i18n.text("bluetooth_stop_scan")
                                        : root.i18n.text("bluetooth_scan")

                                    implicitHeight: 34
                                    leftPadding: 10
                                    rightPadding: 10
                                    outlined: true

                                    enabled:
                                        root.bluetooth.available
                                        && root.bluetooth.powered
                                        && !root.bluetooth.busy

                                    onClicked:
                                        root.bluetooth.setScanning(
                                            !root.bluetooth.scanning
                                        )
                                }

                                Md3Switch {
                                    checked:
                                        root.bluetooth.powered

                                    enabled:
                                        root.bluetooth.available
                                        && !root.bluetooth.busy

                                    onClicked:
                                        root.bluetooth.setPowered(
                                            !root.bluetooth.powered
                                        )
                                }
                            }

                            Text {
                                Layout.fillWidth: true

                                text:
                                    !root.bluetooth.available
                                    ? root.i18n.text("bluetooth_unavailable")
                                    : !root.bluetooth.powered
                                        ? root.i18n.text("bluetooth_disabled")
                                        : root.bluetooth.scanning
                                            ? (
                                                root.bluetooth.scanTransport === "bredr"
                                                ? root.i18n.text("bluetooth_scanning_classic")
                                                : root.i18n.text("bluetooth_scanning_le")
                                            )
                                            : root.i18n
                                                .text("bluetooth_paired_count")
                                                .replace(
                                                    "{count}",
                                                    root.bluetooth.pairedDevices.length
                                                )

                                color:
                                    root.bluetooth.scanning
                                    ? Md3Theme.primary
                                    : Md3Theme.surfaceVariantContent

                                font.pixelSize: 10
                            }

                            Text {
                                Layout.fillWidth: true
                                visible:
                                    root.bluetooth.lastError !== ""

                                text: root.bluetooth.lastError
                                color: Md3Theme.error
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 5

                                    Text {
                                        Layout.fillWidth: true
                                        visible:
                                            root.bluetooth.powered
                                            && root.bluetooth.pairedDevices.length > 0

                                        text:
                                            root.i18n.text("bluetooth_paired")

                                        color:
                                            Md3Theme.surfaceVariantContent

                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }

                                    ListView {
                                        id: pairedBluetoothList

                                        Layout.fillWidth: true
                                        Layout.preferredHeight:
                                            Math.min(
                                                82,
                                                contentHeight
                                            )

                                        visible:
                                            root.bluetooth.powered
                                            && root.bluetooth.pairedDevices.length > 0

                                        clip: true
                                        spacing: 4
                                        model:
                                            root.bluetooth.pairedDevices

                                        delegate: Rectangle {
                                            required property var modelData

                                            width:
                                                pairedBluetoothList.width
                                            height: 38

                                            radius:
                                                Md3Theme.radiusMedium

                                            color:
                                                modelData.connected
                                                ? Md3Theme.primaryContainer
                                                : Md3Theme.surfaceContainerHighest

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 6

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 0

                                                    Text {
                                                        Layout.fillWidth: true

                                                        text:
                                                            modelData.name

                                                        color:
                                                            Md3Theme.surfaceContent

                                                        font.pixelSize: 11
                                                        font.weight:
                                                            modelData.connected
                                                            ? Font.DemiBold
                                                            : Font.Normal

                                                        elide:
                                                            Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true

                                                        text:
                                                            modelData.connected
                                                            ? root.i18n.text("connected")
                                                            : root.i18n.text("disconnected")

                                                        color:
                                                            modelData.connected
                                                            ? Md3Theme.primary
                                                            : Md3Theme.surfaceVariantContent

                                                        font.pixelSize: 8
                                                    }
                                                }

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 14

                                                    color:
                                                        forgetBtTap.pressed
                                                        ? Md3Theme.errorContainer
                                                        : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent

                                                        text: "×"
                                                        color: Md3Theme.error
                                                        font.pixelSize: 20
                                                    }

                                                    TapHandler {
                                                        id: forgetBtTap

                                                        enabled:
                                                            !root.bluetooth.busy

                                                        onTapped:
                                                            root.bluetooth.forgetDevice(
                                                                modelData
                                                            )
                                                    }
                                                }
                                            }

                                            TapHandler {
                                                enabled:
                                                    !root.bluetooth.busy

                                                onTapped: {
                                                    if (modelData.connected) {
                                                        root.bluetooth.disconnectDevice(
                                                            modelData
                                                        )
                                                    } else {
                                                        root.bluetooth.connectDevice(
                                                            modelData
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true

                                        visible:
                                            root.bluetooth.powered
                                            && root.bluetooth.scanning

                                        text:
                                            root.i18n.text("bluetooth_discovered")

                                        color:
                                            Md3Theme.surfaceVariantContent

                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }

                                    ListView {
                                        id: discoveredBluetoothList

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        visible:
                                            root.bluetooth.powered
                                            && (
                                                root.bluetooth.scanning
                                                || root.bluetooth.discoveredDevices.length > 0
                                            )

                                        clip: true
                                        spacing: 4

                                        model:
                                            root.bluetooth.discoveredDevices

                                        delegate: Rectangle {
                                            required property var modelData

                                            width:
                                                discoveredBluetoothList.width
                                            height: 38

                                            radius:
                                                Md3Theme.radiusMedium

                                            color:
                                                Md3Theme.surfaceContainerHighest

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 6

                                                Text {
                                                    Layout.fillWidth: true

                                                    text: modelData.name
                                                    color:
                                                        Md3Theme.surfaceContent

                                                    font.pixelSize: 11
                                                    elide:
                                                        Text.ElideRight
                                                }

                                                Text {
                                                    text:
                                                        root.bluetooth.busy
                                                        && root.bluetooth.busyAddress
                                                            === modelData.address
                                                        ? root.i18n.text("bluetooth_pairing")
                                                        : root.i18n.text("bluetooth_pair")

                                                    color:
                                                        Md3Theme.primary

                                                    font.pixelSize: 9
                                                    font.weight:
                                                        Font.DemiBold
                                                }
                                            }

                                            TapHandler {
                                                enabled:
                                                    !root.bluetooth.busy

                                                onTapped:
                                                    root.bluetooth.pairDevice(
                                                        modelData
                                                    )
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        visible:
                                            root.bluetooth.powered
                                            && root.bluetooth.pairedDevices.length === 0
                                            && root.bluetooth.discoveredDevices.length === 0

                                        text:
                                            root.bluetooth.scanning
                                            ? (
                                                root.bluetooth.scanTransport === "bredr"
                                                ? root.i18n.text("bluetooth_scanning_classic")
                                                : root.i18n.text("bluetooth_scanning_le")
                                            )
                                            : root.i18n.text("bluetooth_no_paired")

                                        color:
                                            Md3Theme.surfaceVariantContent

                                        font.pixelSize: 11

                                        horizontalAlignment:
                                            Text.AlignHCenter
                                        verticalAlignment:
                                            Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }

                    Md3Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        title: root.i18n.text("web_access")

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Image {
                                    id: qrImage

                                    property int revision: 0

                                    anchors.centerIn: parent

                                    width: Math.min(
                                        165,
                                        parent.width - 20,
                                        parent.height - 20
                                    )

                                    height: width

                                    fillMode: Image.PreserveAspectFit
                                    cache: false

                                    source:
                                        root.commanderUrl !== ""
                                        ? "file://" + root.qrPath
                                            + "?v=" + revision
                                        : ""
                                }
                            }

                            Text {
                                Layout.fillWidth: true

                                text:
                                    root.commanderUrl !== ""
                                    ? root.commanderUrl
                                    : root.i18n.text("no_ip")

                                color:
                                    Md3Theme.surfaceVariantContent

                                font.pixelSize: 14

                                horizontalAlignment:
                                    Text.AlignHCenter

                                wrapMode: Text.WrapAnywhere

                                maximumLineCount: 2
                                elide: Text.ElideMiddle
                            }
                        }
                    }


                }
            }

            // Space reserved for the external drag handle below.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
            }
        }
    }

    // The close handle is a sibling of the moving drawer. This avoids
    // coordinate/grab weirdness from dragging an ancestor of the handler.
    Item {
        id: closeGestureArea

        x: 0
        y: drawer.y + drawer.height - height
        width: root.width
        height: 28
        z: 40

        visible: root.open || closeDrag.active

        Rectangle {
            width: 48
            height: 5
            radius: 3
            anchors.centerIn: parent
            color: Md3Theme.surfaceVariantContent
        }

        DragHandler {
            id: closeDrag

            enabled: root.open && !KeyboardController.visible
            target: drawer
            dragThreshold: 0
            snapMode: DragHandler.NoSnap

            xAxis.enabled: false
            yAxis.minimum: -drawer.height
            yAxis.maximum: 0

            property real lastVelocityY: 0

            onActiveChanged: {
                if (active) {
                    settleAnimation.stop()
                    lastVelocityY = 0
                } else {
                    const fastUp = lastVelocityY < -850
                    const farEnough = drawer.y < -drawer.height * 0.28
                    root.settleDrawer(!(fastUp || farEnough))
                }
            }

            onActiveTranslationChanged:
                lastVelocityY = centroid.velocity.y
        }

        TapHandler {
            enabled: root.open && !KeyboardController.visible
            gesturePolicy: TapHandler.DragThreshold
            onTapped: root.settleDrawer(false)
        }
    }

    NumberAnimation {
        id: settleAnimation

        target: drawer
        property: "y"
        duration: 190
        easing.type: Easing.OutCubic
    }

    PowerMenuDialog {
        id: powerMenuDialog

        // Must stay above the shell-level connection/status dialog.
        z: 10000000
        i18n: root.i18n
    }

    WifiConnectDialog {
        id: wifiDialog
        i18n: root.i18n
    }

    SavedWifiDialog {
        id: savedWifiDialog

        i18n: root.i18n
        network: root.network

        onDeleteRequested: function(connection) {
            deleteWifiDialog.connection = connection
            deleteWifiDialog.title =
                root.i18n.text("delete_saved_wifi")
            deleteWifiDialog.message =
                root.i18n
                    .text("delete_saved_wifi_text")
                    .replace("%1", connection.name)
            deleteWifiDialog.open()
        }
    }

    ConfirmDialog {
        id: deleteWifiDialog

        z: 700000
        i18n: root.i18n
        property var connection: null

        onConfirmed: {
            if (connection !== null) {
                connection.forget()
                connection = null
            }
        }

        onClosed: {
            connection = null
        }
    }
}
