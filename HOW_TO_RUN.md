# How to Run the Backend

## Option 1: Run Locally (For Testing)

### Step 1: Install Python Dependencies
```bash
pip install -r requirements.txt
```

Or install individually:
```bash
pip install Flask==3.0.0 flask-sqlalchemy==3.1.1 flask-cors==4.0.0 flask-socketio==5.3.6 reportlab==4.0.7 gunicorn==21.2.0 psycopg2-binary==2.9.9
```

### Step 2: Set Environment Variables (Optional)
```bash
# On Mac/Linux:
export WRITE_API_KEY="your-secret-key-here"
export DATABASE_URL="sqlite:///rescue_radar.db"  # Optional, defaults to SQLite

# On Windows:
set WRITE_API_KEY=your-secret-key-here
set DATABASE_URL=sqlite:///rescue_radar.db
```

### Step 3: Run the Backend
```bash
python railway_backend.py
```

The server will start on `http://localhost:5001`

### Step 4: Test It
Open your browser and go to:
- `http://localhost:5001/` - Should show "Rescue Radar API"
- `http://localhost:5001/api/v1/readings/all` - Should return JSON with readings

---

## Option 2: Deploy to Railway (Your Existing Project)

### Method A: Update via Railway Dashboard

1. **Go to your Railway project**: https://railway.app
2. **Open your service** (the one at `web-production-87279.up.railway.app`)
3. **Go to Settings** → **Source**
4. **Upload or connect your repository** with the new `railway_backend.py` file
5. **Set Environment Variables** (if not already set):
   - `WRITE_API_KEY` = your secret key
   - `DATABASE_URL` = (usually auto-set by Railway if you have a database)
6. **Redeploy** - Railway will automatically detect changes and redeploy

### Method B: Update via Git (If Connected)

1. **Make sure these files are in your repo:**
   - `railway_backend.py` (or rename your current backend file to this)
   - `requirements.txt`
   - `Procfile`
   - `runtime.txt` (optional)

2. **Commit and push:**
   ```bash
   git add railway_backend.py requirements.txt Procfile
   git commit -m "Update backend with PDF export"
   git push
   ```

3. **Railway will auto-deploy** when it detects the push

### Method C: Manual File Upload

1. **Go to Railway Dashboard** → Your Project → Your Service
2. **Go to Settings** → **Deploy**
3. **Upload the files:**
   - `railway_backend.py` (rename to match your current backend filename if needed)
   - `requirements.txt`
   - `Procfile`
4. **Redeploy**

---

## Option 3: Add PDF Export to Your Existing Backend

If you want to keep your current Railway backend and just add PDF export:

1. **Open your current backend file** in Railway (or download it)
2. **Add this import at the top:**
   ```python
   from io import BytesIO
   try:
       from reportlab.lib.pagesizes import letter
       from reportlab.lib import colors
       from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
       from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
       from reportlab.lib.units import inch
       REPORTLAB_AVAILABLE = True
   except ImportError:
       REPORTLAB_AVAILABLE = False
   ```

3. **Add this route** (copy from `railway_backend.py` lines 200-280):
   ```python
   @app.route("/api/v1/readings/export/pdf", methods=["GET"])
   def export_pdf():
       # ... (copy the full function from railway_backend.py)
   ```

4. **Update requirements.txt** to include `reportlab==4.0.7`
5. **Redeploy on Railway**

---

## Quick Test Commands

### Test GET endpoint (no auth needed):
```bash
curl https://web-production-87279.up.railway.app/api/v1/readings/all
```

### Test POST endpoint (replace YOUR_API_KEY):
```bash
curl -X POST https://web-production-87279.up.railway.app/api/v1/readings \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{"victim_id": "test-001", "distance_cm": 150.5}'
```

### Test PDF export (replace YOUR_API_KEY):
```bash
curl -H "x-api-key: YOUR_API_KEY" \
  https://web-production-87279.up.railway.app/api/v1/readings/export/pdf \
  --output report.pdf
```

---

## Troubleshooting

### "Module not found" errors
- Make sure you ran `pip install -r requirements.txt`
- Check that you're using the correct Python version (3.8+)

### "Port already in use"
- Change the port in `railway_backend.py` (line ~280): `port = int(os.environ.get("PORT", 5002))`
- Or kill the process using port 5001

### Railway deployment fails
- Check that `Procfile` exists and has: `web: gunicorn railway_backend:app --bind 0.0.0.0:$PORT`
- Make sure your main file is named `railway_backend.py` (or update Procfile to match your filename)
- Check Railway logs for specific errors

### Database errors
- Make sure `DATABASE_URL` is set in Railway environment variables
- If using SQLite locally, the file will be created automatically

---

## File Structure Needed

```
your-project/
├── railway_backend.py    # Main backend file
├── requirements.txt      # Python dependencies
├── Procfile              # Railway deployment config
├── runtime.txt           # Python version (optional)
└── .env                  # Local environment variables (optional, don't commit)
```

