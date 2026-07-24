#!/bin/bash
set -e

# --- Rebuild credentials from Render's persisted env vars on every boot ---
cat > /root/.hermes/.env <<EOF
GEMINI_API_KEY=${GEMINI_API_KEY}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
EOF

REPO_URL="https://${GITHUB_TOKEN}@github.com/d-amin/hermes-dev-team.git"
STATE_DIR="/app/hermes-state"
STATE_BRANCH="hermes-state"

# --- Restore kanban/session state (not secrets) from the dedicated branch ---
rm -rf "$STATE_DIR"
if git clone --branch "$STATE_BRANCH" --single-branch "$REPO_URL" "$STATE_DIR" 2>/dev/null; then
  echo "Restored previous state from $STATE_BRANCH branch"
  cp "$STATE_DIR/kanban.db" /root/.hermes/kanban.db 2>/dev/null || true
  cp -r "$STATE_DIR/sessions" /root/.hermes/ 2>/dev/null || true
  cp "$STATE_DIR/config.yaml" /root/.hermes/config.yaml 2>/dev/null || true
  cp -r "$STATE_DIR/channels" /root/.hermes/ 2>/dev/null || true
else
  echo "No previous state branch found, starting fresh"
  mkdir -p "$STATE_DIR"
  cd "$STATE_DIR"
  git init -b "$STATE_BRANCH"
  git remote add origin "$REPO_URL"
  cd /app
fi

# --- Apply dashboard auth (from Render env vars) ---
python3 - <<'EOF'
import yaml, os
path = "/root/.hermes/config.yaml"
with open(path) as f:
    config = yaml.safe_load(f) or {}
config.setdefault("dashboard", {}).setdefault("basic_auth", {})
config["dashboard"]["basic_auth"]["username"] = os.environ["DASHBOARD_USER"]
config["dashboard"]["basic_auth"]["password_hash"] = os.environ["DASHBOARD_PASSWORD_HASH"]
with open(path, "w") as f:
    yaml.dump(config, f)
EOF

# --- Background loop: back up kanban/session/config state every 5 minutes ---
(
  while true; do
    sleep 300
    cp /root/.hermes/kanban.db "$STATE_DIR/" 2>/dev/null || true
    cp -r /root/.hermes/sessions "$STATE_DIR/" 2>/dev/null || true
    cp /root/.hermes/config.yaml "$STATE_DIR/" 2>/dev/null || true
    cp -r /root/.hermes/channels "$STATE_DIR/" 2>/dev/null || true
    cd "$STATE_DIR"
    git add .
    git -c user.email="bot@hermes" -c user.name="hermes-bot" commit -m "Auto-backup $(date -u +%Y-%m-%dT%H:%M:%S)" 2>/dev/null
    git push -f origin "$STATE_BRANCH" 2>/dev/null || true
    cd /app
  done
) &

hermes gateway start &
exec hermes dashboard --port 10000 --host 0.0.0.0 --skip-build --no-open