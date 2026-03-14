#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env.prod"
COMPOSE="podman compose --env-file $ENV_FILE"

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[deploy]${NC} $*"; }
warning() { echo -e "${YELLOW}[deploy]${NC} $*"; }
die()     { echo -e "${RED}[deploy] ERROR:${NC} $*" >&2; exit 1; }

# ── pre-flight ────────────────────────────────────────────────────────────────
[[ -f "$ENV_FILE" ]] || die "$ENV_FILE not found. Copy .env.prod.example and fill in values."
command -v podman        >/dev/null 2>&1 || die "podman not installed"
command -v podman-compose >/dev/null 2>&1 || \
  podman compose version >/dev/null 2>&1 || die "podman-compose not installed"

info "Pulling latest code..."
if git remote get-url origin >/dev/null 2>&1; then
  git pull || warning "git pull failed — deploying with local code."
else
  warning "No git remote configured — skipping git pull."
fi

info "Building image..."
$COMPOSE build

info "Starting database (if not already running)..."
$COMPOSE up -d db

info "Waiting for database to be ready..."
for i in $(seq 1 20); do
  if $COMPOSE exec db pg_isready -U postgres -q 2>/dev/null; then
    break
  fi
  [[ $i -eq 20 ]] && die "Database did not become ready in time."
  sleep 2
done

info "Running migrations..."
$COMPOSE run --rm migrate

info "Restarting app..."
$COMPOSE up -d --force-recreate app

info "Waiting for app to respond..."
for i in $(seq 1 15); do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/products | grep -qE "^[23]"; then
    break
  fi
  [[ $i -eq 15 ]] && die "App did not respond on port 4000 after restart."
  sleep 2
done

info "✓ Deploy complete. App is up at http://localhost:4000"
