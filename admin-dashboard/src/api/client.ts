import axios from 'axios'

const api = axios.create({
  baseURL: '/api/v1',
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use(config => {
  const token = localStorage.getItem('admin_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  res => res,
  err => {
    if (err.response?.status === 401) {
      localStorage.removeItem('admin_token')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default api

// API helpers
export const adminApi = {
  getDashboard:    ()           => api.get('/admin/dashboard'),
  getDailyStats:   (days = 7)   => api.get(`/admin/stats/daily?days=${days}`),
  getDrivers:      (page = 0)  => api.get(`/admin/drivers?page=${page}&size=20`),
  getUsers:        (page = 0)  => api.get(`/admin/users?page=${page}&size=20`),
  getRides:        (page = 0, size = 20) => api.get(`/admin/rides?page=${page}&size=${size}`),
  getActiveRides:  ()           => api.get('/admin/rides/active'),
  getRideEvents:   (id: number) => api.get(`/admin/rides/${id}/events`),
  getDriverLocations: ()        => api.get('/admin/drivers/locations'),
  verifyDriver:    (id: number) => api.post(`/admin/drivers/${id}/verify`),
  rejectDriver:    (id: number, reason: string) =>
    api.post(`/admin/drivers/${id}/reject`, { reason }),
  suspendDriver:   (id: number) => api.post(`/admin/drivers/${id}/toggle-suspend`),
  toggleUser:      (id: number) => api.post(`/admin/users/${id}/toggle-status`),
  getDispatchCandidates: (rideId: number) =>
    api.get(`/admin/rides/${rideId}/dispatch-candidates`),
  assignDriver:    (rideId: number, driverId: number) =>
    api.post(`/admin/rides/${rideId}/assign?driverId=${driverId}`),
  cancelRide:      (rideId: number, reason: string) =>
    api.post(`/admin/rides/${rideId}/cancel`, null, { params: { reason } }),
  getPricing:      ()           => api.get('/admin/pricing'),
  updatePricing:   (vehicleType: string, body: Record<string, unknown>) =>
    api.put(`/admin/pricing/${vehicleType}`, body),
  login:           (email: string, password: string) =>
    api.post('/auth/login', { email, password }),
}
