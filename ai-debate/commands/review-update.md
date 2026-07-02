---
description: Sync an existing ai_debate workspace's scripts/templates to the installed plugin version
argument-hint: "[target-dir, default llm_wiki/ai_debate] [--with-rules]"
---

Re-sync an ai_debate workspace that was scaffolded by an older plugin version. `/review-init` **copies** scripts into the project, so they go stale when the plugin updates — this command refreshes them.

Target directory: `$1` if provided, otherwise the directory containing `run_auto.ps1` (default `llm_wiki/ai_debate`). If no workspace is found, stop and suggest `/review-init` instead.

Do the following:

1. For each runtime script — `run_auto.ps1`, `wait_for_review.ps1`, `update_status.ps1`, `scan_queue.ps1` — compare the workspace copy against `${CLAUDE_PLUGIN_ROOT}/scripts/<name>` (content comparison, e.g. hash). Overwrite the workspace copy only when it differs.
2. Same for templates into `_templates/`: `status.schema.md`, `status.template.json`, `topic.template.md`, `findings.schema.md` (copy any that are missing, overwrite any that differ).
3. **Rules are preserved by default**: do NOT touch the workspace `README.md` (users may have customized their operating rules). Only if `--with-rules` was passed, overwrite it with `${CLAUDE_PLUGIN_ROOT}/scripts/templates/rules.md`.
4. NEVER touch topic folders, `status.json` files, `index.md`, or `run_auto.log.jsonl`. This command updates tooling only.
5. Report a summary table: file → `updated` / `unchanged` / `added` (and `skipped (use --with-rules)` for README.md when it differs).
6. If any file was updated, remind the user: a running coordinator (`run_auto.ps1 -Watch`) keeps executing the OLD script — stop it and restart `/review-run` to pick up the new version.

Do not modify any source/trading code. This command only refreshes the workflow tooling.
