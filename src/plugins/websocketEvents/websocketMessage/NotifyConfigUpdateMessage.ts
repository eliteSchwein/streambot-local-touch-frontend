import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyConfigUpdateMessage extends BaseMessage {
  method = 'notify_config_update'

  async handle(data: any) {
    this.store.setBackendConfig(data.data.raw, data.data.parsed)
  }
}
