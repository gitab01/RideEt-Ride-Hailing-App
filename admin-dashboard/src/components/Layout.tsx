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
  // Only a drawer on phones; from `md` up the panel is part of the row and cannot be hidden.
  const [drawerOpen, setDrawerOpen] = useState(false)

  const handleLogout = () => { logout(); navigate('/login') }

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50">
      {drawerOpen && (
        <div className="fixed inset-0 z-30 bg-black/40 md:hidden"
             onClick={() => setDrawerOpen(false)} />
      )}

      {/* Sidebar */}
      <aside className={`fixed inset-y-0 left-0 z-40 w-60 bg-[#1A1A2E] text-white flex flex-col
                         transform transition-transform duration-200 shrink-0
                         md:static md:translate-x-0
                         ${drawerOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        <div className="flex items-center gap-3 px-4 py-5 border-b border-white/10">
          <div className="w-9 h-9 bg-yellow-400 rounded-lg flex items-center justify-center shrink-0">
            <Car size={20} className="text-[#1A1A2E]" />
          </div>
          <span className="font-bold text-lg tracking-wide">RideEt</span>
          <button onClick={() => setDrawerOpen(false)} aria-label="Close menu"
            className="ml-auto p-1 hover:bg-white/10 rounded md:hidden">
            <X size={16} />
          </button>
        </div>

        <nav className="flex-1 py-4 space-y-1 px-2">
          {nav.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to} to={to}
              onClick={() => setDrawerOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors
                 ${isActive ? 'bg-yellow-400 text-[#1A1A2E]' : 'text-white/70 hover:bg-white/10 hover:text-white'}`
              }
            >
              <Icon size={18} className="shrink-0" />
              {label}
            </NavLink>
          ))}
        </nav>

        <div className="p-2 border-t border-white/10">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 w-full px-3 py-2.5 rounded-lg text-sm text-white/70 hover:bg-white/10 hover:text-white transition-colors"
          >
            <LogOut size={18} className="shrink-0" />
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="flex items-center gap-3 px-4 py-3 bg-[#1A1A2E] text-white md:hidden">
          <button onClick={() => setDrawerOpen(true)} aria-label="Open menu"
            className="p-1.5 hover:bg-white/10 rounded">
            <Menu size={20} />
          </button>
          <span className="font-bold tracking-wide">RideEt Admin</span>
        </header>
        <main className="flex-1 overflow-y-auto min-w-0">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
