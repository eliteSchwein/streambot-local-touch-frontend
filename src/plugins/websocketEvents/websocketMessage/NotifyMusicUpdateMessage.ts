import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyMusicUpdateMessage extends BaseMessage {
  method = 'notify_music_update'

  async handle(data: any) {
    this.store.setMusicData(data)
  }
}
