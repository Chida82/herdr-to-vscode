#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/state"

cat >"$tmp/snapshot.json" <<'JSON'
{"result":{"snapshot":{"panes":[{"pane_id":"w5:p4","workspace_id":"w5","tab_id":"w5:t2","terminal_id":"term_current","cwd":"/launch","foreground_cwd":"/live/project","agent":"pi","agent_status":"working"}],"workspaces":[{"workspace_id":"w5","number":5,"label":"Space name"}],"tabs":[{"workspace_id":"w5","tab_id":"w5:t1"},{"workspace_id":"w5","tab_id":"w5:t2"}]}}}
JSON
cat >"$tmp/bin/herdr" <<'SH'
#!/bin/sh
[ "$1 $2" = "api snapshot" ] && cat "$SNAPSHOT" && exit 0
printf '%s\n' "$*" >>"$HERDR_LOG"
SH
cat >"$tmp/bin/code" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$CODE_LOG"
SH
chmod +x "$tmp/bin"/* "$root/scripts"/*.sh

env \
  "PATH=$tmp/bin:$PATH" "SNAPSHOT=$tmp/snapshot.json" "HERDR_LOG=$tmp/herdr.log" \
  "CODE_LOG=$tmp/code.log" "HERDR_BIN_PATH=$tmp/bin/herdr" \
  "HERDR_PLUGIN_ROOT=$root" "HERDR_PLUGIN_STATE_DIR=$tmp/state" "HERDR_PANE_ID=w5:p4" \
  "HERDR_SOCKET_PATH=/tmp/herdr.sock" "HERDR_VSCODE_CODE=$tmp/bin/code" \
  "$root/scripts/open-vscode-terminal.sh"

workspace="$tmp/state/w5:p4-v2.code-workspace"
python3 - "$workspace" "$root/scripts/attach.sh" <<'PY'
import json, sys
w = json.load(open(sys.argv[1]))
t = w["tasks"]["tasks"][0]
assert w["folders"] == [{"path": "/live/project"}]
assert w["settings"]["task.allowAutomaticTasks"] == "on"
assert w["settings"]["terminal.integrated.tabs.title"] == "${sequence}"
assert t["label"] == "Herdr/Space name/2"
assert t["type"] == "shell"
assert t["command"] == sys.argv[2]
assert t["runOptions"]["runOn"] == "folderOpen"
assert t["presentation"]["echo"] is False
assert t["presentation"]["reveal"] == "always"
assert t["presentation"]["focus"] is True
PY
grep -qx -- "--new-window $workspace" "$tmp/code.log"

payload=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tasks"]["tasks"][0]["args"][0])' "$workspace")
env "PATH=$tmp/bin:$PATH" "HERDR_LOG=$tmp/herdr.log" "$root/scripts/attach.sh" "$payload" >/dev/null 2>/dev/null || true
grep -qx "terminal attach term_current --takeover" "$tmp/herdr.log"

echo "ok"
