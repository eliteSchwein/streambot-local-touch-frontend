import BaseEvent from '@/plugins/websocketEvents/BaseEvent'
import { type Websocket, WebsocketEvent } from 'websocket-ts'

export default class DisconnectEvent extends BaseEvent {
  name = 'disconnect'
  eventTypes: WebsocketEvent[] = [
    WebsocketEvent.close,
    WebsocketEvent.error,
  ]

  async handle(_websocket: Websocket, _event: unknown) {
    this.store.setWebsocketConnected(false)
    this.store.setWebsocketConnecting(false)

    console.log('Disconnected to Websocket')
  }
}