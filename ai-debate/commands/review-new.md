---
description: Open a debate topic and let the agents run it to a decision — scaffolds, creates, starts the coordinator, waits, and reports the verdict in one shot
argument-hint: "<slug-or-phrase> [priority p0|p1|p2|p3] [--rounds N] [--manual] [--no-run]"
---

One-shot entry point: after this command the user does **nothing** until the verdict is ready.

Arguments: `$ARGUMENTS` — first token(s) form the topic (kebab-case slug, or a natural-language phrase you convert to one). Optional: priority (default `p2`), `--rounds N` (round budget: 1 round = 1 numbered doc; sets `max_rounds: N`, after which a JUDGE verdict is forced — also use this when the user says "N라운드로"), `--manual` (per-round human review, no auto-run), `--no-run` (create only, do not start the coordinator).

Steps:

1. **Scaffold if missing**: resolve the workspace (directory containing `run_auto.ps1`, default `llm_wiki/ai_debate`). If none exists, scaffold it now: create the workspace + `_templates/`, copy scripts (`run_auto.ps1`, `wait_for_review.ps1`, `update_status.ps1`, `scan_queue.ps1`) and templates from `${CLAUDE_PLUGIN_ROOT}/scripts/`, copy `templates/rules.md` → workspace `README.md`, create `index.md`, and (git repos only) add `*/run_auto.log.jsonl` + `*/status.json.tmp` to `.gitignore`.
2. **Create the topic in one shot**: folder `<YYYY-MM-DD>_<slug>/`. Write `topic.md` from `_templates/topic.template.md`, filling the background/problem/competing-options **yourself from conversation context** — do not interrogate the user (one clarifying question max, only if genuinely ambiguous).
3. **status.json** from `_templates/status.template.json`: `owner=claude`, `status=ready_for_claude`, `next_action=design`, `next_doc=001_claude_design.md`, `auto=true`, `allow_code_change=false`, `priority`, `updated_at=today`, `max_rounds` = N from `--rounds` (0/absent = coordinator default 7). With `--manual`: `auto=false`, `owner=human`.
4. Add a row to `index.md`.
5. **Start the debate** (skip if `--manual` or `--no-run`): launch the coordinator in the background — `run_auto.ps1 -Watch` (`pwsh` on macOS/Linux, `powershell` on Windows), using `run_in_background`. The single-instance mutex makes this safe to attempt even if one is already running (the duplicate exits immediately).
6. **Wait hands-free** (skip if `--manual`/`--no-run`): launch `wait_for_review.ps1 <topic> -UntilStatusLike decided*` with `run_in_background`. When it completes, read `decision.md` and **report the verdict**: adopted findings, the ruling, residual risks, next step. If the watcher reports `owner=human`/`blocked_reason` instead, report what needs the user's attention.
7. Remind: code changes still require `decision.md` + `allow_code_change=true` + the user's approval.

Follow the workspace `README.md` rules. Never call `codex:*` skills to write another agent's round.
