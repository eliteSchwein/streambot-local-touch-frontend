import BaseEvent from '@/plugins/websocketEvents/BaseEvent'
import { type Websocket, WebsocketEvent } from 'websocket-ts'
import eventBus from '@/eventBus.ts'

export default class ConnectEvent extends BaseEvent {
  name = 'connect'
  eventTypes: WebsocketEvent[] = [WebsocketEvent.open, WebsocketEvent.reconnect]

  async handle(_websocket: Websocket, _event: unknown) {
    this.store.setWebsocketConnected(true)
    this.store.setWebsocketConnecting(false)

    this.webSocketClient.send('register_endpoints', ['all'])

    eventBus.$emit('websocket:connected', {})
    console.log('Connected to Websocket')
  }
}