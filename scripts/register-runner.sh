#!/usr/bin/env bash
# Runs ON the VMSS instance (as root) via Azure Run Command.
# Installs the GitHub Actions runner and registers it as an ephemeral runner:
# it picks up exactly one job, then deregisters itself.
#
# Args: $1 repo URL, $2 registration token, $3 runner label/name, $4 runner version
set -euo pipefail

RUNNER_URL="$1"
RUNNER_TOKEN="$2"
RUNNER_LABEL="$3"
RUNNER_VERSION="$4"

RUNNER_USER=ghrunner
RUNNER_DIR="/opt/actions-runner/${RUNNER_LABEL}"

id "$RUNNER_USER" &>/dev/null || useradd -m -s /bin/bash "$RUNNER_USER"

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
curl -fsSL -o runner.tgz \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
tar xzf runner.tgz
rm runner.tgz
./bin/installdependencies.sh
chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

sudo -u "$RUNNER_USER" ./config.sh --unattended --ephemeral --disableupdate \
  --url "$RUNNER_URL" --token "$RUNNER_TOKEN" \
  --name "$RUNNER_LABEL" --labels "$RUNNER_LABEL"

# Detach via systemd so the runner outlives the Run Command invocation.
systemd-run --unit="gh-runner-${RUNNER_LABEL}" --uid="$RUNNER_USER" \
  --working-directory="$RUNNER_DIR" "$RUNNER_DIR/run.sh"

echo "Runner ${RUNNER_LABEL} started."
