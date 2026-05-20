import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyObsAudioUpdateMessage extends BaseMessage {
  method = "notify_obs_audio_update"

  async handle(data: any) {
    this.store.setObsAudioData(data)
  }
}
