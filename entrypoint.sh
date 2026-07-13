#!/bin/bash
set -e
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
exec hermes dashboard --port 10000 --host 0.0.0.0 --skip-build --no-open