import { useEffect, useMemo, useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { MapContainer, TileLayer, Marker, Popup, CircleMarker } from 'react-leaflet'
import L from 'leaflet'
import { adminApi } from '../api/client'
import { subscribeAdmin } from '../lib/adminSocket'
import 'leaflet/dist/leaflet.css'
import toast from 'react-hot-toast'
import clsx from 'clsx'
import { X } from 'lucide-react'

const TIERS = ['ECONOMY', 'STANDARD', 'PREMIUM', 'XL']
const STATUSES = ['ONLINE', 'ON_TRIP']

const TIER_COLOR: Record<string, string> = {
  ECONOMY: '#2E7D32', STANDARD: '#1565C0', PREMIUM: '#6A1B9A', XL: '#EF6C00',
}

/** A plain dot beats leaflet's CDN marker: no network dependency, and it can carry the tier colour. */
const dotIcon = (color: string) => L.divIcon({
  className: '',
  html: `<div style="width:14px;height:14px;border-radius:50%;background:${color};
         border:2px solid #fff;box-shadow:0 0 0 1px rgba(0,0,0,.25)"></div>`,
  iconSize: [14, 14],
  iconAnchor: [7, 7],
})

export default function LiveMapPage() {
  const qc = useQueryClient()
  const [tierFilter, setTierFilter] = useState<string | null>(null)
  const [statusFilter, setStatusFilter] = useState<string | null>(null)
  const [dispatchRide, setDispatchRide] = useState<number | null>(null)

  // The fleet comes from the matching engine's own live index. Polling it means a driver who
  // pinged before this page was opened is still on the map, which a socket subscription alone
  // could never do.
  const { data: fleet } = useQuery({
    queryKey: ['driver-locations'],
    queryFn: () => adminApi.getDriverLocations().then(r => r.data.data as any[]),
    refetchInterval: 5_000,
  })

  const { data: activeRides } = useQuery({
    queryKey: ['active-rides'],
    queryFn: () => adminApi.getActiveRides().then(r => r.data.data as any[]),
    refetchInterval: 10_000,
  })

  const { data: driverDirectory } = useQuery({
    queryKey: ['drivers', 0],
    queryFn: () => adminApi.getDrivers(0).then(r => r.data.data.content as any[]),
  })

  const { data: candidates } = useQuery({
    queryKey: ['dispatch-candidates', dispatchRide],
    queryFn: () => adminApi.getDispatchCandidates(dispatchRide!).then(r => r.data.data as any[]),
    enabled: dispatchRide != null,
  })

  const names = useMemo(() => {
    const map = new Map<number, string>()
    for (const d of driverDirectory ?? []) map.set(d.id, `${d.fullName} · ${d.licensePlate}`)
    return map
  }, [driverDirectory])

  // Live position updates for rides already in progress, on top of the polled snapshot.
  useEffect(() => subscribeAdmin('/topic/admin/live-rides', (frame) => {
    try {
      const payload = JSON.parse(frame)
      if (payload.eventType === 'DRIVER_LOCATION') {
        qc.invalidateQueries({ queryKey: ['driver-locations'] })
      }
      if (payload.eventType === 'RIDE_REQUESTED' || payload.eventType === 'RIDE_ASSIGNED') {
        qc.invalidateQueries({ queryKey: ['active-rides'] })
      }
    } catch (_) { /* a frame we cannot read is not worth breaking the page over */ }
  }), [qc])

  const drivers = (fleet ?? []).filter(d =>
    (!tierFilter || d.vehicleType === tierFilter) &&
    (!statusFilter || d.status === statusFilter))

  const unassigned = (activeRides ?? []).filter(r => r.status === 'SEARCHING')

  const assignMutation = useMutation({
    mutationFn: ({ rideId, driverId }: { rideId: number; driverId: number }) =>
      adminApi.assignDriver(rideId, driverId),
    onSuccess: () => {
      toast.success('Driver dispatched')
      setDispatchRide(null)
      qc.invalidateQueries({ queryKey: ['active-rides'] })
      qc.invalidateQueries({ queryKey: ['driver-locations'] })
    },
    onError: (err: any) => toast.error(err.response?.data?.message ?? 'Dispatch failed'),
  })

  const cancelMutation = useMutation({
    mutationFn: (rideId: number) => adminApi.cancelRide(rideId, 'Cancelled from the dispatch console'),
    onSuccess: () => {
      toast.success('Ride cancelled')
      setDispatchRide(null)
      qc.invalidateQueries({ queryKey: ['active-rides'] })
    },
    onError: (err: any) => toast.error(err.response?.data?.message ?? 'Could not cancel'),
  })

  return (
    <div className="p-4 sm:p-6 space-y-4 h-full">
      <div className="flex flex-wrap items-end gap-3 justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Live Map</h1>
          <p className="text-gray-500 text-sm">
            {fleet?.length ?? 0} in the index · {drivers.length} shown · {unassigned.length} waiting for a driver
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          {TIERS.map(t => (
            <button key={t} onClick={() => setTierFilter(f => f === t ? null : t)}
              className={clsx('chip', tierFilter === t && 'chip-active')}>
              {t}
            </button>
          ))}
          {STATUSES.map(s => (
            <button key={s} onClick={() => setStatusFilter(f => f === s ? null : s)}
              className={clsx('chip', statusFilter === s && 'chip-active')}>
              {s === 'ONLINE' ? 'Available' : 'On trip'}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4" style={{ minHeight: 'calc(100vh - 210px)' }}>
        <div className="lg:col-span-2 card p-0 overflow-hidden min-h-[380px]">
          <MapContainer
            center={[8.9806, 38.7578]}
            zoom={12}
            style={{ height: '100%', width: '100%' }}
          >
            <TileLayer
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            />

            {unassigned.map((ride: any) => (
              <CircleMarker key={`req-${ride.id}`} center={[ride.pickupLatitude, ride.pickupLongitude]}
                            radius={10} pathOptions={{ color: '#D32F2F', weight: 2, fillOpacity: 0 }}>
                <Popup>Unassigned request #{ride.id} — {ride.pickupAddress}</Popup>
              </CircleMarker>
            ))}

            {drivers.map((d: any) => (
              <Marker key={`driver-${d.driverId}`} position={[d.latitude, d.longitude]}
                      icon={dotIcon(TIER_COLOR[d.vehicleType] ?? '#1A1A2E')}>
                <Popup>
                  <div className="text-sm space-y-0.5">
                    <div className="font-semibold">{names.get(d.driverId) ?? `Driver #${d.driverId}`}</div>
                    <div>{d.vehicleType} · {d.status ?? 'unknown'}</div>
                    <div className="text-gray-500">pinged {d.secondsAgo}s ago</div>
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </div>

        {/* Unassigned requests + dispatch control */}
        <div className="card">
          <h2 className="section-title mb-3">Unassigned Requests</h2>
          {unassigned.length === 0 ? (
            <p className="text-sm text-gray-500">Nothing is waiting for a driver right now.</p>
          ) : (
            <ul className="space-y-2 max-h-[46vh] overflow-y-auto pr-1">
              {unassigned.map((ride: any) => (
                <li key={ride.id} className="border border-gray-100 rounded-lg p-3">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="text-sm font-semibold text-gray-900">Ride #{ride.id}</div>
                      <div className="text-xs text-gray-500 truncate">{ride.pickupAddress}</div>
                      <div className="text-xs text-gray-500 truncate">→ {ride.destinationAddress}</div>
                      <div className="text-xs text-gray-500 mt-1">
                        {ride.vehicleType} · {Number(ride.estimatedFare ?? 0).toFixed(2)} ETB ·{' '}
                        {ride.distanceKm ?? '?'} km
                      </div>
                    </div>
                    <button
                      onClick={() => setDispatchRide(dispatchRide === ride.id ? null : ride.id)}
                      className="btn-secondary shrink-0"
                    >
                      Dispatch
                    </button>
                  </div>

                  {dispatchRide === ride.id && (
                    <div className="mt-3 pt-3 border-t border-gray-100">
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-xs font-semibold text-gray-700">Dispatch Control</span>
                        <button onClick={() => setDispatchRide(null)} aria-label="Close dispatch"
                          className="p-1 hover:bg-gray-50 rounded"><X size={14} /></button>
                      </div>
                      {!candidates ? (
                        <p className="text-xs text-gray-500">Loading nearby drivers...</p>
                      ) : candidates.length === 0 ? (
                        <p className="text-xs text-gray-500">
                          No online, approved driver is inside the search radius.
                        </p>
                      ) : (
                        <ul className="space-y-1.5">
                          {candidates.map((c: any) => (
                            <li key={c.driverId} className="flex items-center gap-2 text-xs">
                              <span className="w-2 h-2 rounded-full shrink-0"
                                    style={{ background: TIER_COLOR[c.vehicleType] ?? '#1A1A2E' }} />
                              <span className="font-medium text-gray-900 truncate">
                                {c.fullName ?? `Driver #${c.driverId}`}
                              </span>
                              <span className="text-gray-500">
                                {c.distanceToPickupKm.toFixed(2)} km · {c.pickupEtaMinutes} min ·{' '}
                                {Number(c.fareForThisTrip).toFixed(0)} ETB
                                {c.differentTier && <span className="text-orange-600"> · other tier</span>}
                              </span>
                              <button
                                className="ml-auto px-2 py-1 rounded bg-primary text-white text-xs font-semibold
                                           disabled:opacity-50"
                                disabled={assignMutation.isPending}
                                onClick={() => assignMutation.mutate({ rideId: ride.id, driverId: c.driverId })}
                              >
                                Send
                              </button>
                            </li>
                          ))}
                        </ul>
                      )}
                      <button
                        className="btn-danger mt-3 w-full text-xs disabled:opacity-50"
                        disabled={cancelMutation.isPending}
                        onClick={() => cancelMutation.mutate(ride.id)}
                      >
                        Cancel ride
                      </button>
                      <p className="text-[11px] text-gray-400 mt-2">
                        Sending a driver from another tier re-prices the ride for the car that is
                        actually coming, and the rider is told.
                      </p>
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}
