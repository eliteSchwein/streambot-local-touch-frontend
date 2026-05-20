import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyShieldModeMessage extends BaseMessage {
  method = 'notify_shield_mode'

  async handle(data: any) {
    this.store.setShieldActive(data.action === 'enable')
  }
}
