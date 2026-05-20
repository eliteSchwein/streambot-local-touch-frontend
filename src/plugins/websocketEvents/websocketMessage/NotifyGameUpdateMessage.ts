import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyGameUpdateMessage extends BaseMessage {
  method = 'notify_game_update'

  async handle(data: any) {
    this.store.setCurrentGame(data.data)
  }
}
