import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyConnectionMessage extends BaseMessage {
  method = 'notify_connection'

  async handle(data: any) {
    this.store.setConnections(data)
  }
}
