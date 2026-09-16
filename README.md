# herdr.vscode

`prefix+i` opens the focused Herdr pane's live directory in VS Code and attaches one integrated terminal to that exact terminal session. It works for Pi or a plain shell because it uses Herdr's pane `terminal_id`, not the agent API.

No VS Code extension and no macOS UI automation are used.

## Install

```sh
herdr plugin link /Users/dchini/github/chida82/herdr-to-vscode
```

Add this to `~/.config/herdr/config.toml`, then reload it:

```toml
[[keys.command]]
key = "prefix+i"
type = "plugin_action"
command = "herdr.vscode.open"
description = "open the current Herdr pane in VS Code"
```

```sh
herdr server reload-config
```

## How it works

The plugin writes a pane-specific `.code-workspace` under its Herdr state directory and opens it with `code --new-window`. That workspace contains a `folderOpen` task which VS Code reveals and focuses in its integrated terminal. The task runs:

```sh
herdr terminal attach <terminal_id> --takeover
```

This shows the existing pane session—not a new shell and not the full Herdr UI—so typing in VS Code continues in the same Pi/shell process. Detach with `ctrl+b q`; `ctrl+b ctrl+b` sends a literal `ctrl+b`.

Opening the same `.code-workspace` again normally makes VS Code focus its existing window. Duplicate-window handling beyond VS Code's native workspace behavior is deliberately deferred.

## Terminal title

The generated workspace sets the terminal title to `Herdr/<space-name>/<tab-ordinal>`, for example `Herdr/pippo/10`.

The task is automatically allowed only inside this generated workspace. VS Code still requires the project to be trusted before automatic tasks can run.

## Check

```sh
bash tests/test.sh
```
