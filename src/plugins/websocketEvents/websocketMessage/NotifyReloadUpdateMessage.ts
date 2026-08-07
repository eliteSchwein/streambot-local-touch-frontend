import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyReloadUpdateMessage extends BaseMessage {
  method = 'notify_reload_update'

  async handle(data: any) {
    this.store.setReloadUpdate(data)
  }
}
