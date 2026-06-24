---
description: Scaffold the ai_debate workflow (folders, scripts, templates, rules) into the current project (git or non-git)
argument-hint: "[target-dir, default llm_wiki/ai_debate]"
---

Bootstrap the **ai_debate** adversarial-review workflow into the current project in one shot. Works in **both git and non-git** projects — git-only steps (`.gitignore`) are skipped automatically when no git repo is present.

Target directory: `$1` if provided, otherwise `llm_wiki/ai_debate`.

Do the following:

1. Create the target directory and a `_templates/` subdirectory.
2. Copy these files from the plugin into the target directory (use absolute source paths under `${CLAUDE_PLUGIN_ROOT}/scripts/`):
   - `run_auto.ps1`, `wait_for_review.ps1`, `update_status.ps1`, `scan_queue.ps1` → target root
   - `templates/status.schema.md`, `templates/status.template.json`, `templates/topic.template.md` → `_templates/`
   - `templates/rules.md` → target `README.md` (the operating rules)
3. If `index.md` does not exist in the target, create one with a header and an empty "Recent Additions" table (columns: Status, Topic, Folder, Current Doc, Next Request).
4. Append a short "ai_debate workflow" section to the project root `CLAUDE.md` (create it if absent) that references the target `README.md` as the source of truth and states: (a) the HARD RULE — agents never write another agent's review round on its behalf; when `status.json` shows `owner=<other agent>`, stop and report; and (b) the default mode — topics scaffold with `auto=true`, so the coordinator drives the debate to `decision.md` autonomously; human approval is only required for code changes (`allow_code_change=true`).
5. **Git only** — if a git repo is present (a `.git` directory exists at the project root, or `git rev-parse --is-inside-work-tree` succeeds), add `*/run_auto.log.jsonl` and `*/status.json.tmp` to the project `.gitignore` (ai_debate runtime artifacts). If the project is **not** a git repo, skip this step and note "non-git project: skipped .gitignore (runtime artifacts are local files)".
6. Print a summary of what was created (including whether git mode was detected) and the next step: `/review-new <slug>` to open the first topic, then `/review-run --watch` to let the agents run the debate to completion.

Do not modify any source/trading code. This command only scaffolds documentation and tooling.
