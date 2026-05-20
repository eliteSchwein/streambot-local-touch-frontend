import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifySystemInfoMessage extends BaseMessage {
  method = 'notify_system_info'

  async handle(data: any) {
    this.store.setSystemInfo(data)
  }
}
