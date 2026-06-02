import { Websocket, WebsocketEvent } from 'websocket-ts'
import { getRandomInt, sleep } from '@/helper/GeneralHelper'
import { useAppStore } from '@/stores/app'
import ConnectEvent from '@/plugins/websocketEvents/ConnectEvent'
import MessageEvent from '@/plugins/websocketEvents/MessageEvent'
import DisconnectEvent from '@/plugins/websocketEvents/DisconnectEvent'

type AppStore = ReturnType<typeof useAppStore>
type PendingRequest = {
  resolve: (value: any) => void
  reject: (error: any) => void
  timeout: number
}

export default class WebsocketClient {
  url = ''
  websocket: Websocket | undefined = undefined
  store: AppStore
  pendingRequests: Record<number, PendingRequest> = {}

  public constructor(url: string, store: AppStore) {
    this.url = url
    this.store = store
  }

  public setUrl(url: string) {
    this.url = url
  }

  public async disconnect() {
    this.clearPendingRequests(new Error('websocket disconnected'))

    if (this.websocket) {
      this.websocket.close()
      await sleep(100)
    }
  }

  public async connect() {
    await this.disconnect()

    console.log('Connecting to Websocket')
    this.store.setWebsocketConnecting(true)

    this.websocket = new Websocket(this.url)

    this.registerEvents()
    this.registerRequestHandler()
  }

  public getWebsocket() {
    return this.websocket
  }

  public getStore() {
    return this.store
  }

  private registerEvents() {
    void new ConnectEvent(this).register()
    void new DisconnectEvent(this).register()
    void new MessageEvent(this).register()
  }

  public send(method: string, data: any = {}) {
    try {
      this.websocket?.send(
          JSON.stringify({
            jsonrpc: '2.0',
            method,
            params: data,
            id: getRandomInt(10_000),
          }),
      )
    } catch (error) {
      console.error('request to a websocket client failed!')
      console.error(JSON.stringify(error, Object.getOwnPropertyNames(error)))
    }
  }

  public request(method: string, data: any = {}, timeoutMs = 10_000): Promise<any> {
    return new Promise((resolve, reject) => {
      if (!this.websocket) {
        reject(new Error('websocket is not connected'))
        return
      }

      const id = getRandomInt(10_000)
      const timeout = window.setTimeout(() => {
        delete this.pendingRequests[id]
        reject(new Error(`${method} websocket request timed out`))
      }, timeoutMs)

      this.pendingRequests[id] = { resolve, reject, timeout }

      try {
        this.websocket.send(
            JSON.stringify({
              jsonrpc: '2.0',
              method,
              params: data,
              id,
            }),
        )
      } catch (error) {
        window.clearTimeout(timeout)
        delete this.pendingRequests[id]
        reject(error)
      }
    })
  }

  private registerRequestHandler() {
    const socket = this.websocket as any
    if (!socket) return

    const handler = (...args: any[]) => {
      const event = args.length > 1 ? args[1] : args[0]
      this.handleRequestMessage(event)
    }

    if (typeof socket.addEventListener === 'function') {
      try {
        socket.addEventListener(WebsocketEvent.message, handler)
      } catch {
        socket.addEventListener('message', handler)
      }

      return
    }

    if (typeof socket.on === 'function') {
      socket.on('message', handler)
    }
  }

  private handleRequestMessage(event: any) {
    const message = this.parseMessage(event)
    if (!message?.id) return

    const pending = this.pendingRequests[message.id]
    if (!pending) return

    window.clearTimeout(pending.timeout)
    delete this.pendingRequests[message.id]

    if (message.error) {
      pending.reject(message.error)
      return
    }

    pending.resolve(message.params ?? message.data ?? message)
  }

  private parseMessage(event: any): any {
    const raw = event?.data ?? event

    if (typeof raw === 'string') {
      try {
        return JSON.parse(raw)
      } catch {
        return null
      }
    }

    return raw
  }

  private clearPendingRequests(error: Error) {
    for (const id of Object.keys(this.pendingRequests)) {
      const request = this.pendingRequests[Number(id)]
      window.clearTimeout(request.timeout)
      request.reject(error)
      delete this.pendingRequests[Number(id)]
    }
  }
}
