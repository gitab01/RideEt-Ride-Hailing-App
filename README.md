# RideEt — Ride Hailing Platform

Four parts, one backend: a passenger app, a driver app, and a web admin dashboard on top of a
Spring Boot API that owns ride state, driver matching, live GPS and fares.

```
RideEt-Ride-Hailing-App/
├── backend/           # Spring Boot 3.2.5 / Java 17 — REST + STOMP over WebSocket
├── user-app/          # Flutter — "RideEt User" (passenger, Android)
├── driver-app/        # Flutter — "RideEt Driver" (driver, Android)
├── admin-dashboard/   # React 18 + TypeScript + Vite — admin console
└── docker-compose.yml # MS SQL + backend + admin image (production shape)
```

## Requirements

| Part            | Needs                                                            |
|-----------------|------------------------------------------------------------------|
| Backend         | JDK 17, Maven 3.9+                                               |
| Mobile apps     | Flutter 3.29+ (Dart 3.2+), Android SDK 34+, Google Maps API key   |
| Admin dashboard | Node 20+                                                          |

## Run it

### 1. Backend (in-memory H2, no database to install)

```bash
cd backend
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

API on `http://localhost:8080/api/v1`, H2 console on `http://localhost:8080/api/v1/h2-console`
(JDBC URL `jdbc:h2:mem:rideet`, user `sa`, empty password). The `dev` profile creates and drops the
schema on every boot and seeds the accounts below.

Without `-Dspring-boot.run.profiles=dev` the app targets Microsoft SQL Server from `DB_URL`
(see `docker-compose.yml` for a local instance).

### 2. Admin dashboard

```bash
cd admin-dashboard
npm install
npm run dev            # http://localhost:5173
```

The dev server proxies `/api` to `http://localhost:8080` with WebSocket upgrades enabled. Point it
somewhere else with `VITE_API_PROXY=http://localhost:8091 npm run dev`.

Log in with the seeded admin account. The login screen rejects any token whose role is not `ADMIN`,
so a driver or passenger password will not get in.

### 3. Mobile apps

Both apps need a Google Maps key before they show a map:

- `user-app/android/app/src/main/AndroidManifest.xml`
- `driver-app/android/app/src/main/AndroidManifest.xml`

Replace `YOUR_GOOGLE_MAPS_API_KEY` (enable *Maps SDK for Android* in Google Cloud).

```bash
cd user-app          # or driver-app
flutter pub get
flutter run
```

`lib/core/config/app_config.dart` in each app points at `10.0.2.2`, the host loopback as seen from
the Android emulator. Running on a physical phone means editing
`baseUrl`/`wsUrl` to the machine's LAN IP (for example `http://192.168.1.20:8080/api/v1`) with the
phone on the same Wi-Fi network.

## Seeded dev accounts

| Email                  | Password        | Role      |
|------------------------|-----------------|-----------|
| `admin@rideet.com`     | `Admin@1234`    | ADMIN     |
| `passenger@rideet.com` | `Passenger@1234`| PASSENGER |
| `driver1@rideet.com`   | `Driver@1234`   | DRIVER, verified, ONLINE |
| `driver2@rideet.com`   | `Driver@1234`   | DRIVER, verified, ONLINE |
| `driver3@rideet.com`   | `Driver@1234`   | DRIVER, verified, ONLINE |

Sign-in is email and password — there is no phone-number login endpoint. The only six-digit code in
the product is the boarding OTP the server issues when a driver is assigned: the passenger sees it
on the tracking screen, and the driver must enter it, while standing near the pickup, to start the
trip.

## How a ride actually works

1. The passenger books; the ride enters `SEARCHING` and the server starts offering it in rounds.
2. Each round contacts the nearest free drivers of the requested vehicle class inside the current
   radius, starting at 2 km and doubling per round until `matching.max-radius-km`, then releases the
   ride as `NO_DRIVER_FOUND`.
3. Every offered driver gets a 20-second window (`matching.offer-window-seconds`). Acceptance is a
   compare-and-set on `rides.status`, so when two drivers tap at once exactly one wins and the other
   is told the ride is gone.
4. The passenger receives a boarding OTP. The driver can only start the trip after entering it, and
   only while standing near the pickup point.
5. Driver pings flow over `/app/location.update`. Live position is held in memory (a grid index for
   matching, a topic per driver for the passenger map, one topic for the admin map) and the GPS
   trail is batched into the database — a per-ping write never happens.
6. The final fare is measured from that trail (haversine distance plus elapsed time) using the same
   rates as the estimate, and is refused if it deviates from the quoted fare by more than
   `fare.max-deviation-ratio`.
7. State changes are only made by the server and each one appends a row to `ride_events`. The admin
   rides table expands to show that trail: who moved the ride from which status to which, when, and
   with what note.

A driver that goes offline or is suspended is removed from the live index, so it can never be
offered a ride; a driver on a trip stays placed so the boarding check and the admin map see the
truth, and matching filters it by status instead.

## Realtime surface

| Direction  | Address                        | Who listens                     |
|------------|--------------------------------|---------------------------------|
| inbound    | `/app/location.update`         | driver app (GPS ping)           |
| user queue | `/user/queue/ride-updates`     | passenger: assigned, arrived, started, completed, cancelled, no-driver |
| user queue | `/user/queue/ride-requests`    | driver: `RIDE_OFFER`, `OFFER_CANCELLED`, `RIDE_CANCELLED` |
| topic      | `/topic/driver-location/{userId}` | passenger live map for that driver |
| topic      | `/topic/admin/live-rides`      | admin live map (`DRIVER_LOCATION` and ride events) |

Connect with a `Authorization: Bearer <jwt>` header on the STOMP CONNECT frame.
Endpoint: `/api/v1/ws` (raw WebSocket and SockJS both registered).

## Configuration

Everything is environment-overridable; defaults are safe for local work.

| Variable            | Default                 | Notes                                        |
|---------------------|-------------------------|----------------------------------------------|
| `PORT`              | `8080`                  | API port                                     |
| `DB_URL`            | local MS SQL            | only consumed outside the `dev` profile      |
| `DB_USERNAME` / `DB_PASSWORD` | `sa` / `YourStrong@Passw0rd` | change before any reachable deployment |
| `JWT_SECRET`        | dev string              | must be replaced in production               |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | `admin@rideet.com` / `Admin@1234` | seeded on boot, logged as a warning |
| `STRIPE_SECRET_KEY` | placeholder             | card payments; cash rides need none          |
| `STRIPE_CURRENCY`   | `usd`                   | Stripe has no ETB, so fares are quoted in birr and settled in this currency |
| `GOOGLE_MAPS_API_KEY` | placeholder           | also required in each app's AndroidManifest  |
| `STORAGE_DIR`       | `./uploads`             | onboarding documents, served from `/api/v1/files/**` |

Fare rates and matching radii live in `backend/src/main/resources/application.yml` under `fare:`
and `matching:`.

## Onboarding and documents

A new driver registers with email/OTP, files vehicle details, and uploads licence, registration and
insurance through `POST /uploads/document` (jpg, png, webp or pdf, 10 MB max). Files are stored
under `STORAGE_DIR` with random names and served back from `/api/v1/files/**`. An admin flips
`documentsVerified`; only then may the driver go online.

## Tests run against this build

The backend was verified end to end on a fresh H2 database: 43 REST checks (quote → book → offer →
accept race → wrong/correct OTP → boarding proximity → completion with measured fare → both ratings
→ history → admin lists → RBAC → audit trail → suspension and lift → driver back-out and re-match →
terminal-state guards → dashboard totals) and 13 STOMP checks over a real WebSocket (offer to the
driver queue, round info to the passenger, assigned-driver handoff, driver ping reaching both the
passenger and admin maps, cancellation fan-out).

The harnesses are deliberately not committed; they drive the API from the outside and are meant to
be rewritten as proper integration tests when the project needs CI.

## Production shape

`docker-compose.yml` builds the backend image, runs it against MS SQL, and serves the dashboard's
`dist/` behind nginx. The nginx config forwards `/api/v1/ws` with `Upgrade`/`Connection` headers —
without it the admin live map never connects. Before publishing: set `JWT_SECRET`, `ADMIN_PASSWORD`,
`DB_PASSWORD`, real Stripe keys, and change `ddl-auto` away from `update`.
