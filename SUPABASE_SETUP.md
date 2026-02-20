# Supabase & Render Setup Guide

## 500 Error Fix

The backend API was returning 500 errors because:
1. **Hardcoded credentials in version control** - The DATABASE_URL was exposed in render.yaml
2. **Improper migration handling** - Migrations weren't being run correctly during deployment

## Fixed Issues

✅ Removed hardcoded DATABASE_URL from `render.yaml`
✅ Updated build command to use proper permission handling
✅ Set up to use robust `start.sh` script for migrations with retries

## Required Steps on Render Dashboard

### 1. Set DATABASE_URL Environment Variable

1. Go to **Render Dashboard** → your **structura-backend** service
2. Click **Environment** tab
3. Add/Update the environment variable:
   - **Key**: `DATABASE_URL`
   - **Value**: Get from Supabase → Settings → Database → Connection String (URI)
   
   Format: `postgresql://[user]:[password]@[host]:[port]/[database]`

**Important**: Use the **password field** connection string, not the psql command.

### 2. Verify Other Environment Variables

Make sure these are also set:
- `DEBUG=0` (production)
- `SECRET_KEY` (auto-generated or securely set)
- `CORS_ALLOWED_ORIGINS=https://martyscrackling.github.io`
- `MIGRATE_RETRIES=8`
- `MIGRATE_RETRY_SLEEP_SECONDS=3`

### 3. Redeploy

After setting the environment variables:
1. Click **Manual Deploy** on Render dashboard
2. Select the latest commit
3. Watch the build logs for any migration errors

## Checking for Migration Errors

If migrations still fail:

1. Check **Logs** tab in Render dashboard
2. Look for pattern `Running migrations (attempt X/8)...`
3. Common issues:
   - Wrong password in DATABASE_URL → check Supabase credentials
   - Database doesn't exist → create it in Supabase
   - Wrong host → verify from Supabase connection string

## Testing the API

Once deployed, test with:
```bash
curl https://structura-backend-4vxo.onrender.com/api/
```

Should return JSON API list instead of 500 error.

## Security Notes

⚠️ **Never commit DATABASE_URL with actual credentials to version control**
- Always use Render's environment variables
- If credentials were exposed, rotate them immediately in Supabase
