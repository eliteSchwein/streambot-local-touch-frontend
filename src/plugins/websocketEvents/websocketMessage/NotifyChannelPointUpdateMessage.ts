import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyChannelPointUpdateMessage extends BaseMessage {
  method = 'notify_channel_point_update'

  async handle(data: any) {
    this.store.setChannelPoints(data)
  }
}
