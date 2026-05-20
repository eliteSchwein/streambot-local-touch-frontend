import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyYoloboxUpdateMessage extends BaseMessage {
  method = 'notify_yolobox_update'

  async handle(data: any) {
    this.store.setYoloboxData(data)
  }
}
