import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyIntegrationsUpdateMessage extends BaseMessage {
  method = 'notify_integrations_update'

  async handle(data: any) {
    this.store.setIntegrations(data)
  }
}
