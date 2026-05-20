// eventBus.ts
// @ts-ignore
import emitter from 'tiny-emitter/instance'

type EventCallback = (...args: any[]) => void

export default {
    $on: (event: string, callback: EventCallback) => emitter.on(event, callback),
    $once: (event: string, callback: EventCallback) => emitter.once(event, callback),
    $off: (event: string, callback?: EventCallback) => emitter.off(event, callback),
    $emit: (event: string, ...args: any[]) => emitter.emit(event, ...args),
}