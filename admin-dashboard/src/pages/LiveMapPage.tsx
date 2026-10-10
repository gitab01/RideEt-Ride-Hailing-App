import { useEffect, useRef, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Client } from '@stomp/stompjs'
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet'
import L from 'leaflet'
import { adminApi } from '../api/client'
import 'leaflet/dist/leaflet.css'

// Fix leaflet default marker icons
delete (L.Icon.Default.prototype as any)._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl:       'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl:     'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
})

const driverIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-blue.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
})

interface DriverLocation {
  driverId: number
  latitude: number
  longitude: number
  heading: number
  speed: number
}

export default function LiveMapPage() {
  const [driverLocations, setDriverLocations] = useState<Map<number, DriverLocation>>(new Map())
  const stompRef = useRef<Client | null>(null)

  const { data: activeRides } = useQuery({
    queryKey: ['active-rides'],
    queryFn: () => adminApi.getActiveRides().then(r => r.data.data as any[]),
    refetchInterval: 15_000,
  })

  useEffect(() => {
    const token = localStorage.getItem('admin_token')
    const wsProto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    const client = new Client({
      brokerURL: `${wsProto}//${window.location.host}/api/v1/ws`,
      connectHeaders: { Authorization: `Bearer ${token}` },
      onConnect: () => {
        client.subscribe('/topic/admin/live-rides', (msg) => {
          try {
            const payload = JSON.parse(msg.body)
            if (payload.eventType === 'DRIVER_LOCATION') {
              const loc: DriverLocation = payload.data
              setDriverLocations(prev => new Map(prev).set(loc.driverId, loc))
            }
          } catch (_) {}
        })
      },
      reconnectDelay: 5000,
    })
    client.activate()
    stompRef.current = client
    return () => { client.deactivate() }
  }, [])

  return (
    <div className="p-6 space-y-5 h-full">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Live Map</h1>
          <p className="text-gray-500 text-sm">
            {activeRides?.length ?? 0} active rides • {driverLocations.size} drivers tracked
          </p>
        </div>
      </div>

      <div className="card p-0 overflow-hidden" style={{ height: 'calc(100vh - 160px)' }}>
        <MapContainer
          center={[8.9806, 38.7578]}
          zoom={12}
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          />

          {/* Active ride markers */}
          {activeRides?.map((ride: any) => (
            <Marker key={`pickup-${ride.id}`}
              position={[ride.pickupLatitude, ride.pickupLongitude]}>
              <Popup>
                <div className="text-sm">
                  <div className="font-semibold">Ride #{ride.id}</div>
                  <div className="text-gray-500">{ride.status?.replace(/_/g, ' ')}</div>
                  <div>From: {ride.pickupAddress}</div>
                  <div>To:   {ride.destinationAddress}</div>
                </div>
              </Popup>
            </Marker>
          ))}

          {/* Live driver locations */}
          {Array.from(driverLocations.values()).map(loc => (
            <Marker key={`driver-${loc.driverId}`}
              position={[loc.latitude, loc.longitude]}
              icon={driverIcon}>
              <Popup>
                <div className="text-sm">
                  <div className="font-semibold">Driver #{loc.driverId}</div>
                  <div>Speed: {loc.speed?.toFixed(0)} km/h</div>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
    </div>
  )
}
