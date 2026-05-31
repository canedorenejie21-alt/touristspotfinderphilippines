# Tourist Spot Finder PH Backend

FastAPI backend with PostgreSQL/Neon support. It uses `DATABASE_URL`; if you do not set one, it falls back to local SQLite for development.

## Setup

```bash
cd BACKEND
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

For Neon, set `DATABASE_URL` in `.env`:

```text
DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST.neon.tech/DBNAME?sslmode=require
```

## Email Verification

Set SMTP values in `.env`. For Gmail, enable 2-Step Verification and create an App Password:

```text
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=yourgmail@gmail.com
SMTP_PASSWORD=your_16_character_app_password
SMTP_FROM_EMAIL=yourgmail@gmail.com
```

API docs:

```text
http://localhost:8000/docs
```
