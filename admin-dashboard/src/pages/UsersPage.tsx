import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { adminApi } from '../api/client'
import { UserX, UserCheck, Search, ChevronLeft, ChevronRight } from 'lucide-react'
import toast from 'react-hot-toast'

export default function UsersPage() {
  const [page,   setPage]   = useState(0)
  const [search, setSearch] = useState('')
  const qc = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['users', page],
    queryFn: () => adminApi.getUsers(page).then(r => r.data.data),
  })

  const toggleMutation = useMutation({
    mutationFn: (id: number) => adminApi.toggleUser(id),
    onSuccess: () => { toast.success('User status updated'); qc.invalidateQueries({ queryKey: ['users'] }) },
    onError: () => toast.error('Failed'),
  })

  const users: any[] = data?.content ?? []
  const totalPages: number = data?.totalPages ?? 0
  const filtered = users.filter(u =>
    !search || `${u.firstName} ${u.lastName} ${u.email}`.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Users</h1>
        <p className="text-gray-500 text-sm">Manage passenger accounts</p>
      </div>

      <div className="card">
        <div className="flex items-center gap-3 mb-5">
          <div className="relative flex-1 max-w-xs">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search users..."
              className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 text-left">
                {['Name', 'Email', 'Phone', 'Wallet', 'Status', 'Joined', 'Actions'].map(h => (
                  <th key={h} className="pb-3 pr-4 font-semibold text-gray-600">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i}>{Array.from({ length: 7 }).map((_, j) => (
                    <td key={j} className="py-3 pr-4">
                      <div className="h-4 bg-gray-100 rounded animate-pulse w-24" />
                    </td>
                  ))}</tr>
                ))
              ) : filtered.length === 0 ? (
                <tr><td colSpan={7} className="py-10 text-center text-gray-400">No users found</td></tr>
              ) : filtered.map((u: any) => (
                <tr key={u.id} className="hover:bg-gray-50">
                  <td className="py-3 pr-4 font-medium">{u.firstName} {u.lastName}</td>
                  <td className="py-3 pr-4 text-gray-600">{u.email}</td>
                  <td className="py-3 pr-4">{u.phone}</td>
                  <td className="py-3 pr-4">${(u.walletBalance ?? 0).toFixed(2)}</td>
                  <td className="py-3 pr-4">
                    <span className={u.enabled
                      ? 'badge-online' : 'badge-suspended'}>
                      {u.enabled ? 'Active' : 'Disabled'}
                    </span>
                  </td>
                  <td className="py-3 pr-4 text-gray-500 text-xs">
                    {u.createdAt ? new Date(u.createdAt).toLocaleDateString() : '-'}
                  </td>
                  <td className="py-3 pr-4">
                    <button
                      onClick={() => toggleMutation.mutate(u.id)}
                      className={`flex items-center gap-1 text-xs ${u.enabled ? 'text-red-600 hover:text-red-800' : 'text-green-700 hover:text-green-900'}`}
                    >
                      {u.enabled ? <><UserX size={14} /> Disable</> : <><UserCheck size={14} /> Enable</>}
                    </button>
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
    </div>
  )
}
