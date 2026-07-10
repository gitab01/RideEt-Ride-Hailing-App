# RideEt — Ride Hailing App

End-to-end ride hailing platform with real-time driver matching, live GPS tracking, fare estimation, and in-app payments.

## Architecture

```
rideet/
├── backend/          # Spring Boot REST + WebSocket API
├── user-app/         # Flutter Mobile App (Passengers)
├── driver-app/       # Flutter Mobile App (Drivers)
└── admin-dashboard/  # React Web Admin Panel
```

## Tech Stack

| Layer         | Technology                          |
|---------------|-------------------------------------|
| Backend       | Spring Boot 3.x, Java 21            |
| Database      | Microsoft SQL Server                |
| Realtime      | WebSockets (STOMP over SockJS)      |
| User App      | Flutter (iOS + Android)             |
| Driver App    | Flutter (iOS + Android)             |
| Admin Panel   | React 18 + TypeScript + Vite        |
| Maps          | Google Maps SDK                     |
| Payments      | Stripe SDK                          |
| Auth          | JWT + Spring Security               |

## Quick Start

### Backend
```bash
cd backend
./mvnw spring-boot:run
```

### User App
```bash
cd user-app
flutter pub get
flutter run
```

### Driver App
```bash
cd driver-app
flutter pub get
flutter run
```

### Admin Dashboard
```bash
cd admin-dashboard
npm install
npm run dev
```

## Features

### User App
- Register/Login with phone OTP
- Book rides with pickup & destination
- Real-time driver tracking on map
- Fare estimation before booking
- In-app payments (card/wallet)
- Ride history & receipts
- Driver rating system
- SOS emergency button

### Driver App
- Register & submit documents
- Go online/offline toggle
- Accept/decline ride requests
- Live navigation to passenger
- Earnings dashboard
- Ride history

### Admin Dashboard
- Live map with all active rides
- Driver & user management
- Ride monitoring & disputes
- Fare & zone configuration
- Analytics & revenue reports
- Notifications management
