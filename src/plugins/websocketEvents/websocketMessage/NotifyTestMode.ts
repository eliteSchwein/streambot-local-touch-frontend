import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyTestMode extends BaseMessage {
  method = 'notify_test_mode'

  async handle(data: any) {
    this.store.setTestMode(data.active)
  }
}
