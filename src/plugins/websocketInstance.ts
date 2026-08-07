import type WebsocketClient from "@/plugins/webSocketClient"

let websocketClient: WebsocketClient | undefined

export function getWebsocketClient() {
  return websocketClient
}

export function setWebsocketClient(client: WebsocketClient | undefined) {
  websocketClient = client
}
