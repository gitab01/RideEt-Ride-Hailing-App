import { useQuery } from '@tanstack/react-query'
import { adminApi } from '../api/client'
import {
  Users, Car, DollarSign, TrendingUp, Activity, Clock
} from 'lucide-react'
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, BarChart, Bar
} from 'recharts'

const revenueData = [
  { day: 'Mon', revenue: 420 }, { day: 'Tue', revenue: 380 },
  { day: 'Wed', revenue: 510 }, { day: 'Thu', revenue: 620 },
  { day: 'Fri', revenue: 780 }, { day: 'Sat', revenue: 920 },
  { day: 'Sun', revenue: 540 },
]

const ridesData = [
  { day: 'Mon', rides: 45 }, { day: 'Tue', rides: 38 },
  { day: 'Wed', rides: 56 }, { day: 'Thu', rides: 72 },
  { day: 'Fri', rides: 89 }, { day: 'Sat', rides: 104 },
  { day: 'Sun', rides: 61 },
]

export default function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['dashboard'],
    queryFn: () => adminApi.getDashboard().then(r => r.data.data),
    refetchInterval: 30_000,
  })

  const stats = [
    { label: 'Total Passengers', value: data?.totalPassengers ?? '-', icon: Users,       color: 'text-blue-600',   bg: 'bg-blue-50'   },
    { label: 'Total Drivers',    value: data?.totalDrivers    ?? '-', icon: Car,         color: 'text-purple-600', bg: 'bg-purple-50' },
    { label: 'Online Drivers',   value: data?.onlineDrivers   ?? '-', icon: Activity,    color: 'text-green-600',  bg: 'bg-green-50'  },
    { label: 'Active Rides',     value: data?.activeRides     ?? '-', icon: Clock,       color: 'text-orange-600', bg: 'bg-orange-50' },
    { label: 'Today Revenue',    value: `$${(data?.todayRevenue ?? 0).toFixed(2)}`, icon: DollarSign, color: 'text-emerald-600', bg: 'bg-emerald-50' },
    { label: 'Month Revenue',    value: `$${(data?.monthRevenue ?? 0).toFixed(2)}`, icon: TrendingUp, color: 'text-indigo-600',  bg: 'bg-indigo-50'  },
  ]

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500 text-sm mt-1">Real-time platform overview</p>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
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

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <h2 className="font-semibold text-gray-800 mb-4">Weekly Revenue</h2>
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={revenueData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="day" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v: number) => [`$${v}`, 'Revenue']} />
              <Line type="monotone" dataKey="revenue" stroke="#1A1A2E" strokeWidth={2} dot={{ r: 4 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="card">
          <h2 className="font-semibold text-gray-800 mb-4">Weekly Rides</h2>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={ridesData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="day" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip />
              <Bar dataKey="rides" fill="#FFD700" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
