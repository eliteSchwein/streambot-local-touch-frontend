import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "components"
import "components/audio"
import "components/md3"
import "dialogs"
import "pages"
import "services"

ShellRoot {
    Config {
        id: config
    }

    I18n {
        id: i18n
        language: config.language
    }

    BackendStatus {
        id: backendStatus

        restUrl: config.restUrl
        websocket: websocket
    }

    WsClient {
        id: websocket

        url: config.websocketUrl

        // Same basic order as the old Vue reconnect loop:
        // do not establish WS until /api/status reports ready=true.
        enabled: backendStatus.ready
    }

    CavaClient {
        id: cavaMusicPreview

        baseUrl: config.websocketUrl
        target: "music_preview"

        // CAVA has a dedicated, registration-free websocket in Backend 2.0.
        // Keep it separate from the normal dashboard/state traffic.
        enabled: backendStatus.ready
    }

    NetworkManager {
        id: network
    }

    BluetoothManager {
        id: bluetooth
    }

    DashboardStore {
        id: dashboardStore
    }

    ThemeManager {
        id: themeManager
        wallpaperPath: config.touchWallpaperPath
    }

    IpcHandler {
        target: "streambot-touch"

        function openPowerMenu(): void {
            powerMenu.open()
        }
    }

    Connections {
        target: websocket

        function onJsonReceived(data) {
            config.handleMessage(data)
            dashboardStore.handleMessage(data)
        }

        function onConnectionChanged(connected) {
            if (!connected)
                dashboardStore.resetEndpointSnapshots()
        }
    }

    Connections {
        target: cavaMusicPreview

        function onJsonReceived(data) {
            dashboardStore.handleMessage(data)
        }
    }

    PanelWindow {
        id: window
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        focusable: true
        exclusionMode: ExclusionMode.Ignore
        color: Md3Theme.background

        Image {
            id: touchWallpaper
            anchors.fill: parent
            visible: config.touchWallpaperUrl !== ""
            source: config.touchWallpaperUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false

            onStatusChanged: {
                if (status === Image.Error) {
                    console.warn(
                        "[wallpaper] failed to decode:",
                        source
                    )
                }
            }

            Component.onCompleted:
                Md3Theme.wallpaperItem = touchWallpaper
        }

        Rectangle {
            id: wallpaperTint
            anchors.fill: parent
            visible: touchWallpaper.visible
            color: Qt.rgba(
                Md3Theme.background.r,
                Md3Theme.background.g,
                Md3Theme.background.b,
                0.40
            )
        }

        Rectangle {
            id: appRoot

            property int currentPage: 0
            property int previousPage: 0
            property int pageTransitionDirection: 1
            property bool bootAnimationStarted: false

            onCurrentPageChanged: {
                pageTransitionDirection =
                        currentPage >= previousPage ? 1 : -1

                previousPage = currentPage

                if (currentPage !== 0)
                    dashboardPage.editing = false
            }

            Component.onCompleted:
                Qt.callLater(function() {
                    appRoot.bootAnimationStarted = true
                })

            readonly property bool backendStatusActive:
                !backendStatus.ready || !websocket.connected

            component PageTransition: Item {
                id: transitionRoot

                required property bool active
                property int direction: 1

                visible:
                    active
                    || Math.abs(x) < width

                opacity:
                    active ? 1 : 0.98

                x:
                    active
                    ? 0
                    : -direction * width

                Behavior on x {
                    NumberAnimation {
                        duration: 210
                        easing.type: Easing.OutCubic
                    }
                }
            }

            anchors.fill: parent
            color: touchWallpaper.visible ? "transparent" : Md3Theme.background

            PageTransition {
                active:
                    !appRoot.backendStatusActive
                    && appRoot.currentPage === 0

                direction:
                    appRoot.pageTransitionDirection

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                DashboardPage {
                    id: dashboardPage

                    anchors.fill: parent

                    opacity:
                        appRoot.bootAnimationStarted
                            ? 1
                            : 0

                    scale:
                        appRoot.bootAnimationStarted
                            ? 1
                            : 0.965

                    transformOrigin:
                        Item.Center

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 520
                            easing.type: Easing.OutBack
                        }
                    }

                    z:
                        dashboardPage.editing
                            ? 100000
                            : 0

                    i18n: i18n
                    websocket: websocket
                    store: dashboardStore
                    config: config
                }
            }

            PageTransition {
                active:
                    !appRoot.backendStatusActive
                    && appRoot.currentPage === 1

                direction:
                    appRoot.pageTransitionDirection

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                AudioPage {
                    id: audioPage
                    anchors.fill: parent

                    i18n: i18n
                    websocket: websocket
                    store: dashboardStore
                }
            }

            PageTransition {
                active:
                    !appRoot.backendStatusActive
                    && appRoot.currentPage === 2

                direction:
                    appRoot.pageTransitionDirection

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                MacrosPage {
                    id: macrosPage
                    anchors.fill: parent

                    i18n: i18n
                    store: dashboardStore
                    websocket: websocket
                }
            }

            PageTransition {
                active:
                    !appRoot.backendStatusActive
                    && appRoot.currentPage === 3

                direction:
                    appRoot.pageTransitionDirection

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                SystemPage {
                    id: systemPage
                    anchors.fill: parent

                    i18n: i18n
                    websocket: websocket
                    store: dashboardStore
                    config: config
                }
            }

            PageTransition {
                active:
                    !appRoot.backendStatusActive
                    && appRoot.currentPage === 4

                direction:
                    appRoot.pageTransitionDirection

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                SpeedtestPage {
                    id: speedtestPage
                    anchors.fill: parent

                    i18n: i18n
                    websocket: websocket
                    store: dashboardStore
                }
            }

            BackendStatusView {
                id: backendStatusView

                visible: appRoot.backendStatusActive

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                i18n: i18n
                websocket: websocket
                backendStatus: backendStatus
            }

            Rectangle {
                id: navigation

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                height: 52
                color: Md3Theme.surfaceContainer

                opacity:
                    appRoot.bootAnimationStarted
                        ? 1
                        : 0

                transform: Translate {
                    id: navigationBootTranslate

                    y:
                        appRoot.bootAnimationStarted
                            ? 0
                            : 24

                    Behavior on y {
                        NumberAnimation {
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }

                property real bootOffset:
                    appRoot.bootAnimationStarted
                        ? 0
                        : 24

                Behavior on bootOffset {
                    NumberAnimation {
                        duration: 420
                        easing.type: Easing.OutCubic
                    }
                }

                // While the drawer is open, its bottom gesture area overlaps
                // the nav visually. Disable the whole nav subtree so taps
                // cannot leak through and steal the drag gesture.
                enabled:
                    appRoot.bootAnimationStarted
                    && !settingsDrawer.open
                    && !KeyboardController.visible

                // Keep actual page navigation centered regardless of
                // the power button on the far right.
                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Md3NavButton {
                        icon: "home"
                        selected: appRoot.currentPage === 0

                        onClicked:
                            appRoot.currentPage = 0
                    }

                    Md3NavButton {
                        icon: "volume-high"
                        selected: appRoot.currentPage === 1

                        onClicked:
                            appRoot.currentPage = 1
                    }

                    Md3NavButton {
                        icon: "tune"
                        selected: appRoot.currentPage === 2

                        onClicked:
                            appRoot.currentPage = 2
                    }

                    Md3NavButton {
                        icon: "server"
                        selected: appRoot.currentPage === 3
                        badgeCount: dashboardStore.updatesAvailableCount

                        onClicked:
                            appRoot.currentPage = 3
                    }

                    Md3NavButton {
                        icon: "speedometer"
                        selected: appRoot.currentPage === 4

                        onClicked:
                            appRoot.currentPage = 4
                    }
                }

                // Dashboard editor action. Only exists visually while the
                // Dashboard page is active.
                Rectangle {
                    id: navDashboardEditButton

                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }

                    width: 40
                    height: 40
                    radius: 20

                    visible:
                        !appRoot.backendStatusActive
                        && appRoot.currentPage === 0

                    color:
                        dashboardPage.editing
                            ? Md3Theme.primaryContainer
                            : (
                                navDashboardEditTap.pressed
                                    ? Md3Theme.surfaceContainerHigh
                                    : "transparent"
                            )

                    Text {
                        anchors.centerIn: parent

                        text: "✎"
                        color:
                            dashboardPage.editing
                                ? Md3Theme.surfaceContent
                                : Md3Theme.surfaceVariantContent

                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }

                    TapHandler {
                        id: navDashboardEditTap

                        onTapped:
                            dashboardPage.editing =
                                !dashboardPage.editing
                    }
                }

                // Global power action, deliberately not part of the centered
                // page-navigation Row.
                Rectangle {
                    id: navPowerButton

                    anchors {
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }

                    width: 40
                    height: 40
                    radius: 20

                    color:
                        navPowerTap.pressed
                            ? Md3Theme.surfaceContainerHigh
                            : "transparent"

                    MdiIcon {
                        anchors.centerIn: parent

                        name: "power"
                        size: 21
                    }

                    TapHandler {
                        id: navPowerTap

                        onTapped:
                            powerMenu.open()
                    }
                }
            }

            NetworkDrawer {
                id: settingsDrawer

                anchors.fill: parent

                i18n: i18n
                config: config
                network: network
                bluetooth: bluetooth
            }

            AudioVolumeOsd {
                id: audioVolumeOsd

                anchors.fill: parent

                websocket: websocket

                // The controls already show the live value on the Audio page.
                suppressed: appRoot.currentPage === 1
            }

            // Global top-most dialog. Keep this outside NetworkDrawer so its z
            // is compared directly with Md3Keyboard.
            PowerMenuDialog {
                id: powerMenu

                anchors.fill: parent
                z: 20000000

                i18n: i18n
            }

            Md3Keyboard {
                id: keyboard

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                z: 10000000
                language: config.language
            }

        }
    }
}
