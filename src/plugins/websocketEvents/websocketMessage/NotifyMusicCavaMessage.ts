import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyMusicCavaMessage extends BaseMessage {
  method = 'notify_music_cava'

  async handle(data: any) {
    this.store.setMusicCavaData(data)
  }
}
