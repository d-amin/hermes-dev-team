#!/bin/bash
set -e

REPO_URL="https://${GITHUB_TOKEN}@github.com/d-amin/hermes-dev-team.git"
STATE_DIR="/app/hermes-state"

# Restore previous state if it exists
mkdir -p "$STATE_DIR"
cd /app
if [ -d "$STATE_DIR/.git" ]; then
  cd "$STATE_DIR" && git pull 2>/dev/null || true
  cd /app
fi

# Copy back only the safe, non-secret state files
if [ -f "$STATE_DIR/kanban.db" ]; then
  cp "$STATE_DIR/kanban.db" /root/.hermes/kanban.db
fi
if [ -d "$STATE_DIR/sessions" ]; then
  cp -r "$STATE_DIR/sessions" /root/.hermes/
fi
if [ -f "$STATE_DIR/config.yaml" ]; then
  cp "$STATE_DIR/config.yaml" /root/.hermes/config.yaml
fi

# Apply dashboard auth from env vars (never from git)
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

# Background loop: back up ONLY safe state files every 5 minutes
(
  while true; do
    sleep 300
    mkdir -p "$STATE_DIR"
    cp /root/.hermes/kanban.db "$STATE_DIR/" 2>/dev/null || true
    cp -r /root/.hermes/sessions "$STATE_DIR/" 2>/dev/null || true
    cp /root/.hermes/config.yaml "$STATE_DIR/" 2>/dev/null || true
    cd "$STATE_DIR"
    if [ ! -d .git ]; then
      git init
      git remote add origin "$REPO_URL"
    fi
    git add .
    git -c user.email="bot@hermes" -c user.name="hermes-bot" commit -m "Auto-backup state $(date -u +%Y-%m-%dT%H:%M:%S)" 2>/dev/null
    git push origin main 2>/dev/null || true
    cd /app
  done
) &

hermes gateway start &
exec hermes dashboard --port 10000 --host 0.0.0.0 --skip-build --no-open