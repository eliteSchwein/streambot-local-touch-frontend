import type WebsocketClient from '@/plugins/webSocketClient'
import { getRandomInt } from '@/helper/GeneralHelper'
import { useAppStore } from '@/stores/app'

type AppStore = ReturnType<typeof useAppStore>

export default class BaseMessage {
  webSocketClient: WebsocketClient
  store: AppStore
  method = ''
  id: number = getRandomInt(10_000)

  public constructor(webSocketClient: WebsocketClient) {
    this.webSocketClient = webSocketClient
    this.store = webSocketClient.getStore()
  }

  public async handleMessage(data: any) {
    if (data.method !== this.method) return

    if (data.id) {
      this.id = data.id
    }

    await this.handle(data.params)
  }

  public send(method: string, data: any = {}) {
    this.webSocketClient.send(method, data)
  }

  async handle(_data: any) {
    // override in child classes
  }
}