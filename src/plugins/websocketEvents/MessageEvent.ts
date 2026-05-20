import BaseEvent from '@/plugins/websocketEvents/BaseEvent'
import { type Websocket, WebsocketEvent } from 'websocket-ts'
import NotifyAlertQueryMessage from '@/plugins/websocketEvents/websocketMessage/NotifyAlertQueryMessage'
import NotifyGameUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyGameUpdateMessage'
import NotifyShieldModeMessage from '@/plugins/websocketEvents/websocketMessage/NotifyShieldModeMessage'
import NotifyChannelPointUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyChannelPointUpdateMessage'
import NotifyAudioUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyAudioUpdateMessage'
import NotifySystemInfoMessage from '@/plugins/websocketEvents/websocketMessage/NotifySystemInfoMessage.ts'
import NotifySceneMessage from '@/plugins/websocketEvents/websocketMessage/NotifySceneMessage.ts'
import NotifyConnectionMessage from '@/plugins/websocketEvents/websocketMessage/NotifyConnectionMessage.ts'
import NotifyConfigUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyConfigUpdateMessage.ts'
import NotifyObsSceneUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyObsSceneUpdateMessage.ts'
import NotifyTestMode from '@/plugins/websocketEvents/websocketMessage/NotifyTestMode.ts'
import NotifyPowerButtonMessage from '@/plugins/websocketEvents/websocketMessage/NotifyPowerButtonMessage.ts'
import NotifyVoiceListUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyVoiceListUpdateMessage.ts'
import NotifyMacroUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyMacroUpdateMessage.ts'
import NotifyAutoMacrosUpdate from '@/plugins/websocketEvents/websocketMessage/NotifyAutoMacrosUpdate.ts'
import NotifyVariableUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyVariableUpdateMessage.ts'
import NotifyGiveawayUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyGiveawayUpdateMessage.ts'
import NotifyYoloboxUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyYoloboxUpdateMessage.ts'
import NotifyObsAudioUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyObsAudioUpdateMessage.ts'
import NotifyAssetsUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyAssetsUpdateMessage.ts'
import NotifyDisconnectMessage from '@/plugins/websocketEvents/websocketMessage/NotifyDisconnectMessage.ts'
import NotifyMusicUpdateMessage from '@/plugins/websocketEvents/websocketMessage/NotifyMusicUpdateMessage.ts'

type JsonRpcMessage = {
  method?: string
  params?: {
    error?: unknown
    [key: string]: unknown
  }
  id?: number
}

export default class MessageEvent extends BaseEvent {
  name = 'message'
  eventTypes: WebsocketEvent[] = [WebsocketEvent.message]

  async handle(_websocket: Websocket, event: globalThis.MessageEvent) {
    const data = JSON.parse(String(event.data)) as JsonRpcMessage

    if (data.params?.error) {
      console.warn(data)
      return
    }

    await new NotifyDisconnectMessage(this.webSocketClient).handleMessage(data)
    await new NotifyAlertQueryMessage(this.webSocketClient).handleMessage(data)
    await new NotifyGameUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyShieldModeMessage(this.webSocketClient).handleMessage(data)
    await new NotifyChannelPointUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyAudioUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifySystemInfoMessage(this.webSocketClient).handleMessage(data)
    await new NotifySceneMessage(this.webSocketClient).handleMessage(data)
    await new NotifyConnectionMessage(this.webSocketClient).handleMessage(data)
    await new NotifyConfigUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyObsSceneUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyTestMode(this.webSocketClient).handleMessage(data)
    await new NotifyPowerButtonMessage(this.webSocketClient).handleMessage(data)
    await new NotifyVoiceListUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyMacroUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyAutoMacrosUpdate(this.webSocketClient).handleMessage(data)
    await new NotifyVariableUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyGiveawayUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyYoloboxUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyObsAudioUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyAssetsUpdateMessage(this.webSocketClient).handleMessage(data)
    await new NotifyMusicUpdateMessage(this.webSocketClient).handleMessage(data)
  }
}