import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyAlertQueryMessage extends BaseMessage {
  method = 'notify_alert_query'

  async handle(data: any) {
    this.store.setAlerts(data)
  }
}
