import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyMacroUpdateMessage extends BaseMessage {
  method = 'notify_macro_update'

  async handle(data: any) {
    this.store.setMacros(data.macros)
  }
}
