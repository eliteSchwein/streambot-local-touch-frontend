import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyThrottledMessage extends BaseMessage {
  method = 'notify_throttle'

  async handle(data: any) {
    this.store.setThrottled(data)
  }
}
