#!/usr/bin/env bash
set -euo pipefail

[ "$#" -ge 1 ] || { echo "usage: attach.sh <base64-json>" >&2; exit 2; }
# Keep stdin on the VS Code PTY: Herdr direct attach needs it for interactive input.
if [ -t 1 ]; then
  exec </dev/tty >/dev/tty 2>&1
fi
exec python3 -c '
import base64, json, os, sys
p = json.loads(base64.b64decode(sys.argv[1]))
os.write(1, ("\033]0;" + p["title"] + "\007").encode())
env = os.environ | {"HERDR_SOCKET_PATH": p["socket"], "HERDR_BIN_PATH": p["herdr_bin"]}
os.execvpe(p["herdr_bin"], [p["herdr_bin"], "terminal", "attach", p["terminal_id"], "--takeover"], env)
' "$1"
