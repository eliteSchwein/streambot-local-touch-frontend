import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";

export default class NotifyAssetsUpdateMessage extends BaseMessage {
  method = 'notify_assets_update'

  async handle(data: any) {
    this.store.setAssets(data)
  }
}
