import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { adminApi } from '../api/client'
import { CheckCircle, Ban, ChevronLeft, ChevronRight, Search } from 'lucide-react'
import toast from 'react-hot-toast'
import clsx from 'clsx'

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    ONLINE: 'badge-online', OFFLINE: 'badge-offline',
    ON_TRIP: 'badge-on-trip', SUSPENDED: 'badge-suspended',
  }
  return <span className={map[status] ?? 'badge-offline'}>{status}</span>
}

export default function DriversPage() {
  const [page,   setPage]   = useState(0)
  const [search, setSearch] = useState('')
  const qc = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['drivers', page],
    queryFn: () => adminApi.getDrivers(page).then(r => r.data.data),
  })

  const verifyMutation = useMutation({
    mutationFn: (id: number) => adminApi.verifyDriver(id),
    onSuccess: () => { toast.success('Driver verified'); qc.invalidateQueries({ queryKey: ['drivers'] }) },
    onError: () => toast.error('Failed to verify'),
  })

  const suspendMutation = useMutation({
    mutationFn: (id: number) => adminApi.suspendDriver(id),
    onSuccess: () => { toast.success('Driver status updated'); qc.invalidateQueries({ queryKey: ['drivers'] }) },
    onError: () => toast.error('Failed to update status'),
  })

  const drivers: any[] = data?.content ?? []
  const totalPages: number = data?.totalPages ?? 0

  const filtered = drivers.filter(d =>
    !search || `${d.fullName} ${d.phone} ${d.licensePlate}`.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Drivers</h1>
          <p className="text-gray-500 text-sm">Manage and monitor all drivers</p>
        </div>
      </div>

      <div className="card">
        <div className="flex items-center gap-3 mb-5">
          <div className="relative flex-1 max-w-xs">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search drivers..."
              className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 text-left">
                {['Driver', 'Vehicle', 'License Plate', 'Status', 'Rating', 'Trips', 'Verified', 'Actions'].map(h => (
                  <th key={h} className="pb-3 pr-4 font-semibold text-gray-600">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i}>
                    {Array.from({ length: 8 }).map((_, j) => (
                      <td key={j} className="py-3 pr-4">
                        <div className="h-4 bg-gray-100 rounded animate-pulse w-24" />
                      </td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr><td colSpan={8} className="py-10 text-center text-gray-400">No drivers found</td></tr>
              ) : filtered.map((d: any) => (
                <tr key={d.id} className="hover:bg-gray-50">
                  <td className="py-3 pr-4">
                    <div className="font-medium text-gray-900">{d.fullName}</div>
                    <div className="text-xs text-gray-500">{d.email}</div>
                  </td>
                  <td className="py-3 pr-4">{d.vehicleColor} {d.vehicleMake} {d.vehicleModel}</td>
                  <td className="py-3 pr-4 font-mono">{d.licensePlate}</td>
                  <td className="py-3 pr-4"><StatusBadge status={d.status} /></td>
                  <td className="py-3 pr-4">⭐ {d.rating?.toFixed(1)}</td>
                  <td className="py-3 pr-4">{d.totalRides}</td>
                  <td className="py-3 pr-4">
                    <span className={clsx('text-xs font-semibold px-2 py-1 rounded-full',
                      d.documentsVerified ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800')}>
                      {d.documentsVerified ? 'Verified' : 'Pending'}
                    </span>
                  </td>
                  <td className="py-3 pr-4">
                    <div className="flex gap-2">
                      {!d.documentsVerified && (
                        <button
                          onClick={() => verifyMutation.mutate(d.id)}
                          className="flex items-center gap-1 text-xs text-green-700 hover:text-green-900"
                        >
                          <CheckCircle size={14} /> Verify
                        </button>
                      )}
                      <button
                        onClick={() => suspendMutation.mutate(d.id)}
                        className={clsx('flex items-center gap-1 text-xs',
                          d.status === 'SUSPENDED'
                            ? 'text-green-700 hover:text-green-900'
                            : 'text-red-600 hover:text-red-800')}
                      >
                        <Ban size={14} />
                        {d.status === 'SUSPENDED' ? 'Unsuspend' : 'Suspend'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
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
