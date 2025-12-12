# Railway Deployment Guide

## Quick Setup

Your Flutter app is already configured to use: `https://web-production-87279.up.railway.app`

## Backend Files for Railway

1. **railway_backend.py** - Main Flask application (Railway-ready)
2. **requirements.txt** - Python dependencies
3. **Procfile** - Tells Railway how to run the app
4. **runtime.txt** - Python version specification

## Railway Environment Variables

Set these in your Railway project settings:

1. **WRITE_API_KEY** - Your API key for write operations (default: "rescue-radar-dev")
2. **DATABASE_URL** - Automatically provided by Railway if you add a PostgreSQL database

## Deployment Steps

1. **Connect your repository** to Railway (or upload files)

2. **Add a PostgreSQL database** (Railway will auto-set `DATABASE_URL`)

3. **Set environment variables:**
   - `WRITE_API_KEY` = your secret API key

4. **Deploy** - Railway will automatically:
   - Install dependencies from `requirements.txt`
   - Run the app using `Procfile` (gunicorn)
   - Use the PORT environment variable

## API Endpoints

- `GET /api/v1/readings/all` - Get all readings (no auth)
- `POST /api/v1/readings` - Create/update reading (requires `x-api-key` header)
- `GET /api/v1/readings/export/pdf` - Export PDF (requires `x-api-key` header)
- `POST /admin/init-db` - Initialize database (requires `x-api-key` header)

## Notes

- The backend uses Railway's `PORT` environment variable automatically
- PDF export requires `reportlab` (included in requirements.txt)
- Socket.IO is optional (works if installed, gracefully degrades if not)
- Database auto-initializes on first run

## Testing

After deployment, test the API:

```bash
# Test GET endpoint
curl https://web-production-87279.up.railway.app/api/v1/readings/all

# Test POST endpoint (replace YOUR_API_KEY)
curl -X POST https://web-production-87279.up.railway.app/api/v1/readings \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{"victim_id": "test-001", "distance_cm": 150.5}'
```

