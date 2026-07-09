---
description: Preflight check for the ai_debate workflow — CLIs, platform, workspace freshness; --fix re-syncs stale scripts
argument-hint: "[target-dir, default llm_wiki/ai_debate] [--fix]"
---

Diagnose why the ai_debate workflow might not run, and (with `--fix`) repair what can be repaired automatically.

Target: `$1` if provided, else the directory containing `run_auto.ps1` (default `llm_wiki/ai_debate`).

Check and report each item as OK / WARN / FAIL with a one-line remedy:

1. **PowerShell engine** — on Windows: `powershell` or `pwsh` available (OK either way). On macOS/Linux: `pwsh` must exist; if missing → FAIL with install hint (`brew install --cask powershell` / `apt-get install powershell`).
2. **claude CLI** on PATH — required. FAIL if missing.
3. **codex CLI** on PATH — optional: if missing → WARN "solo fallback active: claude executes codex rounds (provenance-marked)".
4. **Workspace** — exists? If not → FAIL, remedy: `/review-new <topic>` scaffolds automatically.
5. **Workspace freshness** — compare each workspace script (`run_auto.ps1`, `wait_for_review.ps1`, `update_status.ps1`, `scan_queue.ps1`) and `_templates/*` against `${CLAUDE_PLUGIN_ROOT}/scripts/` by content hash. Stale/missing files → WARN listing them.
   - With `--fix`: overwrite stale/missing scripts and templates from the plugin (workspace `README.md` is NEVER touched; topics/`status.json`/`index.md`/logs untouched). Report updated/unchanged per file, and remind that a running coordinator must be restarted to pick up new scripts.
6. **git** — informational only: note git/non-git mode (both fully supported).
7. **Coordinator liveness** — if any topic `status.json` holds a live `lock_owner`/`lock_until` in the future, or `run_auto.log.jsonl` was written in the last few minutes, note "coordinator appears active"; otherwise "not running — /review-new starts it automatically".
8. **Queue health** — count topics by state; highlight any `owner=human`/`blocked_reason` items needing attention.

End with a one-line verdict: "ready" / "ready (solo mode)" / "needs attention: <items>".
