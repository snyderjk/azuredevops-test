#!/usr/bin/env bash
# Install heartbeat.py and schedule it to run every minute via cron.
#   sudo ./setup.sh             install / reinstall
#   sudo ./setup.sh --uninstall remove everything
set -euo pipefail

NAME="heartbeat"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="/usr/local/bin/${NAME}.py"
LOG_DIR="/var/log/${NAME}"
LOG_FILE="${LOG_DIR}/${NAME}.log"
CRON_FILE="/etc/cron.d/${NAME}"
LOGROTATE_FILE="/etc/logrotate.d/${NAME}"
RUN_AS="${SUDO_USER:-root}"   # run the job as the invoking user, not root

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0 $*" >&2
  exit 1
fi

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$CRON_FILE" "$LOGROTATE_FILE" "$INSTALL_PATH"
  echo "Uninstalled. Logs left in ${LOG_DIR} (remove manually if desired)."
  exit 0
fi

command -v python3 >/dev/null || { echo "python3 not found" >&2; exit 1; }
command -v cron >/dev/null || command -v crond >/dev/null || {
  echo "cron not found. Install it first (e.g. apt-get install -y cron)." >&2; exit 1; }

# 1. Copy the script
install -m 0755 -o root -g root "${SRC_DIR}/${NAME}.py" "$INSTALL_PATH"
echo "Installed ${INSTALL_PATH}"

# 2. Log directory, writable by the job's user
install -d -m 0755 -o "$RUN_AS" -g "$(id -gn "$RUN_AS")" "$LOG_DIR"
echo "Log directory ${LOG_DIR} (owner: ${RUN_AS})"

# 3. Cron entry (cron.d files must be root-owned, 0644, and end with a newline)
cat > "$CRON_FILE" <<CRON
# Managed by ${SRC_DIR}/setup.sh
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HEARTBEAT_LOG=${LOG_FILE}
* * * * * ${RUN_AS} /usr/bin/env python3 ${INSTALL_PATH} >> ${LOG_DIR}/cron-errors.log 2>&1
CRON
chmod 0644 "$CRON_FILE"
echo "Created ${CRON_FILE}"

# 4. Keep the log from growing forever
if [[ -d /etc/logrotate.d ]]; then
  cat > "$LOGROTATE_FILE" <<ROT
${LOG_DIR}/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    su ${RUN_AS} $(id -gn "$RUN_AS")
}
ROT
  echo "Created ${LOGROTATE_FILE}"
fi

# 5. Make sure cron is running and enabled
if command -v systemctl >/dev/null && [[ -d /run/systemd/system ]]; then
  svc=cron; systemctl list-unit-files cron.service >/dev/null 2>&1 || svc=crond
  systemctl enable --now "$svc" >/dev/null
else
  service cron start 2>/dev/null || service crond start
fi
echo "cron service is running."

echo
echo "Done. First entry appears within a minute:  tail -f ${LOG_FILE}"
