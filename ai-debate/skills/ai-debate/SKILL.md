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

## Default happy path — open a topic, let the agents debate, report the verdict

When the user names something to debate/review ("X를 토론해봐", "debate whether we should X",
"리뷰 붙여줘"), run this flow — do NOT hand-write rounds yourself:

1. **Workspace** — if no workspace exists (no `run_auto.ps1` found), scaffold one first (`/review-init`).
2. **Create the topic in one shot** (`/review-new`): derive a kebab-case slug from the user's phrase and
   write `topic.md` yourself from conversation context (background, the question, competing options).
   Do not interrogate the user with setup questions — one clarifying question max, and only if the topic
   is genuinely ambiguous. Defaults: priority `p2`, `auto=true`, owner = designer agent (`claude`).
3. **Start the debate** (`/review-run --watch`, `run_in_background`): the coordinator now cycles the
   rounds **by itself** — design → attack → rebuttal → decision — handing the topic between agents with
   no human toggling. Multiple topics? Just create them all; the queue drains by priority.
4. **Don't poll, don't participate** — use `/review-wait <topic> --until-status decided` (background) so
   the session sleeps until the debate lands, then **report the `decision.md` verdict** to the user:
   adopted findings, the ruling, residual risks, next step.
5. The only human gate is **code changes** (`allow_code_change=true` after `decision.md`). Everything
   before that is hands-free by design.

For classic per-round human refereeing, create the topic with `--manual` (`auto=false`) — only when the
user asks for it.

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

## Commands

- `/review-init [dir]` — scaffold the workflow into the current repo (folders, scripts, templates, rules, .gitignore).
- `/review-new <slug> [priority] [--manual]` — open a new topic in one shot (topic.md written from context + status.json, autonomous by default).
- `/review-run [--watch ...]` — start the coordinator (`run_auto.ps1`) that invokes Claude/Codex per topic `owner`. Falls back to solo mode (claude executes codex rounds, provenance-marked) when the codex CLI is missing.
- `/review-wait <topic> [--until-...]` — wait in background for a review to advance, then auto-resume to continue.
- `/review-status [topic]` — queue / blocked / human-pending summary + recent coordinator activity.
- `/review-update [dir] [--with-rules]` — re-sync a workspace's copied scripts/templates to the installed plugin version (topics/status untouched; rules only with `--with-rules`).

## Advancing a topic manually (exception, not the default)

The coordinator normally cycles rounds by itself — write a round in-session only when the user explicitly
asks you to, or a topic is `--manual` and it is your turn:

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
