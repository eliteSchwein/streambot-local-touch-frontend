import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyGiveawayUpdateMessage extends BaseMessage {
  method = 'notify_giveaway_update'

  async handle(data: any) {
    this.store.setGiveaway(data)
  }
}
