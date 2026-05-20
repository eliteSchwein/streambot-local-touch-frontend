import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage";

export default class NotifyObsSceneUpdateMessage extends BaseMessage {
  method = 'notify_obs_scene_update'

  async handle(data: any) {
    this.store.setObsSceneData(data)
  }
}
