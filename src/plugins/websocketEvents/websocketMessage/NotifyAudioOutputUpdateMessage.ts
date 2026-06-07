import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyAudioOutputUpdateMessage extends BaseMessage {
  method = 'notify_audio_outputs_update'

  async handle(data: any) {
    this.store.setAudioOutput(data)
  }
}
