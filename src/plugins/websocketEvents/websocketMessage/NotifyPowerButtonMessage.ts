import BaseMessage from "@/plugins/websocketEvents/websocketMessage/BaseMessage.ts";
import {isLocalhost} from "@/helper/GeneralHelper.ts";
import eventBus from "@/eventBus.ts";

export default class NotifyPowerButtonMessage extends BaseMessage {
  method = 'notify_power_button'

  async handle(data: any) {
    if(!isLocalhost()) return

    eventBus.$emit('dialog:show', 'power')
  }
}
