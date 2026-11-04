# DormSpace Sprint 2 - API Testing Guide

## Backend Setup Instructions
1. Install dependencies:
   ```bash
   cd backend
   npm install
   ```
2. Setup Database:
   - Import `database/schema.sql` into MySQL Server.
   - Import `database/seed.sql`.
3. Configure `.env`:
   - Set `DB_HOST`, `DB_USER`, `DB_PASS`, and `DB_NAME`.
   - Set `JWT_SECRET` to a unique, random value. The server will not start without it.
4. Start Server:
   ```bash
   npm run dev
   ```

## Test Endpoints Summary
- **POST** `/api/auth/login` - Admin Login
- **GET** `/api/admin/buildings` - Fetch Buildings
- **POST** `/api/admin/buildings` - Create Building
- **POST** `/api/admin/rooms` - Create Room
- **GET** `/api/admin/semesters` - Fetch Semesters
- **POST** `/api/admin/addons` - Create Addon
