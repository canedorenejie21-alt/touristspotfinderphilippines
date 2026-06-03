# Tourist Spot Finder PH Deployment

Use this for production/public access. Local commands like `flutter run` and `uvicorn --port 8001` are only for demo testing.

## 1. Backend on Render

1. Push this project to GitHub.
2. Open Render and create a new **Blueprint** from this repo, or create a **Web Service** manually using the `BACKEND` folder.
3. Use these settings if manual:
   - Root directory: `BACKEND`
   - Build command: `pip install -r requirements.txt`
   - Start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - Health check path: `/health`
4. Add environment variables:
   - `DATABASE_URL`: your Neon PostgreSQL URL
   - `APP_SECRET_KEY`: any long random secret
   - `FRONTEND_ORIGINS`: your deployed frontend URL, for example `https://your-site.netlify.app`
   - `SMTP_HOST`: `smtp.gmail.com`
   - `SMTP_PORT`: `587`
   - `SMTP_USERNAME`: Gmail address
   - `SMTP_PASSWORD`: Gmail app password
   - `SMTP_FROM_EMAIL`: Gmail address
   - `OTP_EXPIRY_MINUTES`: `10`
   - `ADMIN_EMAILS`: admin Gmail address
5. After deploy, test:

```bash
curl https://YOUR-RENDER-BACKEND.onrender.com/health
```

Expected:

```json
{"status":"ok"}
```

## 2. Frontend Flutter Web

Build the frontend using your Render backend URL:

```bash
cd FRONTEND
flutter clean
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-RENDER-BACKEND.onrender.com
```

Deploy the generated folder:

```text
FRONTEND/build/web
```

Upload it to Netlify:

1. Open Netlify.
2. Go to **Sites**.
3. Drag and drop `FRONTEND/build/web`.
4. Copy the public site URL.
5. Put that URL into Render `FRONTEND_ORIGINS`.
6. Redeploy/restart the backend.

## 3. Final Check

Open the deployed frontend URL and test:

- Register with real Gmail OTP
- Login
- Map
- Reviews
- Community post/comment/like
- Admin dashboard
- Planner and budget

If the frontend shows a backend connection error, check that:

- Render backend is live
- `API_BASE_URL` used during `flutter build web` is the Render backend URL
- Render `FRONTEND_ORIGINS` contains the exact frontend URL
