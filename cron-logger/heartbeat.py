#!/usr/bin/env python3
"""Append a timestamped heartbeat line to a log file. Intended to run from cron every minute."""

import os
import socket
import sys
from datetime import datetime, timezone

LOG_FILE = os.environ.get("HEARTBEAT_LOG", "/var/log/heartbeat/heartbeat.log")


def main() -> int:
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
    line = f"{timestamp} host={socket.gethostname()} pid={os.getpid()} heartbeat\n"
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
