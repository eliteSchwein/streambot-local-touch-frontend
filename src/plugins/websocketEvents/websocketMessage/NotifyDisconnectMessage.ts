import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyDisconnectMessage extends BaseMessage {
  method = 'notify_disconnect'

  async handle(data: any) {
    if(!data.reason) return

    if(data.reason !== 'auth in progress') return

    window.location.reload()
  }
}
