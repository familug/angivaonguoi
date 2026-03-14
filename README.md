# Angivaonguoi — Food Product Catalog

A Phoenix LiveView app that lets you catalog food products by uploading product images. Google Gemini Vision AI extracts the product name, ingredients (with percentages), categories, and barcode automatically.

**Features:**
- Upload a product photo → AI reads the label
- Browse products filtered by category
- Click any ingredient to find all products containing it, sortable by amount
- User accounts — only logged-in users can upload products

---

## Local Development

**Prerequisites:** Elixir 1.15+, PostgreSQL, a [Gemini API key](https://aistudio.google.com/app/apikey)

```bash
# 1. Clone and install dependencies
mix setup

# 2. Set your Gemini API key
cp .env.example .env
# edit .env and set GEMINI_API_KEY=your_key_here

# 3. Start the server
source .env && mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000).

---

## Deploy with Podman Compose

### Prerequisites

- [Podman](https://podman.io/getting-started/installation) with the `podman-compose` plugin
- A server with ports 4000 (or 80/443 behind a reverse proxy) open

### Step 1 — Prepare secrets

```bash
cp .env.prod.example .env.prod
```

Edit `.env.prod` and fill in all values:

| Variable | How to get it |
|---|---|
| `SECRET_KEY_BASE` | Run `mix phx.gen.secret` (or `openssl rand -base64 48`) |
| `PHX_HOST` | Your server's domain name or IP (no `https://`) |
| `GEMINI_API_KEY` | [Google AI Studio](https://aistudio.google.com/app/apikey) |
| `POSTGRES_PASSWORD` | Choose any strong password |

### Step 2 — Build the image

```bash
podman compose --env-file .env.prod build
```

### Step 3 — Run database migrations

```bash
podman compose --env-file .env.prod run --rm migrate
```

### Step 4 — Start the application

```bash
podman compose --env-file .env.prod up -d app db
```

The app is now running at `http://<your-host>:4000`.

### Nginx reverse proxy (host, with Cloudflare)

The app runs on port 4000 inside the container. Nginx runs on the host and proxies to it. Cloudflare sits in front of Nginx and handles HTTPS.

```bash
# Copy the config to nginx sites-available
sudo cp nginx/angi.pymi.vn.conf /etc/nginx/sites-available/angi.pymi.vn
sudo ln -s /etc/nginx/sites-available/angi.pymi.vn /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

**Cloudflare settings:**
- DNS: A record `angi.pymi.vn` → your server IP, **Proxied** (orange cloud)
- SSL/TLS mode: **Full** (Cloudflare ↔ origin is plain HTTP, Cloudflare ↔ browser is HTTPS)
- No certificate needed on the server — Cloudflare handles it

**PHX_HOST** in `.env.prod` must match the domain:
```
PHX_HOST=angi.pymi.vn
```

### Useful commands

```bash
# View logs
podman compose --env-file .env.prod logs -f app

# Stop everything
podman compose --env-file .env.prod down

# Upgrade: rebuild image, re-run migrations, restart app
podman compose --env-file .env.prod build
podman compose --env-file .env.prod run --rm migrate
podman compose --env-file .env.prod up -d app

# Open a remote shell inside the running container
podman compose --env-file .env.prod exec app bin/angivaonguoi remote
```

### Data persistence

- **PostgreSQL data** is stored in the `pgdata` named volume — survives container restarts and rebuilds.
- **Uploaded images** are stored in the `uploads` named volume mounted at `/app/lib/angivaonguoi-0.1.0/priv/static/uploads`.

---

## Architecture

| Layer | Technology |
|---|---|
| Web framework | Phoenix LiveView (Elixir) |
| Database | PostgreSQL via Ecto |
| AI image parsing | Google Gemini Vision API |
| Password hashing | bcrypt (`bcrypt_elixir`) |
| Styling | Tailwind CSS + DaisyUI |
| Asset pipeline | Mix esbuild + tailwind (no Node needed) |
| Container | Podman / Docker (OCI-compatible) |
