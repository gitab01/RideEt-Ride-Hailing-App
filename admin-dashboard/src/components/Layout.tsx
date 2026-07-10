import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard, Car, Users, List, Map, LogOut, Menu, X
} from 'lucide-react'
import { useState } from 'react'
import { useAuth } from '../store/authStore'

const nav = [
  { to: '/dashboard', label: 'Dashboard',  icon: LayoutDashboard },
  { to: '/live-map',  label: 'Live Map',   icon: Map             },
  { to: '/rides',     label: 'Rides',      icon: List            },
  { to: '/drivers',   label: 'Drivers',    icon: Car             },
  { to: '/users',     label: 'Users',      icon: Users           },
]

export default function Layout() {
  const { logout } = useAuth()
  const navigate   = useNavigate()
  const [open, setOpen] = useState(true)

  const handleLogout = () => { logout(); navigate('/login') }

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50">
      {/* Sidebar */}
      <aside className={`${open ? 'w-60' : 'w-16'} bg-[#1A1A2E] text-white flex flex-col transition-all duration-200 shrink-0`}>
        <div className="flex items-center gap-3 px-4 py-5 border-b border-white/10">
          <div className="w-9 h-9 bg-yellow-400 rounded-lg flex items-center justify-center shrink-0">
            <Car size={20} className="text-[#1A1A2E]" />
          </div>
          {open && <span className="font-bold text-lg tracking-wide">RideEt</span>}
          <button onClick={() => setOpen(!open)} className="ml-auto p-1 hover:bg-white/10 rounded">
            {open ? <X size={16} /> : <Menu size={16} />}
          </button>
        </div>

        <nav className="flex-1 py-4 space-y-1 px-2">
          {nav.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to} to={to}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors
                 ${isActive ? 'bg-yellow-400 text-[#1A1A2E]' : 'text-white/70 hover:bg-white/10 hover:text-white'}`
              }
            >
              <Icon size={18} className="shrink-0" />
              {open && label}
            </NavLink>
          ))}
        </nav>

        <div className="p-2 border-t border-white/10">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 w-full px-3 py-2.5 rounded-lg text-sm text-white/70 hover:bg-white/10 hover:text-white transition-colors"
          >
            <LogOut size={18} className="shrink-0" />
            {open && 'Sign Out'}
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-y-auto">
        <Outlet />
      </main>
    </div>
  )
}
