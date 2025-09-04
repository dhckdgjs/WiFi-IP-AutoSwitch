#!/bin/bash
set -euo pipefail

MODE="${1:?mode missing}"      # manual or dhcp
SERVICE="${2:?service missing}"
LOG="/var/log/ssid-ip-switcher.log"

case "$MODE" in
  manual)
    IP="${3:?ip missing}"
    MASK="${4:?mask missing}"
    ROUTER="${5:?router missing}"
    DNS_CSV="${6:-}"
    /usr/sbin/networksetup -setmanual "$SERVICE" "$IP" "$MASK" "$ROUTER"
    if [ -n "$DNS_CSV" ]; then
      IFS=, read -r -a DNS_ARR <<< "$DNS_CSV"
      /usr/sbin/networksetup -setdnsservers "$SERVICE" "${DNS_ARR[@]}"
    else
      /usr/sbin/networksetup -setdnsservers "$SERVICE" empty
    fi
    ;;
  dhcp)
    /usr/sbin/networksetup -setdhcp "$SERVICE"
    /usr/sbin/networksetup -setdnsservers "$SERVICE" empty
    ;;
  *)
    echo "unknown mode: $MODE" >&2; exit 2;;
esac

echo "$(date '+%F %T') $MODE on $SERVICE" >> "$LOG"
