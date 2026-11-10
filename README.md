# MiniProject_Booking_Dorm
- node -v
- cmd
- npm init -y
- npm install express mysql2 cors
- npm install @node-rs/argon2
--------------------------
- npm install json-server
- create db.json
- npx json-server todo_db.json
- npm install jsonwebtoken
------------------
run app.js

## Owner dashboard API

The owner dashboard in `hubrage` uses the API in `jinkwaisunkumpang` and the
`dorm_master` MySQL schema. Import `dorm_master.sql`, install the dependencies
in `jinkwaisunkumpang`, then start its server:

```powershell
cd jinkwaisunkumpang
npm install
$env:DB_HOST = "localhost"
$env:DB_USER = "root"
$env:DB_PASSWORD = ""
$env:DB_NAME = "dorm_master"
$env:JWT_SECRET = "<use-a-long-random-secret>"
node Tserver.js
```

The owner API runs on port `3001` so it does not conflict with the existing
backend on port `3000`. Flutter web can use the default owner API URL; for an
Android emulator, start Flutter with
`--dart-define=OWNER_API_URL=http://10.0.2.2:3001`. For a physical device, use
the computer's LAN address instead. The existing `ApiConfig` remains unchanged
for tenant/chat services.
Owner credentials are checked against `users` in `dorm_master`; only active
users with role `seller` can enter the owner dashboard (`POST /api/owner/login`).
The shared `POST /api/login` endpoint also uses that table for tenant/admin
sign-in. To use the SQL fixture account locally, run
`node Server/dorm_api/seed_passwords.js` after importing the database, then
sign in as `seller@test.com` with password `1234`.
node --watch app.js