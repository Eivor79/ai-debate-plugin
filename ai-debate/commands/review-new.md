---
description: Create a new ai_debate topic folder (topic.md + status.json) from templates
argument-hint: "<slug> [priority p0|p1|p2|p3]"
---

Create a new ai_debate topic.

Arguments: `$ARGUMENTS` — first token is the topic `<slug>` (kebab-case), optional second token is priority (default `p2`).

Steps:

1. Resolve the ai_debate root (the directory containing `run_auto.ps1`; default `llm_wiki/ai_debate`).
2. Compute today's date as `YYYY-MM-DD` and create folder `<date>_<slug>/`.
3. Create `topic.md` from `_templates/topic.template.md` (fill in title, date, priority, a Background section to be completed).
4. Create `status.json` from `_templates/status.template.json` with:
   - `status`: `design_review_pending`, `owner`: the author agent (usually `claude`), `next_action`: `write_design`,
   - `current_doc`: `topic.md`, `next_doc`: `001_<author>_design.md`,
   - `auto`: false, `allow_code_change`: false, `priority`: the chosen priority, `updated_at`: today.
5. Add a row to `index.md`.
6. Report the created paths and remind: write `001_*_design.md`, then hand off (set `owner`/`status`) for adversarial review.

Follow the rules in the ai_debate `README.md`. Do not call any `codex:*` skill to write another agent's round.
