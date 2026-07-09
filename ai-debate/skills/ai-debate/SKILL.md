---
name: ai-debate
description: Use when the user wants AI agents to debate, adversarially review, or stress-test a topic/design/decision — the AI Debate Review workflow where Claude and Codex exchange structured rounds (design → attack → rebuttal → decision) autonomously and deliver a reasoned conclusion. Triggers on "ai debate", "debate this", "토론", "토론 붙여", "review_bus", "리뷰 진행", "리뷰 돌려", "pr 진행", waiting on a Codex/Claude review round, or status.json owner handoffs.
---

# AI Debate Review workflow

The review workspace is a **file-based, multi-agent debate space**: agents (Claude, Codex) exchange
design → attack → rebuttal → decision documents about one topic, adversarially verifying each other's
claims, and converge on a decision delivered to the user. It is NOT a finished-docs store; confirmed
knowledge graduates to the wiki, in-flight argument stays in the workspace. Default workspace folder:
`llm_wiki/ai_debate/` (configurable; the coordinator is folder-name-agnostic).

## Default happy path — one command, hands-free to the verdict

When the user names something to debate/review ("X를 토론해봐", "debate whether we should X",
"리뷰 붙여줘"), the ENTIRE flow is one command — `/review-new <topic>` — which:

1. scaffolds the workspace if missing (no separate init step),
2. creates the topic in one shot — slug derived from the user's phrase, `topic.md` written from
   conversation context (do not interrogate the user; one clarifying question max), `auto=true`,
3. starts the coordinator in the background (`run_auto.ps1 -Watch`; the single-instance mutex makes a
   duplicate start harmless), so the agents cycle design → attack → rebuttal → decision **by themselves**,
4. waits in the background (`wait_for_review.ps1 <topic> -UntilStatusLike decided*`, `run_in_background`)
   and, on completion, **reports the `decision.md` verdict**: adopted findings, ruling, residual risks, next step.

Do NOT hand-write rounds yourself, do NOT poll. Multiple topics? Run `/review-new` for each; the queue
drains by priority. A round cap (default 7 numbered docs, per-topic `max_rounds`) forces a JUDGE verdict
if the debate ping-pongs, so autonomous runs always terminate.

The only human gate is **code changes** (`allow_code_change=true` after `decision.md`). For classic
per-round human refereeing, use `--manual` — only when the user asks for it.

**Works in git AND non-git projects.** Git-only steps (`.gitignore`) are skipped when no git repo is
present, and the coordinator resolves the project root via `git rev-parse --show-toplevel` when git is
available, falling back to the workspace's parent otherwise (override with `run_auto.ps1 -RepoRoot`).

## Core artifacts (per topic folder)

- `topic.md` — background, problem, competing hypotheses.
- `NNN_<agent>_<round>.md` — numbered rounds: `001_claude_design.md`, `002_codex_attack_round1.md`, `003_claude_rebuttal_round1.md`, ... `decision.md`.
- `status.json` — the state machine. Key fields: `status`, `owner`, `next_action`, `current_doc`, `next_doc`, `auto`, `allow_code_change`, `priority`, `lock_owner`/`lock_until`, `blocked_reason`.

## Round roles (review-quality)

Each round has a role; reviewers write a structured `## Findings` section (`id`/`severity`/`confidence`/`claim`/`evidence`/`refutable_by`). See `_templates/findings.schema.md`.

- **DESIGNER** — design + self-critique (pre-empt the attacker).
- **ATTACKER** — strongest concrete refutations, no softening.
- **REBUTTER** — per finding, a verdict: `CONFIRMED` / `PLAUSIBLE` / `REFUTED` (REFUTED needs a concrete counter).
- **JUDGE** — adopt only surviving findings (CONFIRMED + well-evidenced PLAUSIBLE); drop REFUTED. This adversarial-verification step keeps plausible-but-wrong findings out of the decision.

## HARD RULE (never violate)

- **Never write another agent's review round on its behalf.** When `status.json` shows `owner=<other agent>` (e.g. `codex`), STOP and report to the user — that agent runs from its own session or via the coordinator.
  - *Single sanctioned exception — coordinator solo fallback*: when the codex CLI is unavailable, the coordinator (`run_auto.ps1`, auto-detected or `-SoloClaude`) may execute a codex-owned round via the claude CLI; the doc must carry a provenance line (`> executed_by: claude (solo fallback for codex)`). Interactive sessions still must NOT do this manually.
- **Never call `codex:*` skills to create review documents.** Codex rounds come from a separate Codex process (the coordinator's `codex exec`, or the user's Codex session).
- Code changes are out of scope until `decision.md` is finalized AND `allow_code_change=true` AND human approval. The process produces documents and decisions, not implementation.
- Commit/push only when the user explicitly asks.

## Commands (4)

- `/review-new <topic> [priority] [--manual] [--no-run]` — **the entry point**: scaffold if needed → create topic → start coordinator → wait → report verdict. One shot.
- `/review-run [--watch ...]` — manual coordinator control (restart, pin models, flags). Solo fallback when codex is missing.
- `/review-status [topic]` — queue / blocked / human-pending summary + recent coordinator activity.
- `/review-doctor [dir] [--fix]` — preflight (pwsh/CLIs/workspace freshness/queue health); `--fix` re-syncs stale workspace scripts from the plugin.

(`wait_for_review.ps1` and `update_status.ps1` are internal plumbing invoked by the flows above — not user commands.)

## Advancing a topic manually (exception, not the default)

The coordinator normally cycles rounds by itself — write a round in-session only when the user explicitly
asks you to, or a topic is `--manual` and it is your turn:

1. Read the workspace `README.md`, `index.md`, the topic's `topic.md`, `status.json`, and the latest numbered docs.
2. Act only if `owner` is your agent and the status is actionable. Otherwise stop (HARD RULE).
3. Write the expected `next_doc` for your round role, then update `status.json` (`owner`, `status`, `next_action`, `current_doc`, `next_doc`) and refresh the `index.md` row.
4. Keep changes inside the workspace/wiki metadata unless `allow_code_change=true`.

## Async review → auto-resume decision tree

When waiting on a debate, launch `wait_for_review.ps1` (workspace root) with `run_in_background` — the harness re-invokes this session on completion. On resume, read the watcher's JSON result and branch:

- `owner` = your agent + actionable status → read `latest_doc`, write the next round (or implement if a decision allows).
- `status = decided` + `allow_code_change = true` → implement within the decision scope, verify, update status.
- `owner = human` or `blocked_reason` set → STOP and report; human approval/attention is required. Do not auto-implement.

## Coordinator notes

`run_auto.ps1 -Watch` loops unattended: it reads each `status.json`, claims a per-topic lock, invokes the `owner` agent's CLI with a role-specific prompt, then verifies progress. It is hardened — per-topic timeout, progress-stall detection (escalates to `owner=human`), **round cap** (`-MaxNumberedDocs`, default 7; per-topic `max_rounds` override — forces a JUDGE verdict so ping-pong debates always terminate), turn-level error catch (loop survives a failed agent), single-instance mutex, and a JSONL run log (5MB rotation). Pin `-ClaudeModel`/`-CodexModel` for review-quality parity with interactive sessions.
