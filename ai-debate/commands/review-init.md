---
description: Scaffold the ai_debate workflow (folders, scripts, templates, rules) into the current repository
argument-hint: "[target-dir, default llm_wiki/ai_debate]"
---

Bootstrap the **ai_debate** adversarial-review workflow into the current repository in one shot.

Target directory: `$1` if provided, otherwise `llm_wiki/ai_debate`.

Do the following:

1. Create the target directory and a `_templates/` subdirectory.
2. Copy these files from the plugin into the target directory (use absolute source paths under `${CLAUDE_PLUGIN_ROOT}/scripts/`):
   - `run_auto.ps1`, `wait_for_review.ps1`, `update_status.ps1`, `scan_queue.ps1` → target root
   - `templates/status.schema.md`, `templates/status.template.json`, `templates/topic.template.md` → `_templates/`
   - `templates/rules.md` → target `README.md` (the operating rules)
3. If `index.md` does not exist in the target, create one with a header and an empty "Recent Additions" table (columns: Status, Topic, Folder, Current Doc, Next Request).
4. Append a short "ai_debate workflow" section to the repository root `CLAUDE.md` (create it if absent) that references the target `README.md` as the source of truth and states the HARD RULE: agents never write another agent's review round on its behalf; when `status.json` shows `owner=<other agent>`, stop and report.
5. Add `*/run_auto.log.jsonl` and `*/status.json.tmp` to the repo `.gitignore` (ai_debate runtime artifacts).
6. Print a summary of what was created and the next step: `/review-new <slug>` to open the first topic.

Do not modify any source/trading code. This command only scaffolds documentation and tooling.
