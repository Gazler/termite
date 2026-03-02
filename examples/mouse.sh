#!/usr/bin/env bash
set -euo pipefail

# Run from repository root:
#   ./examples/mouse.sh

TTY_PATH="$(tty 2>/dev/null || true)"
RESTORE_SEQ=$'\033[?1003l\033[?1002l\033[?1000l\033[?1006l\033[?25h\033[0m\033[?1049l'

restore_terminal() {
  if [[ -n "${TTY_PATH}" ]]; then
    printf '%s' "${RESTORE_SEQ}" >"${TTY_PATH}" 2>/dev/null || true
    stty sane <"${TTY_PATH}" >/dev/null 2>&1 || true
  fi
}

cleanup() {
  restore_terminal
}

trap cleanup EXIT INT TERM HUP QUIT

# +Bc routes Ctrl+C away from the Erlang break menu path.
ELIXIR_ERL_OPTIONS="${ELIXIR_ERL_OPTIONS:-} +Bc" mix run examples/mouse.exs
