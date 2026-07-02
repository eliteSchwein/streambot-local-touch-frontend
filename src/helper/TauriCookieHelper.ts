export async function clearTauriCookies() {
    try {
        const { getCurrentWebview } = await import('@tauri-apps/api/webview')

        await getCurrentWebview().clearAllBrowsingData()
    } catch (error) {
        console.debug('clear tauri cookies skipped', error)
    }
}