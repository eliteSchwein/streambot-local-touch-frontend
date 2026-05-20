import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyAudioUpdateMessage extends BaseMessage {
  method = 'notify_audio_update'

  async handle(data: any) {
    this.store.setAudioData(data)
  }
}
