import BaseEvent from "@/plugins/websocketEvents/BaseEvent";
import {type Websocket, WebsocketEvent} from "websocket-ts";

export default class DisconnectEvent extends BaseEvent {
  name = 'disconnect'
  eventTypes = [WebsocketEvent.close, WebsocketEvent.error]

  async handle(websocket: Websocket, event:any) {
    this.store.setWebsocketConnected(false)
    this.store.setWebsocketConnecting(false)
    console.log('Disconnected to Websocket')
  }
}
