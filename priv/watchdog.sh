#!/bin/sh

parent_pid="$1"
tty_path="$2"
disarm_path="$3"
log_path="$4"

log() {
  [ -n "$log_path" ] && printf '%s\n' "$1" >> "$log_path"
}

log "start pid=$parent_pid tty=$tty_path disarm=$disarm_path"

while kill -0 "$parent_pid" 2>/dev/null; do
  if [ -e "$disarm_path" ]; then
    log "disarmed-before-exit"
    exit 0
  fi
  sleep 0.1
done

if [ -e "$disarm_path" ]; then
  log "disarmed-after-exit"
  exit 0
fi

printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?25h\033[?1049l\r' > "$tty_path" 2>/dev/null
status=$?
log "cleanup status=$status"
