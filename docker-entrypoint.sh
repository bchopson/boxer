#!/usr/bin/env bash
set -euo pipefail

# If you ever drop into an interactive shell inside krunvm, these help avoid
# CR/LF weirdness on some console stacks.
stty sane >/dev/null 2>&1 || true
stty icrnl >/dev/null 2>&1 || true

# Start sshd only if explicitly requested (keeps default simple)
if [[ "${START_SSHD:-0}" == "1" ]]; then
  ssh-keygen -A >/dev/null 2>&1 || true
  /usr/sbin/sshd
fi

# Start Docker daemon (rootful)
# No systemd inside this image; just start dockerd in the background.
if ! pgrep -x dockerd >/dev/null 2>&1; then
  dockerd \
    --host=unix:///var/run/docker.sock \
    --storage-driver=overlay2 \
    >/var/log/dockerd.log 2>&1 &
fi

# Wait for Docker to be responsive (best-effort)
for i in {1..50}; do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

cd "${REPO_DIR}" 2>/dev/null || true

# Launch whatever CMD was provided (default: codex)
exec "$@"
