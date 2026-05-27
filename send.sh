#!/bin/bash
# Sends an iMessage to a phone number or Apple ID using the macOS Messages app.
#
# Usage:
#   ./send.sh                                      # fully interactive
#   ./send.sh <recipient>                          # prompts for message
#   ./send.sh <recipient> <message>                # send immediately
#   ./send.sh --at HH:MM <recipient> [message]    # schedule for today

set -euo pipefail

SCHEDULE_AT=""

# Parse --at flag
if [[ "${1:-}" == "--at" ]]; then
  SCHEDULE_AT="${2:?'--at requires a time, e.g. --at 14:30'}"
  shift 2
fi

# Positional args
RECIPIENT="${1:-}"
MESSAGE="${2:-}"

# Prompt for anything still missing
if [[ -z "$RECIPIENT" ]]; then
  read -rp "Recipient (phone number or Apple ID email): " RECIPIENT
fi
if [[ -z "$MESSAGE" ]]; then
  read -rp "Message [Hello World 👋]: " MESSAGE
  MESSAGE="${MESSAGE:-Hello World 👋}"
fi

_send() {
  osascript <<EOF
tell application "Messages"
  set targetService to 1st service whose service type = iMessage
  set targetBuddy to buddy "$RECIPIENT" of targetService
  send "$MESSAGE" to targetBuddy
end tell
EOF
  echo "✓ Sent \"$MESSAGE\" to $RECIPIENT"
}

if [[ -z "$SCHEDULE_AT" ]]; then
  _send
else
  # Compute seconds until target time today (or tomorrow if already past)
  TARGET_EPOCH=$(date -j -f "%H:%M" "$SCHEDULE_AT" "+%s" 2>/dev/null) || {
    echo "Invalid time format. Use HH:MM (24-hour), e.g. --at 14:30" >&2
    exit 1
  }
  NOW_EPOCH=$(date +%s)
  DELAY=$(( TARGET_EPOCH - NOW_EPOCH ))
  if (( DELAY < 0 )); then
    DELAY=$(( DELAY + 86400 ))   # push to tomorrow if the time has passed today
  fi
  ARRIVAL_EPOCH=$(( NOW_EPOCH + DELAY ))
  HUMAN=$(date -r "$ARRIVAL_EPOCH" "+%H:%M on %b %d")

  # Spawn background job that sleeps then sends
  (sleep "$DELAY" && _send) &
  disown
  echo "⏰ Scheduled \"$MESSAGE\" → $RECIPIENT at $HUMAN (PID $!)"
fi
