import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyConnectionUpdateMessage extends BaseMessage {
  method = 'notify_connection_update'

  async handle(data: any) {
    this.store.setConnectionData(data)
  }
}
