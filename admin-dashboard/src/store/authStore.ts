import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface AuthState {
  token: string | null
  user:  Record<string, unknown> | null
  setAuth: (token: string, user: Record<string, unknown>) => void
  logout:  () => void
}

// Simple zustand store — add zustand to dependencies if not already present
// For now using a simple module-level store pattern
let _token: string | null = localStorage.getItem('admin_token')
let _user:  Record<string, unknown> | null = null

const listeners: Array<() => void> = []
function notify() { listeners.forEach(l => l()) }

export const useAuthStore = (selector: (s: AuthState) => unknown) => {
  // Minimal implementation without full zustand
  const state: AuthState = {
    token: _token,
    user:  _user,
    setAuth: (token, user) => {
      _token = token
      _user  = user
      localStorage.setItem('admin_token', token)
      notify()
    },
    logout: () => {
      _token = null
      _user  = null
      localStorage.removeItem('admin_token')
      notify()
    },
  }
  return selector(state)
}

// Simple hook for components
import { useState, useEffect } from 'react'

export function useAuth() {
  const [token, setToken] = useState<string | null>(_token)

  useEffect(() => {
    const handler = () => setToken(_token)
    listeners.push(handler)
    return () => { const i = listeners.indexOf(handler); if (i > -1) listeners.splice(i, 1) }
  }, [])

  return {
    token,
    isAuthenticated: !!token,
    setAuth: (t: string, u: Record<string, unknown>) => {
      _token = t; _user = u
      localStorage.setItem('admin_token', t)
      setToken(t)
    },
    logout: () => {
      _token = null; _user = null
      localStorage.removeItem('admin_token')
      setToken(null)
    },
  }
}
