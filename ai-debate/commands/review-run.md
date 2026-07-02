---
description: Start the ai_debate coordinator (run_auto.ps1) that drives Claude/Codex review rounds
argument-hint: "[--watch] [extra run_auto.ps1 flags]"
---

Start the ai_debate coordinator for the current repository.

Resolve the ai_debate root (directory containing `run_auto.ps1`; default `llm_wiki/ai_debate`).

Run the coordinator with the user's flags: `$ARGUMENTS` (pass through to `run_auto.ps1`). Common forms:
- `/review-run --watch` → `run_auto.ps1 -Watch` (unattended loop until stopped)
- `/review-run` → single pass (process the top actionable item once)

Notes to honor:
- The coordinator invokes the local `claude` and `codex` CLIs as separate processes based on each topic's `status.json` `owner`. It only acts on topics with an actionable status and (`auto=true` or `-EnableExisting`). Since new topics default to `auto=true`, this single command drives each topic's debate all the way to `decision.md` autonomously.
- Works in git and non-git projects: the project root is resolved from `git rev-parse --show-toplevel` when git is available, else the workspace parent. Pass `-RepoRoot <path>` to override for unusual layouts.
- On macOS/Linux, launch with PowerShell 7: `pwsh <workspace>/run_auto.ps1 ...` (check `pwsh` exists first; if missing, tell the user to install PowerShell 7 via brew/apt). On Windows either `powershell` or `pwsh` works.
- It is resilient: a per-topic timeout or error blocks that topic (`owner=human`) and the loop continues; a single-instance mutex prevents double-runs.
- For unattended runs, consider `-WatchMaxActions <N>` as a safety cap and `-ClaudeModel`/`-CodexModel` to pin models for review-quality parity.
- Do NOT pass flags that change trading/order code. The coordinator is for document review rounds; code changes require `allow_code_change=true` + a finalized `decision.md` + human approval.

Launch it (use `run_in_background` if `-Watch` so the session is not blocked), then report the coordinator status.
