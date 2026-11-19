# EcoRide – Backend (Node.js + Express + MariaDB)

REST API that matches the Flutter app (`AppStore`) and the `ecoride_db.sql` schema.
Business rules live in the controllers (same error messages as the app); money / ride changes go through the
stored procedures (`sp_borrow_vehicle`, `sp_return_vehicle`, `sp_confirm_topup`, `sp_adjust_credit`).

## Setup
1. Start MySQL/MariaDB (XAMPP) and import `ecoride_db.sql` (phpMyAdmin > Import).
2. `cp .env.example .env` and set `DB_*` and `JWT_SECRET`.
   `JWT_SECRET` must be 32+ random characters – the server refuses to start with an empty, example or short value
   and prints a ready-to-paste one: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`
3. `npm install`
4. `npm start` (API on http://localhost:3000/api, `GET /api/health`)
5. `npm test` (unit tests, no database needed) / `npm run test:coverage`

Demo accounts from the SQL: password `password123` for every user (admin username `admin`).
Passwords are hashed with **argon2id**. The demo users in the SQL still have bcrypt hashes; they are accepted and silently upgraded to argon2id on first login.

## Endpoints (all under `/api`, JSON; send `Authorization: Bearer <token>`)
| Method & path | AppStore method |
|---|---|
| POST /auth/login, /auth/register, /auth/find-username, /auth/reset-password | login, register, forgot username / password |
| GET/PUT /me, PUT /me/password, PUT /me/avatar, POST /me/avatar/photo, DELETE /me/avatar | updateProfile, changePassword, setAvatar |
| GET /stations, /stations/:id/vehicles, /vehicles, /vehicles/by-code/:code, /vehicle-types, /rental-plans | home, pick vehicle, scan QR |
| POST /rides, GET /rides, /rides/active, /rides/stats, POST /rides/:id/return, /rides/:id/help | borrow, history, returnVehicle, requestHelp |
| GET /credit/transactions, POST /topups, POST /topups/:id/confirm | myTransactions, createTopup, confirmTopup |
| POST /feedback | submitFeedback |
| Admin: /admin/overview, /admin/stations (CRUD + photo), /admin/vehicles (+maintenance), /admin/reports, /admin/rides?open=1, /admin/topups, /admin/transactions, /admin/feedback, /admin/users (+detail, active, credit) | admin tabs |

Errors are `{ "error": "message" }` with 400 / 401 / 403 / 404 / 409.

## Design notes
- Battery is simulated like the app (riding drains, parked vehicles charge); `battery_end` is computed on the server.
- Photos are sent as base64 (`image_base64`, `mime`: png/jpeg/webp, max 2 MB) and saved in `/uploads`.
  The file content is checked (PNG / JPEG / WebP magic bytes); anything else is rejected even if it claims to be an image.
- `ALLOW_SELF_CONFIRM_TOPUP=true` lets a student confirm their own top-up (no real payment gateway yet). Set `false` for admin-only.
- Overdue rides are marked by the SQL event `ev_mark_overdue` (needs `event_scheduler=ON`) and computed live in queries.

## Connecting Flutter later (Sprint 3)
Replace the in-memory methods of `AppStore` with `http` calls to the endpoints above (keep the models; field names equal DB column names).
