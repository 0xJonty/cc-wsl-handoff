---
name: cc-wsl-handoff
description: Hand a build or coding task to headless Claude Code in WSL, stay idle while it runs, and wake on a signal when it stops. Use for any multi-step build delegated from a Desktop chat.
---

# cc-wsl-handoff

Run a task with headless Claude Code in the user's WSL and stay idle while it works. When the run stops for any reason, it fires a one-shot wake-up into this chat. Never poll the log: each check re-reads the whole chat and burns usage.

## Requirements
- `wsl-exec` (device bridge) and the `send_later` scheduling tool in this chat.
- WSL scripts `~/bin/cc-run`, `~/bin/cc-run-inner`, `~/bin/cc-status`, `~/bin/cc-tail` (installed by this repo's `install.sh`). If any are missing, stop and tell the user.
- WSL Claude Code with auto mode and the `RemoteTrigger` tool.

## Procedure
1. **Prepare.** Pick or create the project folder in WSL. For anything non-trivial, write a SPEC.md and a short project CLAUDE.md first. Write the task prompt to `<dir>/.cc/<name>.txt`. Make it self-contained: say the run is headless with no human, that it should make reasonable decisions and log them in DECISIONS.md, and that it must end with a status of done / next / blockers / questions.
2. **Choose a model.** Use `claude-sonnet-5` for implementation and Opus for hard research or design. Do not use Haiku: auto mode does not apply to it, so its file writes get denied.
3. **Schedule the wake-up.** Call `send_later` with `delay_minutes` set to about 2× the expected run time plus 10, as a fallback only. The message must name the folder and say: "read only <dir>/.cc/status.json". Keep the returned `trigger_id`.
4. **Launch.** Run `~/bin/cc-run <dir> <uuid> <prompt-file> new <trigger_id> <model>`, using `uuidgen` for the uuid and keeping it for resumes. It must print `started sid ...`; if it prints FAILED, show the runner.log lines.
5. **Go idle.** Tell the user in one line what's running and that you'll wake when it stops. End the turn. Do not poll.
6. **On wake.** Call ReadNotifications, then read only `<dir>/.cc/status.json`. If the fallback fired, also read `.cc/wake.log`.
   - `running`: the fallback fired before the run finished. Schedule a new `send_later` and go idle again.
   - `done` with no open questions: review the `result` text, spot-check specific files only if needed, and report to the user.
   - `done` with questions or blockers: write the answers to a new prompt file, schedule a new `send_later`, and run `cc-run <dir> <same uuid> <answers-file> resume <new trigger_id> <model>`. Go idle.
   - `error`: run `~/bin/cc-tail <dir>/.cc/latest.jsonl 10` and decide whether to fix and resume or report.
7. After 3 resume loops without finishing, stop and check with the user.

## Rules
- Each wake-up fires only once. Make a new one for every launch or resume.
- The wake fire carries no text; extra text is rejected. The status file carries the information.
- Keep `wsl-exec` commands short. Commands containing `>`, `rm`, `mv` and similar need a confirmation call, which echoes the whole command back.
- Bridge calls time out at about 80s, so never `sleep` longer than about 70s in one call.
- Prefer launching from a fresh chat so each wake re-reads less context.
- Live writes to external accounts (posting, sending, creating real records) need the user's go-ahead in the prompt. Don't let the headless run decide those.
