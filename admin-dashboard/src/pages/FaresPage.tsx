import { useMemo, useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { adminApi } from '../api/client'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import toast from 'react-hot-toast'
import clsx from 'clsx'

/** Surge values the curve is drawn against, matching the levels an operator actually applies. */
const SURGE_LEVELS = [1.0, 1.2, 1.8, 2.5]

/** A typical Addis cross-town run, used for the "what changes if I move this" preview. */
const SAMPLE = { distanceKm: 10, durationMinutes: 20 }

const fareAt = (tier: any, distanceKm: number, durationMinutes: number, surge: number) => {
  const trip = (Number(tier.baseFare) + distanceKm * Number(tier.perKmRate)
    + durationMinutes * Number(tier.perMinuteRate)) * surge
  return Math.round(Math.max(trip + Number(tier.bookingFee), Number(tier.minimumFare)) * 100) / 100
}

type Draft = {
  displayName: string
  baseFare: number
  perKmRate: number
  perMinuteRate: number
  bookingFee: number
  minimumFare: number
  surgeMultiplier: number
  active: boolean
}

const draftOf = (tier: any): Draft => ({
  displayName: tier.displayName,
  baseFare: Number(tier.baseFare),
  perKmRate: Number(tier.perKmRate),
  perMinuteRate: Number(tier.perMinuteRate),
  bookingFee: Number(tier.bookingFee),
  minimumFare: Number(tier.minimumFare),
  surgeMultiplier: Number(tier.surgeMultiplier),
  active: Boolean(tier.active),
})

function Slider({ label, hint, value, min, max, step, onChange }: {
  label: string; hint: string; value: number
  min: number; max: number; step: number; onChange: (v: number) => void
}) {
  return (
    <div>
      <div className="flex items-baseline justify-between mb-1">
        <label className="text-sm font-medium text-gray-700">{label}</label>
        <span className="text-sm font-semibold text-gray-900 tabular-nums">{value.toFixed(2)}</span>
      </div>
      <input
        type="range" min={min} max={max} step={step} value={value}
        onChange={e => onChange(Number(e.target.value))}
        className="w-full accent-[#1A1A2E]"
      />
      <p className="text-xs text-gray-400 mt-1">{hint}</p>
    </div>
  )
}

export default function FaresPage() {
  const qc = useQueryClient()
  const [selected, setSelected] = useState<string | null>(null)
  const [draft, setDraft] = useState<Draft | null>(null)

  const { data: tiers, isLoading } = useQuery({
    queryKey: ['pricing'],
    queryFn: () => adminApi.getPricing().then(r => r.data.data as any[]),
  })

  const active = useMemo(() => {
    if (!tiers?.length) return null
    const key = selected ?? tiers[0].vehicleType
    return tiers.find(t => t.vehicleType === key) ?? tiers[0]
  }, [tiers, selected])

  const chooseTier = (tier: any) => {
    setSelected(tier.vehicleType)
    setDraft(draftOf(tier))
  }

  const saveMutation = useMutation({
    mutationFn: ({ vehicleType, body }: { vehicleType: string; body: Draft }) =>
      adminApi.updatePricing(vehicleType, body),
    onSuccess: () => {
      toast.success('Pricing saved — new quotes use it immediately')
      setDraft(null)
      qc.invalidateQueries({ queryKey: ['pricing'] })
    },
    onError: (err: any) => toast.error(err.response?.data?.message ?? 'Could not save pricing'),
  })

  const current: Draft | null = draft ?? (active ? draftOf(active) : null)

  const curve = useMemo(() => {
    if (!current) return []
    return [1, 3, 5, 8, 10, 13, 16, 20, 25].map(km => {
      const row: Record<string, number | string> = { distance: km }
      for (const surge of SURGE_LEVELS) {
        row[`x${surge}`] = fareAt(current, km, Math.ceil((km / 22) * 60), surge)
      }
      return row
    })
  }, [current])

  if (isLoading) {
    return <div className="p-6"><div className="h-6 w-40 bg-gray-100 animate-pulse rounded" /></div>
  }
  if (!active || !current) {
    return (
      <div className="p-6">
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Fares & Settings</h1>
        <p className="text-sm text-gray-500">No service tiers are configured.</p>
      </div>
    )
  }

  const sampleQuote = fareAt(current, SAMPLE.distanceKm, SAMPLE.durationMinutes, current.surgeMultiplier)

  return (
    <div className="p-4 sm:p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Fares & Settings</h1>
        <p className="text-gray-500 text-sm mt-1">
          Every tier is priced independently. Saving invalidates the quote cache, so the next
          estimate uses these numbers.
        </p>
      </div>

      {/* Service tiers */}
      <div className="card">
        <h2 className="section-title mb-4">Service Tier</h2>
        <div className="divide-y divide-gray-100">
          {(tiers ?? []).map((t: any) => (
            <button
              key={t.vehicleType}
              onClick={() => chooseTier(t)}
              className={clsx('w-full flex flex-wrap items-center gap-3 py-3 px-2 rounded-lg text-left',
                t.vehicleType === active.vehicleType ? 'bg-gray-50' : 'hover:bg-gray-50')}
            >
              <span className="font-semibold text-gray-900">{t.displayName}</span>
              <span className="text-xs text-gray-500">{t.vehicleType}</span>
              <span className="text-sm text-gray-600 ml-auto tabular-nums">
                {t.baseFare.toFixed(2)} ETB base · {t.perKmRate.toFixed(2)} ETB/km
              </span>
              <span className="text-sm text-gray-600 tabular-nums w-28 text-right">
                {t.sampleFare10km.toFixed(2)} ETB
              </span>
              {!t.active && <span className="badge-offline">Disabled</span>}
            </button>
          ))}
        </div>
        <p className="text-xs text-gray-400 mt-3">
          Right-hand column is what a {SAMPLE.distanceKm} km / {SAMPLE.durationMinutes} minute trip
          costs on that tier as it is saved.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Surge curve */}
        <div className="card">
          <h2 className="section-title mb-1">Surge Curve — {current.displayName}</h2>
          <p className="text-xs text-gray-500 mb-4">
            Same trip priced at each surge level, using the numbers in the editor. Duration scales
            with distance at 22 km/h.
          </p>
          <ResponsiveContainer width="100%" height={260}>
            <LineChart data={curve}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="distance" tick={{ fontSize: 12 }} label={{ value: 'km', position: 'insideBottomRight', offset: -5 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v: number) => [`${v.toFixed(2)} ETB`]} />
              <Legend />
              {SURGE_LEVELS.map((s, i) => (
                <Line key={s} type="monotone" dataKey={`x${s}`} name={`${s}x`}
                      stroke={i === 0 ? '#1A1A2E' : ['#4CAF50', '#FFB300', '#D32F2F'][i - 1]}
                      strokeWidth={2} dot={{ r: 3 }} />
              ))}
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Editor */}
        <div className="card space-y-5">
          <div className="flex items-center justify-between">
            <h2 className="section-title">Pricing Model — {active.displayName}</h2>
            <span className="text-xs text-gray-500">
              saved {active.updatedAt ? new Date(active.updatedAt).toLocaleString() : 'never'}
            </span>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Display name</label>
            <input
              className="input" value={current.displayName}
              onChange={e => setDraft({ ...current, displayName: e.target.value })}
              maxLength={40}
            />
          </div>

          <Slider
            label="Base Fares (ETB)" hint="Charged on every trip on this tier."
            value={current.baseFare} min={0} max={1000} step={5}
            onChange={v => setDraft({ ...current, baseFare: v })}
          />
          <Slider
            label="Distance Rates (ETB/km)" hint="Multiplied by the distance actually driven."
            value={current.perKmRate} min={0} max={20} step={0.05}
            onChange={v => setDraft({ ...current, perKmRate: v })}
          />
          <Slider
            label="Time Rates (ETB/min)" hint="Covers traffic, where distance alone under-prices the trip."
            value={current.perMinuteRate} min={0} max={10} step={0.05}
            onChange={v => setDraft({ ...current, perMinuteRate: v })}
          />
          <Slider
            label="Booking Fees (ETB)" hint="Flat, added after surge."
            value={current.bookingFee} min={0} max={200} step={5}
            onChange={v => setDraft({ ...current, bookingFee: v })}
          />
          <Slider
            label="Minimum Fare (ETB)" hint="The floor a short trip still costs."
            value={current.minimumFare} min={0} max={1000} step={5}
            onChange={v => setDraft({ ...current, minimumFare: v })}
          />
          <Slider
            label="Surge Multiplier" hint="1.00 is normal pricing. Applied to distance and time."
            value={current.surgeMultiplier} min={1} max={3} step={0.05}
            onChange={v => setDraft({ ...current, surgeMultiplier: v })}
          />

          <label className="flex items-center gap-2 text-sm text-gray-700">
            <input type="checkbox" checked={current.active}
                   onChange={e => setDraft({ ...current, active: e.target.checked })} />
            Offered to riders
          </label>

          <div className="flex flex-wrap items-center gap-3 pt-2 border-t border-gray-100">
            <span className="text-sm text-gray-600">
              Preview: {SAMPLE.distanceKm} km / {SAMPLE.durationMinutes} min ={' '}
              <strong className="text-gray-900 tabular-nums">{sampleQuote.toFixed(2)} ETB</strong>
            </span>
            <div className="ml-auto flex gap-2">
              <button className="btn-secondary" onClick={() => setDraft(draftOf(active))}>Reset</button>
              <button
                className="btn-primary"
                disabled={saveMutation.isPending}
                onClick={() => saveMutation.mutate({ vehicleType: active.vehicleType, body: current })}
              >
                {saveMutation.isPending ? 'Saving...' : 'Save pricing'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
