# Changelog

## v0.5.2 — 2026-07-10

- **Default round budget is now 5** (was 7): the coordinator default `-MaxNumberedDocs` is 5, so a plain `/review-new` runs a 5-round debate (design → 2 attack/rebuttal cycles → forced JUDGE) with no `--rounds` needed. Per-topic `max_rounds` still overrides.

## v0.5.1 — 2026-07-10

- **Natural-language round budget, applied live**: "make that topic 5 rounds" (해당 주제 5라운드로) now works — `/review-new --rounds N` at creation, or `update_status.ps1 -Set @{max_rounds=N} -Force` on a running topic; the coordinator re-reads `max_rounds` every poll, so the change takes effect on the very next turn (no restart). 1 round = 1 numbered doc. Template exposes `max_rounds: 0` (0 = coordinator default 7); schema documented; skill carries the mapping.

## v0.5.0 — 2026-07-10

- **Round cap → guaranteed termination**: coordinator `-MaxNumberedDocs` (default 7; per-topic `max_rounds` override). When a debate ping-pongs past the cap, the next turn is forced into a JUDGE round that writes `decision.md` from the existing rounds. Autonomous runs now always terminate.
- **Command diet (6 → 4, breaking)**: `/review-new` is now the one-shot entry point — scaffolds the workspace if missing, creates the topic, starts the coordinator in the background, waits, and reports the verdict. Removed `/review-init` (absorbed by `review-new`), `/review-wait` (internal plumbing; `wait_for_review.ps1` remains), `/review-update` (absorbed by `review-doctor --fix`).
- **New `/review-doctor [--fix]`**: preflight — PowerShell engine (pwsh on macOS/Linux), claude/codex CLIs (solo-fallback note), workspace script freshness vs plugin, git mode, coordinator liveness, queue health. `--fix` re-syncs stale scripts.
- Run log rotation: `run_auto.log.jsonl` rolls to `.1` past 5MB.

## v0.4.1 — 2026-07-10

- Skill: "default happy path" — one-shot topic creation from conversation context, hands-free continuous debate, verdict-only reporting; natural-language debate triggers.

## v0.4.0 — 2026-07-03

- macOS/Linux support (beta) via cross-platform PowerShell 7: platform-branched host shell, process-tree kill, folder-open, path handling; named-mutex guard. Not yet verified on real macOS/Linux hardware.
- README: real dogfooded debate excerpt (8 findings, 7 CONFIRMED, security low→high escalation).

## v0.3.0 — 2026-07-03

- Claude-solo fallback: when the codex CLI is missing (or `-SoloClaude`), claude executes codex-owned rounds with a provenance line — the debate never stalls on a missing CLI.
- `/review-update` to re-sync scaffolded workspace scripts after a plugin update (later absorbed by `review-doctor --fix` in v0.5.0).

## v0.2.0 — 2026-07-02

- Works in git AND non-git projects: project root resolved via `git rev-parse --show-toplevel` when available, workspace-parent fallback otherwise; `.gitignore` step skipped without a repo; `-RepoRoot` override.
- Autonomous by default: new topics scaffold with `auto=true`, owner=designer agent — the coordinator drives design → attack → rebuttal → decision with no per-round human toggling. Human gate only on code changes.

## v0.1.0 — 2026-06-21

- Initial public release: file-based adversarial review workflow (design/attack/rebuttal/decision), hardened unattended coordinator, async auto-resume watcher, review-quality round roles + structured findings schema.
