import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { adminApi } from '../api/client'
import { CheckCircle, Ban, ChevronLeft, ChevronRight, Search, ShieldCheck, X } from 'lucide-react'
import toast from 'react-hot-toast'
import clsx from 'clsx'

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    ONLINE: 'badge-online', OFFLINE: 'badge-offline',
    ON_TRIP: 'badge-on-trip', SUSPENDED: 'badge-suspended',
  }
  return <span className={map[status] ?? 'badge-offline'}>{status}</span>
}

function DocumentLink({ label, url }: { label: string; url?: string }) {
  return (
    <div className="border border-gray-100 rounded-lg p-3">
      <div className="text-xs font-semibold text-gray-600 mb-1">{label}</div>
      {url ? (
        <a href={url} target="_blank" rel="noreferrer" className="text-sm text-blue-700 underline break-all">
          Open upload
        </a>
      ) : (
        <p className="text-sm text-gray-400">Nothing uploaded</p>
      )}
    </div>
  )
}

/**
 * The whole decision fits on one panel: the paperwork, what was concluded last time, and the two
 * outcomes. There is no approval history feed because the database keeps only the current verdict
 * and its note — showing an invented timeline would be a lie about records we do not have.
 */
function VerificationModal({ driver, onClose }: { driver: any; onClose: () => void }) {
  const qc = useQueryClient()
  const [reason, setReason] = useState('')

  const afterWrite = (message: string) => {
    toast.success(message)
    qc.invalidateQueries({ queryKey: ['drivers'] })
    onClose()
  }

  const approve = useMutation({
    mutationFn: () => adminApi.verifyDriver(driver.id),
    onSuccess: () => afterWrite(`${driver.fullName} approved`),
    onError: () => toast.error('Could not approve'),
  })

  const reject = useMutation({
    mutationFn: () => adminApi.rejectDriver(driver.id, reason.trim()),
    onSuccess: () => afterWrite(`${driver.fullName} rejected`),
    onError: (err: any) => toast.error(err.response?.data?.message ?? 'Could not reject'),
  })

  const accepted = driver.offersAccepted ?? 0
  const declined = driver.offersDeclined ?? 0
  const answered = accepted + declined

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-end sm:items-center justify-center p-0 sm:p-4"
         onClick={onClose}>
      <div className="bg-white w-full max-w-2xl rounded-t-2xl sm:rounded-2xl p-5 sm:p-6 max-h-[90vh] overflow-y-auto"
           onClick={e => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3 mb-4">
          <div>
            <h2 className="text-lg font-bold text-gray-900">Driver Verification</h2>
            <p className="text-sm text-gray-500">
              #{driver.id} · {driver.fullName} · {driver.phone}
            </p>
          </div>
          <button onClick={onClose} aria-label="Close" className="p-1.5 hover:bg-gray-50 rounded">
            <X size={18} />
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-4">
          <DocumentLink label="Driver licence" url={driver.driverLicenseUrl} />
          <DocumentLink label="Vehicle registration" url={driver.vehicleRegistrationUrl} />
          <DocumentLink label="Insurance" url={driver.insuranceUrl} />
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-4 text-sm">
          <div>
            <div className="text-xs text-gray-500">Vehicle</div>
            <div className="font-medium text-gray-900">{driver.vehicleMake} {driver.vehicleModel}</div>
          </div>
          <div>
            <div className="text-xs text-gray-500">Plate</div>
            <div className="font-mono font-medium text-gray-900">{driver.licensePlate}</div>
          </div>
          <div>
            <div className="text-xs text-gray-500">Tier</div>
            <div className="font-medium text-gray-900">{driver.vehicleType}</div>
          </div>
          <div>
            <div className="text-xs text-gray-500">Answers offers</div>
            <div className="font-medium text-gray-900">
              {answered === 0 ? 'no data yet' : `${Math.round((accepted / answered) * 100)}% (${accepted}/${answered})`}
            </div>
          </div>
        </div>

        <div className="rounded-lg bg-gray-50 p-3 mb-4 text-sm">
          <div className="flex items-center gap-2 mb-1">
            <ShieldCheck size={16} className="text-gray-600" />
            <span className="font-semibold text-gray-800">Current verdict</span>
          </div>
          <p className="text-gray-600">
            {driver.documentsVerified
              ? 'Approved — this driver is being offered rides.'
              : 'Not approved — the matching engine will not hand this driver a ride.'}
            {driver.verificationNote && ` Last note: ${driver.verificationNote}`}
          </p>
          <p className="text-xs text-gray-400 mt-1">
            Registered {new Date(driver.createdAt).toLocaleDateString()}
          </p>
        </div>

        <div className="space-y-3">
          <input
            className="input" value={reason}
            onChange={e => setReason(e.target.value)}
            placeholder="Reason for rejection (shown to the driver)"
            maxLength={300}
          />
          <div className="flex flex-col sm:flex-row gap-2">
            <button
              className="flex-1 bg-success text-white rounded-lg py-2.5 text-sm font-semibold
                         hover:opacity-90 disabled:opacity-50 flex items-center justify-center gap-2"
              disabled={approve.isPending}
              onClick={() => approve.mutate()}
            >
              <CheckCircle size={16} /> Approve documents
            </button>
            <button
              className="flex-1 btn-danger rounded-lg py-2.5 text-sm font-semibold
                         disabled:opacity-50 flex items-center justify-center gap-2"
              disabled={reject.isPending || reason.trim().length < 3}
              onClick={() => reject.mutate()}
            >
              <Ban size={16} /> {reject.isPending ? 'Rejecting...' : 'Reject'}
            </button>
          </div>
          {reason.trim().length < 3 && (
            <p className="text-xs text-gray-400">Rejection needs a reason of at least three characters.</p>
          )}
        </div>
      </div>
    </div>
  )
}

export default function DriversPage() {
  const [page,   setPage]   = useState(0)
  const [search, setSearch] = useState('')
  const [review, setReview] = useState<any | null>(null)
  const qc = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['drivers', page],
    queryFn: () => adminApi.getDrivers(page).then(r => r.data.data),
  })

  const suspendMutation = useMutation({
    mutationFn: (id: number) => adminApi.suspendDriver(id),
    onSuccess: () => { toast.success('Driver status updated'); qc.invalidateQueries({ queryKey: ['drivers'] }) },
    onError: () => toast.error('Failed to update status'),
  })

  const drivers: any[] = data?.content ?? []
  const totalPages: number = data?.totalPages ?? 0

  const filtered = drivers.filter(d =>
    !search || `${d.fullName} ${d.phone} ${d.licensePlate}`.toLowerCase().includes(search.toLowerCase()))

  return (
    <div className="p-4 sm:p-6 space-y-5">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Drivers</h1>
        <p className="text-gray-500 text-sm">Approve paperwork, suspend accounts, review live activity</p>
      </div>

      <div className="card">
        <div className="flex items-center gap-3 mb-5">
          <div className="relative flex-1 max-w-xs">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search drivers..."
              className="pl-9 pr-3 py-2 w-full border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 text-left">
                {['ID', 'Driver', 'Vehicle Type', 'Plate Number', 'Rating', 'Trips', 'Status', 'Documents', ''].map(h => (
                  <th key={h} className="pb-3 pr-4 font-semibold text-gray-600 whitespace-nowrap">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i}>
                    {Array.from({ length: 9 }).map((_, j) => (
                      <td key={j} className="py-3 pr-4">
                        <div className="h-4 bg-gray-100 rounded animate-pulse w-24" />
                      </td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr><td colSpan={9} className="py-10 text-center text-gray-400">No drivers found</td></tr>
              ) : filtered.map((d: any) => (
                <tr key={d.id} className="hover:bg-gray-50">
                  <td className="py-3 pr-4 text-gray-500 tabular-nums">#{d.id}</td>
                  <td className="py-3 pr-4">
                    <div className="font-medium text-gray-900">{d.fullName}</div>
                    <div className="text-xs text-gray-500">{d.phone}</div>
                  </td>
                  <td className="py-3 pr-4 whitespace-nowrap">{d.vehicleType}</td>
                  <td className="py-3 pr-4 font-mono">{d.licensePlate}</td>
                  <td className="py-3 pr-4 tabular-nums">{d.rating?.toFixed(1)} ★</td>
                  <td className="py-3 pr-4 tabular-nums">{d.totalRides}</td>
                  <td className="py-3 pr-4"><StatusBadge status={d.status} /></td>
                  <td className="py-3 pr-4">
                    <span className={clsx('text-xs font-semibold px-2 py-1 rounded-full whitespace-nowrap',
                      d.documentsVerified ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800')}>
                      {d.documentsVerified ? 'Approved' : d.verificationNote ? 'Rejected' : 'Pending'}
                    </span>
                  </td>
                  <td className="py-3 pr-4">
                    <div className="flex gap-2 whitespace-nowrap">
                      <button onClick={() => setReview(d)} className="text-xs font-semibold text-primary hover:underline">
                        Review
                      </button>
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

      {review && <VerificationModal driver={review} onClose={() => setReview(null)} />}
    </div>
  )
}
