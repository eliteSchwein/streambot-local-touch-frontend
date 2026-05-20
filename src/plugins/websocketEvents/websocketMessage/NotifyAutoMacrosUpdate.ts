import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyAutoMacrosUpdate extends BaseMessage {
  method = 'notify_auto_macros_update'

  async handle(data: any) {
    this.store.setAutoMacros(data)
  }
}
