---
name: ai-debate
description: Use when running or participating in the AI Debate Review workflow — where multiple AI agents (Claude, Codex) debate and adversarially verify a topic across structured rounds (design → attack → rebuttal → decision) and deliver a reasoned conclusion. Triggers on "ai debate", "review_bus", "리뷰 진행", "pr 진행", waiting on a Codex/Claude review round, or status.json owner handoffs.
---

# AI Debate Review workflow

The review workspace is a **file-based, multi-agent debate space**: agents (Claude, Codex) exchange
design → attack → rebuttal → decision documents about one topic, adversarially verifying each other's
claims, and converge on a decision delivered to the user. It is NOT a finished-docs store; confirmed
knowledge graduates to the wiki, in-flight argument stays in the workspace. Default workspace folder:
`llm_wiki/ai_debate/` (configurable; the coordinator is folder-name-agnostic).

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
- **Never call `codex:*` skills to create review documents.** Codex rounds come from a separate Codex process (the coordinator's `codex exec`, or the user's Codex session).
- Code changes are out of scope until `decision.md` is finalized AND `allow_code_change=true` AND human approval. The process produces documents and decisions, not implementation.
- Commit/push only when the user explicitly asks.

## Commands

- `/review-init [dir]` — scaffold the workflow into the current repo (folders, scripts, templates, rules, .gitignore).
- `/review-new <slug> [priority]` — open a new topic (topic.md + status.json).
- `/review-run [--watch ...]` — start the coordinator (`run_auto.ps1`) that invokes Claude/Codex per topic `owner`.
- `/review-wait <topic> [--until-...]` — wait in background for a review to advance, then auto-resume to continue.
- `/review-status [topic]` — queue / blocked / human-pending summary + recent coordinator activity.

## Advancing a topic (when it is your turn)

1. Read the workspace `README.md`, `index.md`, the topic's `topic.md`, `status.json`, and the latest numbered docs.
2. Act only if `owner` is your agent and the status is actionable. Otherwise stop (HARD RULE).
3. Write the expected `next_doc` for your round role, then update `status.json` (`owner`, `status`, `next_action`, `current_doc`, `next_doc`) and refresh the `index.md` row.
4. Keep changes inside the workspace/wiki metadata unless `allow_code_change=true`.

## Async review → auto-resume decision tree

When waiting on another agent's round, use `/review-wait` (it launches `wait_for_review.ps1` with `run_in_background`; the harness re-invokes this session on completion). On resume, read the watcher's JSON result and branch:

- `owner` = your agent + actionable status → read `latest_doc`, write the next round (or implement if a decision allows).
- `status = decided` + `allow_code_change = true` → implement within the decision scope, verify, update status.
- `owner = human` or `blocked_reason` set → STOP and report; human approval/attention is required. Do not auto-implement.

## Coordinator notes

`run_auto.ps1 -Watch` loops unattended: it reads each `status.json`, claims a per-topic lock, invokes the `owner` agent's CLI with a role-specific prompt, then verifies progress. It is hardened — per-topic timeout, progress-stall detection (escalates to `owner=human`), turn-level error catch (loop survives a failed agent), single-instance mutex, and a JSONL run log. Pin `-ClaudeModel`/`-CodexModel` for review-quality parity with interactive sessions.
