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

| Phone             | Email                  | Password         | Role                       |
|-------------------|------------------------|------------------|----------------------------|
| `+251911000001`   | `passenger@rideet.com` | `Passenger@1234` | PASSENGER                  |
| `+251911000011`   | `driver1@rideet.com`   | `Driver@1234`    | DRIVER, verified, ONLINE   |
| `+251911000012`   | `driver2@rideet.com`   | `Driver@1234`    | DRIVER, verified, ONLINE   |
| `+251911000013`   | `driver3@rideet.com`   | `Driver@1234`    | DRIVER, verified, ONLINE   |
| —                 | `admin@rideet.com`     | `Admin@1234`     | ADMIN (console only)       |

There are three ways in, and every one of them is real:

- **Password** — `POST /auth/login` takes *either* `email` or `phone`. Both apps send the phone, in
  international format; the driver app prefixes the +251 dial code the user typed digits into.
- **One-time code** — `POST /auth/otp/send` then `POST /auth/otp/verify` signs a passenger in with no
  password at all. In the `dev` profile no SMS is sent: the response carries the live code and the
  passenger app prints it on the screen.
- **Password reset** — the same two steps under a separate purpose
  (`/auth/password-reset/send`, `/auth/password-reset/confirm`), so "Forgot Password?" changes the
  stored hash instead of opening a dead link. A reset code cannot be replayed as a login code.

The boarding code is a different thing: it is the six-digit OTP the server issues when a driver is
assigned. The passenger sees it on the tracking screen and the driver must enter it, standing near
the pickup, to start the trip.

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

A new driver uses the Register tab of the driver app — first name, last name, email, phone in
international format and a password — then files vehicle details, and uploads licence, registration
and insurance through `POST /uploads/document` (jpg, png, webp or pdf, 10 MB max). Files are stored
under `STORAGE_DIR` with random names and served back from `/api/v1/files/**`. An admin flips
`documentsVerified`; only then may the driver go online.

## Tests run against this build

The backend was verified end to end on a fresh H2 database: 43 REST checks (quote → book → offer →
accept race → wrong/correct OTP → boarding proximity → completion with measured fare → both ratings
→ history → admin lists → RBAC → audit trail → suspension and lift → driver back-out and re-match →
terminal-state guards → dashboard totals) and 13 STOMP checks over a real WebSocket (offer to the
driver queue, round info to the passenger, assigned-driver handoff, driver ping reaching both the
passenger and admin maps, cancellation fan-out).

This pass re-ran the parts the new screens depend on, against a live `dev` instance: password login
by phone, OTP send/verify, the whole reset round trip (send → confirm → sign in with the new
password), registration and re-login for a brand-new driver, duplicate-phone rejection,
`/rides/options` for all four tiers (the tier with no free car comes back with a null ETA and zero
drivers rather than a phantom one), `/rides/estimate`, book → search → admin dispatch candidates →
cancel, `/driver/earnings?days=7`, and the admin pricing, driver-location, daily-stats and
reject endpoints. The matching log shows round 1 declining at 2 km and reaching a driver 3.96 km
away on the next round, which is the intended ramp.

`user-app` analyses clean and passes 5 widget tests (onboarding paging, the default +251 dial code,
and the three sign-in guards that stop the app sending a number or password the server would reject);
`driver-app` passes 4 (phone and password guards, the masked password toggle, the Register tab). The
dashboard passes `npm run build` (type-check plus Vite). **No APK has been produced** — a Gradle
Android build needs more memory than this machine has, so the apps are verified at the analyzer,
widget-test and live-API level only.

`mvn test` runs ten committed unit tests over the two rules everything else trusts and no single
endpoint can show on its own: the ride transition table (a finished ride has no outgoing edge, a
failed search cannot be claimed late, a driver may back out of an assignment but nobody may extend
a trip) and the fare rules (each tier prices itself, surge multiplies base and distance but never
the booking fee, the minimum floors a stub trip, and an edited rate only reaches quotes once the
cache is dropped — which is what the admin Fares page does on save). The outside REST and STOMP
harnesses are still not committed: they drive a live server and belong in a CI job with a database.

## Not built, on purpose

The reference screens show a few controls this backend has no answer for, and a button that lies is
worse than a button that is missing. Left out deliberately:

- **Google / Facebook sign-in** — needs OAuth client IDs from a cloud console.
- **SOS and in-trip chat** — an SOS that only shows a dialog, and a chat with no server-side
  conversation, would misrepresent safety features.
- **Driver cash-out** — no payout provider is integrated; the wallet reports the server's balance and
  stops there.
- **Turn-by-turn navigation** ("Turn Right: Bole Road, ETA 4 min") — there is no routing engine, so
  the driver header shows the real pickup or drop-off address and the passenger's own ETA instead.
- **Passenger rating on the offer card** — `RideOfferResponse` does not carry it, and inventing a
  star value for a person who has not rated anything is not a display bug, it is a data lie.
- **Admin "Request Access"** — self-service admin sign-up against a seeded superuser; the console is
  reachable with the seeded account.

## Production shape

`docker-compose.yml` builds the backend image, runs it against MS SQL, and serves the dashboard's
`dist/` behind nginx. The nginx config forwards `/api/v1/ws` with `Upgrade`/`Connection` headers —
without it the admin live map never connects. Before publishing: set `JWT_SECRET`, `ADMIN_PASSWORD`,
`DB_PASSWORD`, real Stripe keys, and change `ddl-auto` away from `update`.
