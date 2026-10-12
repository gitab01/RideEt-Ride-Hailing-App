import { Client } from '@stomp/stompjs'

/**
 * Subscribe to an admin topic with a raw WebSocket.
 *
 * The STOMP client is used directly rather than through sockjs-client because the latter
 * expects a Node `global`, which crashes under Vite. Returns the teardown the caller passes
 * straight to useEffect.
 */
export function subscribeAdmin(destination: string, onFrame: (body: string) => void) {
  const token = localStorage.getItem('admin_token')
  const wsProto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  const client = new Client({
    brokerURL: `${wsProto}//${window.location.host}/api/v1/ws`,
    connectHeaders: { Authorization: `Bearer ${token}` },
    onConnect: () => client.subscribe(destination, msg => onFrame(msg.body)),
    reconnectDelay: 5_000,
  })
  client.activate()
  return () => { client.deactivate() }
}
