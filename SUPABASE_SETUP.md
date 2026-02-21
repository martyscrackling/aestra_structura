# Supabase & Render Setup Guide

## 500 Error Fix

The backend API was returning 500 errors because:
1. **Hardcoded credentials in version control** - The DATABASE_URL was exposed in render.yaml
2. **Improper migration handling** - Migrations weren't being run correctly during deployment
3. **Missing DATABASE_URL environment variable** - Backend falls back to SQLite without production data

## Fixed Issues

✅ Removed hardcoded DATABASE_URL from `render.yaml`
✅ Updated build command to use proper permission handling
✅ Set up robust `start.sh` script for migrations with retries
✅ Added health check endpoint for diagnostics (`/api/health/`)
✅ Added production warnings when DATABASE_URL is missing

## Required Steps on Render Dashboard

### 1. Set DATABASE_URL Environment Variable ⚠️ CRITICAL

1. Go to **Render Dashboard** → your **structura-backend** service
2. Click **Environment** tab
3. Add/Update the environment variable:
   - **Key**: `DATABASE_URL`
   - **Value**: Get from Supabase → Settings → Database → Connection String (URI)
   
   Format: `postgresql://[user]:[password]@[host]:[port]/[database]?sslmode=require`

**Important**: Use the **password field** connection string, not the psql command.

### 2. Verify Other Environment Variables

Make sure these are also set (AUTO-GENERATED ones can stay as is):
- `DEBUG=0` (production)
- `SECRET_KEY` (auto-generated - don't change if working)
- `CORS_ALLOWED_ORIGINS=https://martyscrackling.github.io`
- `MIGRATE_RETRIES=8`
- `MIGRATE_RETRY_SLEEP_SECONDS=3`
- `DJANGO_SETTINGS_MODULE=structura_backend.settings`
- `PYTHONUNBUFFERED=1`

### 3. Redeploy

After setting/verifying the environment variables:
1. Click **Manual Deploy** on Render dashboard
2. Select the latest commit
3. Watch the build logs for success

## Debugging Connection Issues

### Step 1: Check Health Endpoint
```bash
curl https://structura-backend-4vxo.onrender.com/api/health/
```

Expected response:
```json
{
  "status": "ok",
  "database": {
    "status": "connected",
    "error": null,
    "engine": "django.db.backends.postgresql",
    "name": "your_db_name"
  },
  "version": "1.0"
}
```

If you see `"engine": "django.db.backends.sqlite3"`, it means **DATABASE_URL is not set** → Go back to Step 1.

### Step 2: Check Render Logs
1. Go to Render Dashboard → structura-backend
2. Click **Logs** tab
3. Look for these patterns:
   - `Running migrations (attempt 1/8)` - indicates migrations are running
   - `Migrations OK` - indicates success
   - `Migrations failed` - indicates database connection issue
   - `WARNING: DATABASE_URL environment variable is not set!` - confirms missing env var

### Step 3: Verify Supabase Connection String

The connection string should:
- ✅ Start with `postgresql://`
- ✅ Include username and password
- ✅ Have the correct host (something like `db.xxxxxxxxxxxx.supabase.co`)
- ✅ End with `?sslmode=require`

❌ **Don't use**: `psql` command or incomplete strings

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| `"engine": "sqlite3"` in health check | DATABASE_URL not set | Set DATABASE_URL in Render Environment |
| `error: "could not translate host name"` | Wrong host in connection string | Double-check Supabase connection string |
| `FATAL: password authentication failed` | Wrong password in connection string | Verify Supabase database password |
| `Migrations failed after 8 attempts` | Database doesn't exist or wrong name | Create database in Supabase or check DB name |
| CORS errors in Flutter app | CORS not configured | Set CORS_ALLOWED_ORIGINS to your Flutter Web URL |

## Testing the API

Once deployed, test with:
```bash
# Health check
curl https://structura-backend-4vxo.onrender.com/api/health/

# API endpoints
curl https://structura-backend-4vxo.onrender.com/api/users/
curl https://structura-backend-4vxo.onrender.com/api/projects/
```

Should return JSON data instead of 500 error.

## Security Notes

⚠️ **Never commit DATABASE_URL with actual credentials to version control**
- Always use Render's environment variables
- If credentials were exposed, rotate them immediately in Supabase
- Check Git history: `git log -p --all -- Pipfile render.yaml`

## Still Having Issues?

1. Ensure you committed the latest code with health check
2. Redeploy on Render dashboard (Manual Deploy)
3. Check the `/api/health/` endpoint to see exact error
4. Check Render logs for the full error message
5. Verify Supabase database is running and accessible
