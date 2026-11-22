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
0. **Clarify before building.** Check the request for each item below. Ask only about the ones it doesn't settle, in a single AskUserQuestion call (up to 4 questions, with the recommended option first), before writing any spec or launching anything. If the user isn't there to answer (scheduled or unattended), use the defaults shown and state them at the top of the spec.
   - **Git / GitHub:**
     - Local git only, or a GitHub repo too?
     - If GitHub: the repo name, public or private, and the owner (default: the signed-in `gh` account).
     - When to commit and push: after each working milestone, or only at the end?
     - Default: local git, commit at milestones, no GitHub. Only push to a public repo if the user said public in so many words.
   - **Model and effort:**
     - Which model: Sonnet 5 (recommended for implementation), Opus (hard research or design), or the Claude Code default from settings.json.
     - Which effort: low, medium, high or xhigh, or the default.
     - Default: Claude Code's defaults.
   - **Location:** a new folder (and its name under `~/build/`) or an existing project path. Default: a new `~/build/<slug>`.
   - **Done criteria and limits:**
     - What counts as finished (tests passing, a smoke test, a deploy).
     - Which live or external actions are allowed: real accounts, sending, posting, deploys, sudo.
     - Which secrets or logins the build needs.
     - Any cost or time cap.
     - Default: tests plus a local smoke test, no live writes, no sudo.
   Put every answer into SPEC.md and the task prompt, so the headless run has them and never has to ask.
1. **Prepare.** Pick or create the project folder in WSL. For anything non-trivial, write a SPEC.md and a short project CLAUDE.md first. Write the task prompt to `<dir>/.cc/<name>.txt`. Make it self-contained: say the run is headless with no human, that it should make reasonable decisions and log them in DECISIONS.md, and that it must end with a status of done / next / blockers / questions.
2. **Model and effort.** Use what step 0 settled. Pass an empty string to use the Claude Code defaults. Do not use Haiku: auto mode does not apply to it, so its file writes get denied. If the user picks Haiku, explain this and suggest Sonnet 5.
3. **Schedule the wake-up.** Call `send_later` with `delay_minutes` set to about 2× the expected run time plus 10, as a fallback only. The message must name the folder and say: "read only <dir>/.cc/status.json". Keep the returned `trigger_id`.
4. **Launch.** Run `~/bin/cc-run <dir> <uuid> <prompt-file> new <trigger_id> "<model>" "<effort>"`, using `uuidgen` for the uuid and keeping it for resumes. Pass `""` for either to use the default. It must print `started sid ...`; if it prints FAILED, show the runner.log lines.
5. **Go idle.** Tell the user in one line what's running and that you'll wake when it stops. End the turn. Do not poll.
6. **On wake.** Call ReadNotifications. Then delete this wake-up with `delete_trigger(<trigger_id>)`: an early fire does not cancel its fallback time, so it would go off again later. If the notification was the fallback itself, deleting it is harmless. Then read only `<dir>/.cc/status.json`. If the fallback fired, also read `.cc/wake.log`.
   - `running`: the fallback fired before the run finished. Schedule a new `send_later` with a new fallback time. Re-point the running build at it by writing the new id to `<dir>/.cc/wake-trigger` (`printf %s <new trigger_id> > <dir>/.cc/wake-trigger`); the build reads this file when it exits. Go idle.
   - `done` with no open questions: review the `result` text, spot-check specific files only if needed, and report to the user. No new wake-up is needed.
   - `done` with questions or blockers: write the answers to a new prompt file, schedule a new `send_later`, and run `cc-run <dir> <same uuid> <answers-file> resume <new trigger_id> "<model>" "<effort>"`. Go idle.
   - `error`: run `~/bin/cc-tail <dir>/.cc/latest.jsonl 10` and decide whether to fix and resume or report. A resume gets a new `send_later` with a new fallback time, the same as for questions.
7. After 3 resume loops without finishing, stop and check with the user.

## Rules
- Git and GitHub steps go in the task prompt: when to commit, and whether to `gh repo create` and push (with name and visibility). Never let the headless run decide to make anything public.
- Each wake-up fires only once. Make a new one for every launch or resume, and delete the previous one on every wake, so a stale fallback never goes off after the job is finished.
- The wake fire carries no text; extra text is rejected. The status file carries the information.
- Keep `wsl-exec` commands short. Commands containing `>`, `rm`, `mv` and similar need a confirmation call, which echoes the whole command back.
- Bridge calls time out at about 80s, so never `sleep` longer than about 70s in one call.
- Prefer launching from a fresh chat so each wake re-reads less context.
- Live writes to external accounts (posting, sending, creating real records) need the user's go-ahead in the prompt. Don't let the headless run decide those.
