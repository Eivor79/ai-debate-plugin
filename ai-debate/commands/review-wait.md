---
description: Wait (in background) for a review to complete, then auto-resume this session to continue the next step
argument-hint: "<topic-folder> [--until-owner X | --until-status PATTERN | --until-doc GLOB]"
---

Block-then-auto-resume on a ai_debate review.

Arguments: `$ARGUMENTS` — first token is the topic folder (name or path). Optional completion condition:
- `--until-owner <owner>` → `wait_for_review.ps1 -UntilOwner <owner>` (e.g. wait until it's your turn: `claude`)
- `--until-status <pattern>` → `-UntilStatusLike <pattern>` (e.g. `decided`, `ready_for_claude*`)
- `--until-doc <glob>` → `-UntilDocExists <glob>` (e.g. `002_*.md`)
- none → exit when the topic's owner/status/current_doc changes from now

Steps:

1. Resolve the ai_debate root (directory containing `wait_for_review.ps1`; default `llm_wiki/ai_debate`).
2. Launch `wait_for_review.ps1` with the parsed args **using `run_in_background`** so the session spends no tokens while waiting. The watcher exits when the review advances, and the harness re-invokes this session.
3. When re-invoked (the background task completes), read the watcher's output (the JSON line + `NEXT:` hint), then continue automatically based on the result:
   - `owner` is your agent (e.g. `claude`) and status actionable → read the `latest_doc` and write the next round / implement.
   - `status=decided` and `allow_code_change=true` → proceed to implementation within the decision scope.
   - `owner=human` or `blocked` → stop and report to the user that human approval/attention is required (do not auto-implement).

This is the recommended way to chain an async review into the next step without manual polling.
