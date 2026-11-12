import { Fragment, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { adminApi } from '../api/client'
import { ChevronLeft, ChevronRight, Search } from 'lucide-react'

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    COMPLETED: 'badge-completed', CANCELLED: 'badge-cancelled',
    IN_PROGRESS: 'badge-in-progress', SEARCHING: 'badge-searching',
    DRIVER_ASSIGNED: 'badge-in-progress', DRIVER_ARRIVED: 'badge-in-progress',
  }
  return <span className={map[status] ?? 'badge-offline'}>{status?.replace(/_/g,' ')}</span>
}

export default function RidesPage() {
  const [page,   setPage]   = useState(0)
  const [search, setSearch] = useState('')
  const [expanded, setExpanded] = useState<number | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['rides', page],
    queryFn: () => adminApi.getRides(page).then(r => r.data.data),
    refetchInterval: 15_000,
  })

  const rides: any[] = data?.content ?? []
  const totalPages: number = data?.totalPages ?? 0
  const filtered = rides.filter(r =>
    !search || `${r.passengerName} ${r.driverName ?? ''} ${r.pickupAddress} ${r.destinationAddress}`
      .toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Rides</h1>
        <p className="text-gray-500 text-sm">Monitor all ride activity</p>
      </div>

      <div className="card">
        <div className="flex items-center gap-3 mb-5">
          <div className="relative flex-1 max-w-xs">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search rides..."
              className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 text-left">
                {['ID', 'Passenger', 'Driver', 'From → To', 'Status', 'Fare', 'Date'].map(h => (
                  <th key={h} className="pb-3 pr-4 font-semibold text-gray-600">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i}>{Array.from({ length: 7 }).map((_, j) => (
                    <td key={j} className="py-3 pr-4">
                      <div className="h-4 bg-gray-100 rounded animate-pulse w-24" />
                    </td>
                  ))}</tr>
                ))
              ) : filtered.length === 0 ? (
                <tr><td colSpan={7} className="py-10 text-center text-gray-400">No rides found</td></tr>
              ) : filtered.map((r: any) => (
                <Fragment key={r.id}>
                  <tr className="hover:bg-gray-50">
                    <td className="py-3 pr-4">
                      <button
                        onClick={() => setExpanded(expanded === r.id ? null : r.id)}
                        className="font-mono text-gray-500 hover:text-gray-900 underline decoration-dotted"
                      >
                        #{r.id}
                      </button>
                    </td>
                    <td className="py-3 pr-4 font-medium">{r.passengerName}</td>
                    <td className="py-3 pr-4">{r.driverName ?? '—'}</td>
                    <td className="py-3 pr-4 max-w-xs">
                      <div className="truncate text-xs text-gray-500">{r.pickupAddress}</div>
                      <div className="truncate text-xs">{r.destinationAddress}</div>
                    </td>
                    <td className="py-3 pr-4"><StatusBadge status={r.status} /></td>
                    <td className="py-3 pr-4 font-medium">
                      {r.actualFare != null ? `${r.actualFare.toFixed(2)} ETB`
                        : r.status === 'CANCELLED' || r.status === 'NO_DRIVER_FOUND' ? '—'
                        : <span className="text-gray-500">{(r.estimatedFare ?? 0).toFixed(2)} ETB est.</span>}
                    </td>
                    <td className="py-3 pr-4 text-gray-500 text-xs">
                      {r.requestedAt ? new Date(r.requestedAt).toLocaleDateString() : '-'}
                    </td>
                  </tr>
                  {expanded === r.id && (
                    <tr className="bg-gray-50">
                      <td colSpan={7} className="px-4 py-4">
                        <Timeline rideId={r.id} ride={r} />
                      </td>
                    </tr>
                  )}
                </Fragment>
              ))}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="flex items-center justify-between mt-4 pt-4 border-t border-gray-100">
            <span className="text-sm text-gray-500">Page {page + 1} of {totalPages}</span>
            <div className="flex gap-2">
              <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0}
                className="p-1.5 rounded border border-gray-200 hover:bg-gray-50 disabled:opacity-40">
                <ChevronLeft size={16} />
              </button>
              <button onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))} disabled={page >= totalPages - 1}
                className="p-1.5 rounded border border-gray-200 hover:bg-gray-50 disabled:opacity-40">
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

/** The append-only state trail plus the ride facts that do not fit a table column. */
function Timeline({ rideId, ride }: { rideId: number; ride: any }) {
  const { data: events, isLoading } = useQuery({
    queryKey: ['ride-events', rideId],
    queryFn: () => adminApi.getRideEvents(rideId).then(r => r.data.data as any[]),
  })

  const facts: { label: string; value: string }[] = [
    { label: 'Distance',  value: ride.distanceKm != null ? `${Number(ride.distanceKm).toFixed(2)} km` : '—' },
    { label: 'Duration',  value: ride.durationMinutes != null ? `${ride.durationMinutes} min` : '—' },
    { label: 'Payment',   value: ride.paymentMethod ?? '—' },
    { label: 'Surge',     value: ride.surgeMultiplier ? `${ride.surgeMultiplier}x` : '1x' },
    { label: 'Rated by passenger', value: ride.ratingByPassenger ? `${ride.ratingByPassenger}★` : 'Not rated' },
    { label: 'Rated by driver',    value: ride.ratingByDriver ? `${ride.ratingByDriver}★` : 'Not rated' },
  ]
  if (ride.cancelledAt) {
    facts.push({
      label: 'Cancelled',
      value: `${ride.cancelledBy ?? 'unknown'}${ride.cancellationReason ? ` · ${ride.cancellationReason}` : ''}`,
    })
  }

  return (
    <div className="grid gap-5 lg:grid-cols-2">
      <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
        {facts.map(f => (
          <div key={f.label}>
            <dt className="text-xs uppercase tracking-wide text-gray-500">{f.label}</dt>
            <dd className="text-sm font-medium text-gray-900">{f.value}</dd>
          </div>
        ))}
      </dl>

      <ol className="space-y-1.5 border-l border-gray-200 pl-4">
        {isLoading ? (
          <li className="text-sm text-gray-400">Loading trail...</li>
        ) : events?.length === 0 ? (
          <li className="text-sm text-gray-400">No state changes recorded</li>
        ) : (
          events?.map((e: any, i: number) => (
            <li key={i} className="text-sm">
              <span className="font-medium">{e.from ?? 'NEW'}</span>
              <span className="text-gray-400"> → </span>
              <span className="font-medium">{e.to}</span>
              <span className="ml-2 text-xs text-gray-500">
                {e.actor}{e.at ? ` · ${new Date(e.at).toLocaleTimeString()}` : ''}
              </span>
              {e.note && <div className="text-xs text-gray-500">{e.note}</div>}
            </li>
          ))
        )}
      </ol>
    </div>
  )
}
