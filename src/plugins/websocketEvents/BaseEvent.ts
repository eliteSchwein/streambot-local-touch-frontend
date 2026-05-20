import type {WebsocketClient} from "@/plugins/webSocketClient";
import type {Store} from "pinia";
import {type Websocket, WebsocketEvent} from "websocket-ts";
import {useAppStore} from "@/stores/app";

export default class BaseEvent {
  webSocketClient: WebsocketClient
  store: useAppStore

  name: string
  eventTypes: WebsocketEvent[]

  public constructor(webSocketClient: WebsocketClient) {
    this.webSocketClient = webSocketClient
    this.store = webSocketClient.getStore()
  }

  register() {
    for(const eventType of this.eventTypes) {
      this.webSocketClient?.getWebsocket()?.addEventListener(eventType, (websocket: Websocket, event: any) => void this.handle(websocket, event))
    }
  }

  async handle(websocket: Websocket, event: any) {

  }
}
