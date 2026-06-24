---
description: Create a new ai_debate topic folder (topic.md + status.json) from templates
argument-hint: "<slug> [priority p0|p1|p2|p3]"
---

Create a new ai_debate topic.

Arguments: `$ARGUMENTS` — first token is the topic `<slug>` (kebab-case), optional second token is priority (default `p2`). Optional flag `--manual` (or `--no-auto`) opts out of autonomous mode.

Steps:

1. Resolve the ai_debate root (the directory containing `run_auto.ps1`; default `llm_wiki/ai_debate`).
2. Compute today's date as `YYYY-MM-DD` and create folder `<date>_<slug>/`.
3. Create `topic.md` from `_templates/topic.template.md` (fill in title, date, priority, a Background section to be completed).
4. Create `status.json` from `_templates/status.template.json`. **Default = autonomous**: the agents run the full debate (design → attack → rebuttal → decision) on their own once the coordinator is started. Set:
   - `owner`: the designer agent (default `claude`), `status`: `ready_for_claude` (actionable so the coordinator picks it up), `next_action`: `design`,
   - `current_doc`: `topic.md`, `next_doc`: `001_claude_design.md`,
   - `auto`: **true** (so `/review-run` drives it to `decision.md` without per-round human toggling), `allow_code_change`: false, `priority`: the chosen priority, `updated_at`: today.
   - If `--manual` / `--no-auto` was passed, instead set `auto`: false and `owner`: `human` (classic per-round human-gated review).
5. Add a row to `index.md`.
6. Report the created paths and the mode (autonomous vs manual). For autonomous, remind: run `/review-run --watch` and the agents will debate to `decision.md` by themselves; you are only asked to approve **code changes** (`allow_code_change=true`) afterward. For manual, remind to write `001_*_design.md` then hand off.

Follow the rules in the ai_debate `README.md`. Do not call any `codex:*` skill to write another agent's round.
