# AGENTS.md

## Purpose

This repository is a macOS-only Herdr plugin. From the focused Herdr pane, its `open` action opens the pane's live working directory in VS Code and connects a VS Code integrated terminal to the exact existing Herdr terminal session.

The intended result is continuity, not a copy:

- Pi/agent panes and plain shell panes both work.
- The process already running in Herdr remains the process controlled from VS Code.
- VS Code shows the terminal session, not the full Herdr UI and not a new shell.
- Reopening the same generated workspace should rely on VS Code's native window reuse behavior.

The user's keybinding is configured outside this repository as `prefix+i` → `herdr.vscode.open`.

## Product constraints

Preserve these unless the user explicitly changes the requirements:

- Do not require a VS Code extension.
- Do not use AppleScript, Accessibility, simulated input, or other UI automation.
- Do not write `.vscode`, task, or workspace files into the opened project.
- Do not close, replace, or repurpose unrelated VS Code windows.
- Do not turn the attach into a fresh shell.
- Do not depend on agent-specific APIs; use the pane's `terminal_id` so plain terminals work too.
- Do not force the VS Code Panel or Terminal to the right. Layout experiments were deliberately dropped.
- Keep VS Code's terminal-tabs column disabled in the generated workspace with `terminal.integrated.tabs.enabled: false`; the compact terminal selector remains available.

## Runtime flow

1. Herdr invokes `scripts/open-vscode-terminal.sh` with plugin context environment variables.
2. The launcher calls `herdr api snapshot`.
3. It finds `HERDR_PANE_ID`, then resolves:
   - `terminal_id`;
   - `foreground_cwd`, falling back to `cwd`;
   - workspace label;
   - one-based tab ordinal.
4. It writes a generated workspace to:

   ```text
   $HERDR_PLUGIN_STATE_DIR/<pane-id>-v2.code-workspace
   ```

5. It opens that file with:

   ```sh
   code --new-window <generated-workspace>
   ```

6. The workspace's `folderOpen` task reveals and focuses a dedicated integrated terminal and runs `scripts/attach.sh`.
7. `attach.sh` executes:

   ```sh
   herdr terminal attach <terminal_id> --takeover
   ```

The stable workspace path is intentional: VS Code can recognize an already-open pane-specific workspace. The generated file is persistent plugin state, is safe to delete while its VS Code window is closed, and must never be written inside the user's project.

## Important implementation details

### Preserve terminal stdin

`attach.sh` must leave stdin connected to the VS Code PTY. Do not feed Python source through a heredoc such as:

```sh
python3 - <<'PY'
```

That consumes stdin and produces a read-only-looking attachment: output updates, but typed keys never reach Herdr. Keep the current `python3 -c` approach and `/dev/tty` reconnection.

### Python has no third-party dependencies

The project is orchestrated by Bash. Python is used because Bash has no safe native JSON parser and the launcher must parse a snapshot and generate valid JSON without quoting bugs.

Only standard-library modules are used: `base64`, `json`, `os`, `pathlib`, and `sys`. Do not add `pip`, a virtual environment, or Python packages. If Python is removed, use an equally reliable JSON solution rather than parsing JSON with `grep` or shell word splitting.

### Generated task

Keep the task as a shell task with:

- `runOn: folderOpen`;
- automatic-task permission scoped to the generated workspace;
- `presentation.reveal: always`;
- `presentation.focus: true`;
- `presentation.panel: dedicated`;
- `instanceLimit: 1`.

Here `panel: dedicated` means a terminal dedicated to this task; it does not control whether VS Code's Panel is left, right, or bottom.

### Titles and attachment

The terminal title format is intentionally compact:

```text
Herdr/<workspace-label>/<tab-ordinal>
```

Keep `--takeover`: it replaces a previous direct-attach owner for that terminal. It does not replace the ordinary Herdr UI client.

Herdr direct-attach controls:

- detach: `ctrl+b q`;
- send literal prefix: `ctrl+b ctrl+b`.

## Repository map

- `herdr-plugin.toml` — plugin manifest and `open` action.
- `scripts/open-vscode-terminal.sh` — snapshot lookup, generated workspace, and VS Code launch.
- `scripts/attach.sh` — payload decoding and interactive Herdr attachment.
- `tests/test.sh` — dependency-free integration-style check using fake `herdr` and `code` commands.
- `README.md` — installation and user-facing behavior.

## Dependencies

Runtime requirements:

- macOS;
- Herdr `>= 0.9.0`;
- the VS Code `code` command on `PATH`;
- Python 3 using only its standard library.

Do not add a dependency for something already covered by Bash, Python's standard library, Herdr, or VS Code.

## Validation

Run before every commit:

```sh
bash -n scripts/*.sh tests/test.sh
bash tests/test.sh
git diff --check
```

For a manual check:

1. Focus an active Herdr pane.
2. Press `prefix+i`.
3. Confirm VS Code opens at the pane's live directory.
4. Confirm the integrated terminal displays the existing session.
5. Type in VS Code and confirm input reaches that same Pi/shell process.
6. Invoke `prefix+i` again and confirm VS Code focuses/reuses the associated workspace rather than an unrelated window.

Useful diagnostics:

```sh
herdr config check
herdr plugin log list --plugin herdr.vscode --limit 10
```

## Deferred behavior

Do not add these speculatively:

- exact sidebar/panel placement or widths;
- VS Code profile management;
- UI automation;
- a VS Code extension;
- custom duplicate-window management beyond VS Code's native workspace behavior.

Implement them only after an explicit requirement and keep unrelated VS Code windows unaffected.
