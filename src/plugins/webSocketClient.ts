import {Websocket} from "websocket-ts";
import {getRandomInt, sleep} from "@/helper/GeneralHelper";
import {useAppStore} from "@/stores/app";
import ConnectEvent from "@/plugins/websocketEvents/ConnectEvent";
import MessageEvent from "@/plugins/websocketEvents/MessageEvent";
import DisconnectEvent from "@/plugins/websocketEvents/DisconnectEvent";

export default class WebsocketClient {
  url = ''
  websocket: Websocket|undefined = undefined
  store: useAppStore

  public constructor(
    url: string,
    store: useAppStore
  ) {
    this.url = url
    this.store = store
  }

  public setUrl(url: string) {
    this.url = url;
  }

  public async disconnect() {
    if(this.websocket) {
      this.websocket.close()
      await sleep(100)
    }
  }

  public async connect() {
    await this.disconnect()

    console.log("Connecting to Websocket")
    this.store.setWebsocketConnecting(true)

    this.websocket = new Websocket(this.url)

    this.registerEvents()
  }

  public getWebsocket() {
    return this.websocket;
  }

  public getStore() {
    return this.store;
  }

  private registerEvents() {
    void new ConnectEvent(this).register()
    void new DisconnectEvent(this).register()
    void new MessageEvent(this).register()
  }

  public send(method: string, data: any = {}) {
    try {
      this.websocket?.send(JSON.stringify({jsonrpc: "2.0", method: method, params: data, id: getRandomInt(10_000)}))
    } catch (error) {
      console.error('request to a websocket client failed!')
      console.error(JSON.stringify(error, Object.getOwnPropertyNames(error)))
    }
  }
}
