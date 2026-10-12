import { useQuery } from '@tanstack/react-query'
import { adminApi } from '../api/client'
import {
  Users, Car, Banknote, TrendingUp, Activity, Clock
} from 'lucide-react'
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, BarChart, Bar
} from 'recharts'

/** Grid resolution for the density panel. Coarse on purpose: it reads as a heat map, not a scatter. */
const HEAT_COLS = 14
const HEAT_ROWS = 9

/** Addis Ababa operating area, used when there are too few drivers to bound a grid ourselves. */
const DEFAULT_BOX = { minLat: 8.85, maxLat: 9.10, minLng: 38.65, maxLng: 38.92 }

function densityCells(locations: any[]) {
  if (locations.length === 0) return null
  const lats = locations.map(l => l.latitude)
  const lngs = locations.map(l => l.longitude)
  const box = locations.length < 4 ? DEFAULT_BOX : {
    minLat: Math.min(...lats), maxLat: Math.max(...lats),
    minLng: Math.min(...lngs), maxLng: Math.max(...lngs),
  }
  // A single-point box would divide by zero; pad so the maths stays finite.
  const latSpan = Math.max(box.maxLat - box.minLat, 0.01)
  const lngSpan = Math.max(box.maxLng - box.minLng, 0.01)

  const counts = new Array(HEAT_COLS * HEAT_ROWS).fill(0)
  for (const loc of locations) {
    const x = Math.min(HEAT_COLS - 1, Math.max(0,
      Math.floor(((loc.longitude - box.minLng) / lngSpan) * HEAT_COLS)))
    const y = Math.min(HEAT_ROWS - 1, Math.max(0,
      Math.floor(((box.maxLat - loc.latitude) / latSpan) * HEAT_ROWS)))
    counts[y * HEAT_COLS + x] += 1
  }
  return { counts, max: Math.max(...counts) }
}

export default function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['dashboard'],
    queryFn: () => adminApi.getDashboard().then(r => r.data.data),
    refetchInterval: 30_000,
  })

  // The charts come from the server's own day-by-day aggregate, so they cover the whole
  // window instead of only the rides that fit on one page of the rides list.
  const { data: daily } = useQuery({
    queryKey: ['daily-stats', 7],
    queryFn: () => adminApi.getDailyStats(7).then(r => r.data.data),
    refetchInterval: 60_000,
  })

  const { data: drivers } = useQuery({
    queryKey: ['driver-locations'],
    queryFn: () => adminApi.getDriverLocations().then(r => r.data.data as any[]),
    refetchInterval: 10_000,
  })

  const series = (daily?.days ?? []).map((d: any) => ({
    day: new Date(d.date).toLocaleDateString(undefined, { weekday: 'short' }),
    rides: d.rides,
    revenue: d.revenue,
  }))

  const heat = densityCells(drivers ?? [])

  const stats = [
    { label: 'Active Drivers',   value: data?.onlineDrivers   ?? '-', icon: Activity,    color: 'text-green-600',  bg: 'bg-green-50'  },
    { label: 'Riders On Trips',  value: data?.activeRides     ?? '-', icon: Clock,       color: 'text-orange-600', bg: 'bg-orange-50' },
    { label: "Today's Revenue",  value: `${(data?.todayRevenue ?? 0).toFixed(2)} ETB`, icon: Banknote,   color: 'text-emerald-600', bg: 'bg-emerald-50' },
    { label: 'Total Passengers', value: data?.totalPassengers ?? '-', icon: Users,       color: 'text-blue-600',   bg: 'bg-blue-50'   },
    { label: 'Total Drivers',    value: data?.totalDrivers    ?? '-', icon: Car,         color: 'text-purple-600', bg: 'bg-purple-50' },
    { label: 'Month Revenue',    value: `${(data?.monthRevenue ?? 0).toFixed(2)} ETB`, icon: TrendingUp, color: 'text-indigo-600', bg: 'bg-indigo-50' },
  ]

  return (
    <div className="p-4 sm:p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500 text-sm mt-1">
          Live fleet: {data?.trackedDrivers ?? 0} drivers placed, {data?.searchesInProgress ?? 0} searches running
        </p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        {stats.map(({ label, value, icon: Icon, color, bg }) => (
          <div key={label} className="card">
            <div className={`w-10 h-10 ${bg} rounded-lg flex items-center justify-center mb-3`}>
              <Icon size={20} className={color} />
            </div>
            <div className="text-xl sm:text-2xl font-bold text-gray-900">
              {isLoading ? <div className="h-7 w-16 bg-gray-100 animate-pulse rounded" /> : value}
            </div>
            <div className="text-xs text-gray-500 mt-1">{label}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <h2 className="section-title mb-4">Weekly Ride Volume</h2>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={series}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="day" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} allowDecimals={false} />
              <Tooltip />
              <Area type="monotone" dataKey="rides" stroke="#1A1A2E" strokeWidth={2}
                    fill="#FFD700" fillOpacity={0.35} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="card">
          <h2 className="section-title mb-4">Daily Takings (ETB)</h2>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={series}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="day" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v: number) => [`${v.toFixed(2)} ETB`, 'Takings']} />
              <Bar dataKey="revenue" fill="#1A1A2E" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="card">
        <div className="flex items-baseline justify-between mb-4">
          <h2 className="section-title">Live Heat Map</h2>
          <span className="text-xs text-gray-500">
            {drivers?.length ?? 0} placed drivers, refreshed every 10s
          </span>
        </div>

        {heat ? (
          <div
            className="grid gap-1"
            style={{ gridTemplateColumns: `repeat(${HEAT_COLS}, minmax(0, 1fr))` }}
            aria-label="Driver density grid"
          >
            {heat.counts.map((count: number, i: number) => (
              <div
                key={i}
                title={count > 0 ? `${count} driver${count > 1 ? 's' : ''} in this cell` : undefined}
                className="aspect-square rounded-sm"
                style={{
                  background: count === 0 ? '#f5f5f5' : `rgba(26, 26, 46, ${0.25 + 0.75 * (count / heat.max)})`,
                }}
              />
            ))}
          </div>
        ) : (
          <p className="text-sm text-gray-500">
            No driver is online right now, so there is nothing to place on the map.
          </p>
        )}
        <p className="text-xs text-gray-400 mt-3">
          Cells are a grid over the bounding box of current driver positions — darker means more
          cars in that area, not more rides.
        </p>
      </div>
    </div>
  )
}
