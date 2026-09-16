#!/usr/bin/env bash
set -euo pipefail

herdr_bin=${HERDR_BIN_PATH:-herdr}
code_bin=${HERDR_VSCODE_CODE:-code}
state_dir=${HERDR_PLUGIN_STATE_DIR:?run via Herdr plugin action}
pane_id=${HERDR_PANE_ID:?run from a Herdr pane}

case "$pane_id" in *[!A-Za-z0-9:_-]*|'') echo "herdr.vscode: invalid pane id" >&2; exit 1;; esac
command -v "$code_bin" >/dev/null || { echo "herdr.vscode: VS Code's 'code' command is not on PATH" >&2; exit 1; }
command -v python3 >/dev/null || { echo "herdr.vscode: python3 is required" >&2; exit 1; }
[ -n "${HERDR_SOCKET_PATH:-}" ] || { echo "herdr.vscode: HERDR_SOCKET_PATH is missing" >&2; exit 1; }

snapshot=$("$herdr_bin" api snapshot)
workspace_file="$state_dir/$pane_id-v2.code-workspace"
mkdir -p "$state_dir"

printf '%s' "$snapshot" | python3 -c '
import base64, json, os, pathlib, sys
pane_id, output, attach = sys.argv[1:]
snapshot = json.load(sys.stdin)["result"]["snapshot"]
pane = next((p for p in snapshot["panes"] if p["pane_id"] == pane_id), None)
if not pane:
    raise SystemExit("herdr.vscode: focused pane no longer exists")
workspace = next((w for w in snapshot["workspaces"] if w["workspace_id"] == pane["workspace_id"]), None)
tabs = [t for t in snapshot["tabs"] if t["workspace_id"] == pane["workspace_id"]]
tab_number = next((i for i, t in enumerate(tabs, 1) if t["tab_id"] == pane["tab_id"]), None)
cwd = pane.get("foreground_cwd") or pane.get("cwd")
terminal_id = pane.get("terminal_id")
if not cwd or not terminal_id or not workspace or not tab_number:
    raise SystemExit("herdr.vscode: incomplete pane context")
title = "Herdr/{}/{}".format(workspace["label"], tab_number)
payload = base64.b64encode(json.dumps({
    "herdr_bin": os.environ.get("HERDR_BIN_PATH", "herdr"),
    "socket": os.environ["HERDR_SOCKET_PATH"],
    "terminal_id": terminal_id,
    "title": title,
}).encode()).decode()
config = {
    "folders": [{"path": cwd}],
    "settings": {
        "task.allowAutomaticTasks": "on",
        "terminal.integrated.tabs.title": "${sequence}",
    },
    "tasks": {
        "version": "2.0.0",
        "tasks": [{
            "label": title,
            "type": "shell",
            "command": attach,
            "args": [payload],
            "options": {"cwd": cwd},
            "problemMatcher": [],
            "runOptions": {"runOn": "folderOpen", "instanceLimit": 1},
            "presentation": {
                "echo": False,
                "reveal": "always",
                "focus": True,
                "panel": "dedicated",
                "showReuseMessage": False,
                "clear": True,
            },
        }],
    },
}
path = pathlib.Path(output)
tmp = path.with_suffix(path.suffix + ".tmp")
tmp.write_text(json.dumps(config, indent=2) + "\n")
tmp.replace(path)
' "$pane_id" "$workspace_file" "$HERDR_PLUGIN_ROOT/scripts/attach.sh"

# A stable workspace file makes VS Code focus the existing pane-specific window on repeat.
exec "$code_bin" --new-window "$workspace_file"
