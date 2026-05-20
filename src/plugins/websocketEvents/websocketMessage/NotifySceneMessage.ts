import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifySceneMessage extends BaseMessage {
  method = 'notify_source_update'

  async handle(data: any) {
    this.store.setScene(data)
  }
}
