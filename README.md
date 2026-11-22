# cc-wsl-handoff

A Claude skill plus helper scripts for delegating builds from a Claude Desktop chat to headless
Claude Code in WSL, without polling. The Desktop chat launches the run, goes idle, and is woken by
a signal the moment the run stops.

## How it works

1. The chat schedules a one-shot wake-up for itself (`send_later`) with a long fallback delay.
2. `cc-run` starts `claude -p` detached in WSL (`setsid -f`, so it survives the bridge shell closing).
3. When Claude Code exits for any reason, `cc-run-inner` writes `.cc/status.json`
   (`done` / `error`, turns, cost, final summary) and then fires the wake-up early through Claude
   Code's `RemoteTrigger` tool, with no text.
4. The chat wakes within about a minute and reads only `status.json`. If there are questions, it
   answers them and resumes the same session.

This costs about one chat step per run instead of one per polling interval.

## Install

In WSL:

```sh
git clone https://github.com/0xJonty/cc-wsl-handoff.git
cd cc-wsl-handoff && ./install.sh      # copies bin/cc-* to ~/bin
```

Then add `SKILL.md` as a skill in Claude.

## Agent install

Paste this into your coding agent (for example Claude Code running in WSL) and let it do the setup:

```text
Install the cc-wsl-handoff skill and scripts from https://github.com/0xJonty/cc-wsl-handoff.

1. Check prerequisites in WSL2 and report anything missing:
   - `claude --version` works and Claude Code is signed in to the same Claude account I use in Claude Desktop.
   - `python3`, `uuidgen`, `setsid` and `realpath` exist. If any are missing, give me the exact `sudo apt install -y python3 uuid-runtime util-linux coreutils` line to run myself. Do not run sudo.
2. Clone the repo inside WSL and run `./install.sh`. Confirm ~/bin/cc-run, cc-run-inner, cc-status and cc-tail exist and are executable.
3. Verify headless auto mode works: in a new empty folder, run
   `claude -p "Create ok.txt containing ok, then reply done" --model claude-sonnet-5 --permission-mode auto`
   and confirm ok.txt was written. If it is refused, tell me auto mode is unavailable on this plan or setup.
4. Check the Windows side: claude_desktop_config.json (usually %APPDATA%\Claude\, or search %LOCALAPPDATA%) must have an MCP server that runs WSL commands. If none exists, install one: on Windows run `npm i -g mcp-wsl-exec`, back up the config, and MERGE (never overwrite other servers) an entry like
   "wsl-exec": { "command": "node", "args": ["<npm global root>\\mcp-wsl-exec\\dist\\index.js"] }
   using `npm root -g` for the real path.
5. Install the skill:
   - For Claude Code: copy SKILL.md to ~/.claude/skills/cc-wsl-handoff/SKILL.md.
   - For Claude Desktop/claude.ai: you can't upload it yourself. Tell me to add SKILL.md under Settings > Capabilities > Skills (or ask Claude in a chat to save it as a skill).
6. Tell me to restart Claude Desktop if the config changed. Then suggest a first test from a Desktop chat: "Use cc-wsl-handoff to have Claude Code create hello.txt in ~/cc-handoff-test." The chat should wake by itself within about a minute.

Rules: never run sudo; never print tokens or credentials; back up any config file before editing it.
```

## Requirements

**Windows side**
- Windows 10/11 with WSL2 (tested on Ubuntu 24.04)
- Claude Desktop app, with this chat linked to the computer (device bridge)
- A WSL command MCP server registered in Claude Desktop, e.g. [`mcp-wsl-exec`](https://www.npmjs.com/package/mcp-wsl-exec), which needs Node.js on Windows
- A Claude chat with the `send_later` scheduling tool (the scheduled-tasks feature)

**WSL side**
- Claude Code CLI (tested on 2.1.330), signed in to the **same Claude account** as the Desktop chat, with:
  - auto mode available on your plan (`--permission-mode auto`)
  - the `RemoteTrigger` tool
  - access to `claude-sonnet-5` (used to fire the wake-up)
- `bash`, `python3` (3.8+), `uuidgen` (`uuid-runtime`), `setsid` and `realpath` (`util-linux` and `coreutils`, both preinstalled on Ubuntu)
- Optional: `nvm`. The runner sources `~/.nvm/nvm.sh` if it exists and adds `~/.local/bin` to `PATH`, so `claude` and Node can be found in non-interactive shells
- Optional: `git` and `gh` to clone this repo

On Ubuntu, install anything missing with:

```sh
sudo apt install -y python3 uuid-runtime util-linux coreutils
```

## Scripts

| Script | Purpose |
|---|---|
| `cc-run <dir> <uuid> <prompt-file> <new\|resume> [trigger-id] [model] [effort]` | Start a detached run and confirm it started |
| `cc-run-inner` | Runs Claude Code, writes `status.json`, fires the wake-up |
| `cc-status <log> <exit>` | Summarises a stream-json log into `status.json` |
| `cc-tail [log] [n]` | Compact view of a run log, for debugging |

Runs use `--permission-mode auto` and `disableClaudeAiConnectors: true` (keeps the per-step context small).
Model and effort are optional; pass `""` or omit them to use your Claude Code defaults.

Before building, the skill asks about anything the request leaves open: Git/GitHub (repo name, visibility,
commit cadence), model and effort, project location, and done criteria and limits.

## Gotchas

- **Don't use Haiku:** auto mode doesn't apply to it, so its file writes and the trigger fire are refused.
- **The fire must carry no text:** session-bound wake-ups reject extra text (`caller_text_resume_only`).
- **Each wake-up fires once.** Create a new one for every launch or resume.
- **Keep the fallback delay generous** in case the machine sleeps or the fire fails.

## Licence

MIT
