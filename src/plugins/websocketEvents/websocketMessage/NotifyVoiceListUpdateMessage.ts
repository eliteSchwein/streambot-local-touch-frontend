import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyVoiceListUpdateMessage extends BaseMessage {
  method = 'notify_voice_list_update'

  async handle(data: any) {
    this.store.setVoices(data.voices)
  }
}
