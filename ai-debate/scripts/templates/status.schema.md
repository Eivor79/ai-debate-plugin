# Review Bus status.json Schema

## Required

- `status`: `draft`, `ready_for_claude`, `ready_for_codex`, `ready_for_<owner>_*`, `ready_for_decision`, `ready_for_implementation`, `blocked`, `done`
- `owner`: `codex`, `claude`, `human`, `none`
- `next_action`: `design`, `review`, `rebuttal`, `decision`, `implementation_plan`, `implementation`, `verify`, `none`
- `current_doc`: latest document in the topic folder
- `auto`: boolean
- `allow_code_change`: boolean
- `updated_at`: `YYYY-MM-DD`

## Optional

- `priority`: `low`, `normal`, `high`, `urgent`
- `max_rounds`: integer round budget for this topic — 1 round = 1 numbered doc (`NNN_*.md`); at the cap the coordinator forces a JUDGE round that writes `decision.md`. `0`/absent = coordinator default (`-MaxNumberedDocs`, 7). Re-read every poll, so changing it on a running topic applies on the next turn.
- `next_doc`: expected next document filename
- `lock_owner`: current worker id
- `lock_until`: ISO timestamp
- `touches_paths`: paths allowed for code changes
- `blocked_reason`: reason when `status=blocked`
- `notes`: free-form short note
- `upgrade_doc`: promoted upgrade design path when `decision.md` creates a system design
- `upgrade_doc_status`: `none`, `needed`, `created`, `skipped`

## Safety Rules

- Codex may auto-write docs only when `auto=true`, `owner=codex`, and status is actionable.
- `run_auto.ps1` may invoke either local CLI when `auto=true`, `owner` is `claude` or `codex`, and status is `ready_for_<owner>*`, `ready_for_decision`, or `ready_for_implementation`.
- `run_auto.ps1 -EnableExisting` lets the coordinator act on an eligible topic whose `auto` is `false`, **for that run only**. It does NOT persist `auto=true` to `status.json` — the override is session-scoped, so the topic stays `auto=false` on disk and will not be auto-processed by a later unattended run.
- Codex may edit code only when `allow_code_change=true`, `touches_paths` is non-empty, and a decision document exists.
- Trading/order/account paths require explicit human approval even when `allow_code_change=true`.
