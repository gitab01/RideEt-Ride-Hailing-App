import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import LoginPage from './pages/LoginPage'
import DashboardPage from './pages/DashboardPage'
import DriversPage from './pages/DriversPage'
import FaresPage from './pages/FaresPage'
import UsersPage from './pages/UsersPage'
import RidesPage from './pages/RidesPage'
import LiveMapPage from './pages/LiveMapPage'
import { useAuthStore } from './store/authStore'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore(s => s.token)
  return token ? <>{children}</> : <Navigate to="/login" replace />
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/" element={<ProtectedRoute><Layout /></ProtectedRoute>}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="drivers"   element={<DriversPage />} />
          <Route path="fares"     element={<FaresPage />} />
          <Route path="users"     element={<UsersPage />} />
          <Route path="rides"     element={<RidesPage />} />
          <Route path="live-map"  element={<LiveMapPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
