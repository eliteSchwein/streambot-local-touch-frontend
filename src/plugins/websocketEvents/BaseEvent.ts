import type WebsocketClient from '@/plugins/webSocketClient'
import { type Websocket, WebsocketEvent } from 'websocket-ts'
import { useAppStore } from '@/stores/app'

type AppStore = ReturnType<typeof useAppStore>

export default class BaseEvent {
  webSocketClient: WebsocketClient
  store: AppStore

  name = ''
  eventTypes: WebsocketEvent[] = []

  public constructor(webSocketClient: WebsocketClient) {
    this.webSocketClient = webSocketClient
    this.store = webSocketClient.getStore()
  }

  register() {
    for (const eventType of this.eventTypes) {
      this.webSocketClient
          .getWebsocket()
          ?.addEventListener(eventType, (websocket: Websocket, event: unknown) =>
              void this.handle(websocket, event),
          )
    }
  }

  async handle(_websocket: Websocket, _event: unknown) {
    // override in child classes
  }
}