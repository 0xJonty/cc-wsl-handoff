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

## Requirements

- Claude Desktop linked to a chat with the device bridge and a WSL command tool (e.g. `wsl-exec`)
- A chat with the `send_later` scheduling tool
- Claude Code in WSL, signed in to the same account, with auto mode available and the `RemoteTrigger` tool
- `python3`, `uuidgen`, `nvm`-installed Node (the runner sources `~/.nvm/nvm.sh`)

## Scripts

| Script | Purpose |
|---|---|
| `cc-run <dir> <uuid> <prompt-file> <new\|resume> [trigger-id] [model]` | Start a detached run and confirm it started |
| `cc-run-inner` | Runs Claude Code, writes `status.json`, fires the wake-up |
| `cc-status <log> <exit>` | Summarises a stream-json log into `status.json` |
| `cc-tail [log] [n]` | Compact view of a run log, for debugging |

Runs use `--permission-mode auto`, `effortLevel: high` and `disableClaudeAiConnectors: true` to keep
the per-step context small.

## Gotchas

- **Don't use Haiku:** auto mode doesn't apply to it, so its file writes and the trigger fire are refused.
- **The fire must carry no text:** session-bound wake-ups reject extra text (`caller_text_resume_only`).
- **Each wake-up fires once.** Create a new one for every launch or resume.
- **Keep the fallback delay generous** in case the machine sleeps or the fire fails.

## Licence

MIT
