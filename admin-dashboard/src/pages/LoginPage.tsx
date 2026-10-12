import { useState, FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { Car } from 'lucide-react'
import { adminApi } from '../api/client'
import { useAuth } from '../store/authStore'
import toast from 'react-hot-toast'

export default function LoginPage() {
  const [email,    setEmail]    = useState('')
  const [password, setPassword] = useState('')
  const [loading,  setLoading]  = useState(false)
  const { setAuth } = useAuth()
  const navigate    = useNavigate()

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setLoading(true)
    try {
      const res  = await adminApi.login(email, password)
      const data = res.data.data
      if (data.role !== 'ADMIN') {
        toast.error('Admin access only')
        return
      }
      setAuth(data.accessToken, data)
      navigate('/dashboard')
    } catch (err: any) {
      toast.error(err.response?.data?.message ?? 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-white flex items-center justify-center p-4">
      <div className="border border-gray-200 rounded-2xl w-full max-w-sm p-8">
        {/* Logo */}
        <div className="flex items-center gap-3 mb-8">
          <div className="w-11 h-11 bg-[#1A1A2E] rounded-xl flex items-center justify-center">
            <Car size={24} className="text-yellow-400" />
          </div>
          <div>
            <div className="font-bold text-xl text-[#1A1A2E]">RideEt</div>
            <div className="text-xs text-gray-500">Admin Console</div>
          </div>
        </div>

        <h1 className="text-2xl font-bold text-gray-900 mb-1">Administrator sign in</h1>
        <p className="text-gray-500 text-sm mb-6">Console access is limited to admin accounts</p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Administrator Email</label>
            <input
              type="email" required value={email}
              onChange={e => setEmail(e.target.value)}
              className="input"
              placeholder="admin@rideet.com"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
            <input
              type="password" required value={password}
              onChange={e => setPassword(e.target.value)}
              className="input"
              placeholder="••••••••"
            />
          </div>
          <button
            type="submit" disabled={loading}
            className="w-full bg-[#1A1A2E] text-white rounded-lg py-3 font-semibold text-sm
                       hover:bg-primary-600 disabled:opacity-50 transition"
          >
            {loading ? 'Checking...' : 'Secure Login'}
          </button>
        </form>
      </div>
    </div>
  )
}
