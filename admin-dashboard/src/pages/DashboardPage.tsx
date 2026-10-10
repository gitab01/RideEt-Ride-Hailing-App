import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { adminApi } from '../api/client'
import {
  Users, Car, Banknote, TrendingUp, Activity, Clock
} from 'lucide-react'
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, BarChart, Bar
} from 'recharts'

const dayKey = (value: string | number | Date) => {
  const d = new Date(value)
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`
}

export default function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['dashboard'],
    queryFn: () => adminApi.getDashboard().then(r => r.data.data),
    refetchInterval: 30_000,
  })

  // The weekly charts read the same ride directory the Rides page shows, so a bar is
  // always a number an admin can drill into rather than a made-up trend line.
  const { data: ridePage } = useQuery({
    queryKey: ['rides', 0, 200],
    queryFn: () => adminApi.getRides(0, 200).then(r => r.data.data),
    refetchInterval: 60_000,
  })

  const week = useMemo(() => {
    const days = Array.from({ length: 7 }, (_, i) => {
      const d = new Date()
      d.setHours(0, 0, 0, 0)
      d.setDate(d.getDate() - (6 - i))
      return {
        key: dayKey(d),
        day: d.toLocaleDateString(undefined, { weekday: 'short' }),
        rides: 0,
        revenue: 0,
      }
    })
    const byKey = new Map(days.map(x => [x.key, x]))

    for (const ride of ridePage?.content ?? []) {
      if (ride.requestedAt) {
        const bucket = byKey.get(dayKey(ride.requestedAt))
        if (bucket) bucket.rides += 1
      }
      if (ride.status === 'COMPLETED' && ride.completedAt && ride.actualFare != null) {
        const bucket = byKey.get(dayKey(ride.completedAt))
        if (bucket) bucket.revenue += Number(ride.actualFare)
      }
    }
    return days
  }, [ridePage])

  const stats = [
    { label: 'Total Passengers', value: data?.totalPassengers ?? '-', icon: Users,       color: 'text-blue-600',   bg: 'bg-blue-50'   },
    { label: 'Total Drivers',    value: data?.totalDrivers    ?? '-', icon: Car,         color: 'text-purple-600', bg: 'bg-purple-50' },
    { label: 'Online Drivers',   value: data?.onlineDrivers   ?? '-', icon: Activity,    color: 'text-green-600',  bg: 'bg-green-50'  },
    { label: 'Active Rides',     value: data?.activeRides     ?? '-', icon: Clock,       color: 'text-orange-600', bg: 'bg-orange-50' },
    { label: 'Today Revenue',    value: `${(data?.todayRevenue ?? 0).toFixed(2)} ETB`, icon: Banknote,   color: 'text-emerald-600', bg: 'bg-emerald-50' },
    { label: 'Month Revenue',    value: `${(data?.monthRevenue ?? 0).toFixed(2)} ETB`, icon: TrendingUp, color: 'text-indigo-600',  bg: 'bg-indigo-50'  },
  ]

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500 text-sm mt-1">Real-time platform overview</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        {stats.map(({ label, value, icon: Icon, color, bg }) => (
          <div key={label} className="card">
            <div className={`w-10 h-10 ${bg} rounded-lg flex items-center justify-center mb-3`}>
              <Icon size={20} className={color} />
            </div>
            <div className="text-2xl font-bold text-gray-900">
              {isLoading ? <div className="h-7 w-16 bg-gray-100 animate-pulse rounded" /> : value}
            </div>
            <div className="text-xs text-gray-500 mt-1">{label}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <h2 className="font-semibold text-gray-800 mb-4">Revenue, last 7 days</h2>
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={week}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="day" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v: number) => [`${v.toFixed(2)} ETB`, 'Revenue']} />
              <Line type="monotone" dataKey="revenue" stroke="#1A1A2E" strokeWidth={2} dot={{ r: 4 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="card">
          <h2 className="font-semibold text-gray-800 mb-4">Rides requested, last 7 days</h2>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={week}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="day" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="rides" fill="#FFD700" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
