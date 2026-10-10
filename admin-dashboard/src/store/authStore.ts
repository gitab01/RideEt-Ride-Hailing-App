import { create } from 'zustand'

interface AuthState {
  token: string | null
  user:  Record<string, unknown> | null
  setAuth: (token: string, user: Record<string, unknown>) => void
  logout:  () => void
}

// localStorage is the single place the token lives: the axios interceptor and the live map
// socket both read 'admin_token' directly, so persisting a second copy would only drift.
export const useAuthStore = create<AuthState>(set => ({
  token: localStorage.getItem('admin_token'),
  user: null,
  setAuth: (token, user) => {
    localStorage.setItem('admin_token', token)
    set({ token, user })
  },
  logout: () => {
    localStorage.removeItem('admin_token')
    set({ token: null, user: null })
  },
}))

export function useAuth() {
  const token   = useAuthStore(s => s.token)
  const setAuth = useAuthStore(s => s.setAuth)
  const logout  = useAuthStore(s => s.logout)

  return { token, isAuthenticated: !!token, setAuth, logout }
}
