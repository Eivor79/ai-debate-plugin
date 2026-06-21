---
description: Show the ai_debate queue — actionable, blocked, and human-pending topics, plus recent coordinator activity
argument-hint: "[topic-folder for detail]"
---

Summarize the current ai_debate state for the repository.

Resolve the ai_debate root (directory containing `run_auto.ps1`; default `llm_wiki/ai_debate`).

If a topic folder is given (`$1`), show its detail: `status.json` fields, the document list, and the latest numbered doc / `decision.md`.

Otherwise, scan every `<topic>/status.json` and report a compact table:
- topic, priority, status, owner, actionable (owner is an automated agent + actionable status + not blocked + not locked), `blocked_reason`/`next_action`.
- Group by: **needs human** (`owner=human` or non-empty `blocked_reason`), **in flight** (owner=claude/codex), **idle/decided**.

Then tail the last ~15 lines of `run_auto.log.jsonl` (if present) and summarize recent results (ok / timeout / nonzero / no_progress / doc_without_state / human_handoff / turn_error) with topic and duration.

Highlight anything that needs the user's attention first (human-pending or blocked topics).
