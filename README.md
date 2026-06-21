# ai-debate-tools

A Claude Code **plugin marketplace** that distributes the **AI Debate Review** (`ai-debate`) plugin —
where multiple AI agents (Claude, Codex) **debate and adversarially verify** a topic across structured
rounds (design → attack → rebuttal → decision) and deliver a reasoned **decision to you**. Includes a
hardened coordinator and an async-review auto-resume watcher.

## What's inside

The `ai-debate` plugin provides:

- **Commands**
  - `/review-init [dir]` — scaffold the workflow into the current repo (folders, scripts, templates, rules, `.gitignore`). Default workspace `llm_wiki/ai_debate/`.
  - `/review-new <slug> [priority]` — open a new review topic (`topic.md` + `status.json`).
  - `/review-run [--watch ...]` — start the `run_auto.ps1` coordinator (drives Claude/Codex rounds by `status.json` owner, with role-specific prompts).
  - `/review-wait <topic> [--until-...]` — wait in background for a review to advance, then auto-resume to continue the next step.
  - `/review-status [topic]` — queue / blocked / human-pending summary + recent coordinator activity.
- **Skill** `ai-debate` — the workflow rules (HARD RULE), round roles, the structured-findings + adversarial-verification scheme, and the async-review decision tree. Auto-invoked when working with the review workflow.
- **Scripts** (`scripts/`) — `run_auto.ps1` (coordinator), `wait_for_review.ps1` (autoresume watcher), `update_status.ps1` (atomic status writes), `scan_queue.ps1`, plus `templates/`.

> Scripts are PowerShell (Windows-first, UTF-8 BOM for cross-codepage safety). `/review-init` copies them into the target repo's workspace; the coordinator is folder-name-agnostic.

## Review quality

Each round runs with a **role** and a structured `## Findings` schema (`id`/`severity`/`confidence`/`claim`/`evidence`/`refutable_by`):

- **DESIGNER** writes the design + a self-critique. **ATTACKER** raises the strongest concrete refutations.
- **REBUTTER** assigns each finding a verdict (`CONFIRMED` / `PLAUSIBLE` / `REFUTED`). **JUDGE** adopts only the survivors. This adversarial-verification step keeps plausible-but-wrong findings out of the decision.

## Install (teammates)

```shell
# Add this marketplace (git URL or local path)
/plugin marketplace add <git-url-of-this-repo>

# Install the plugin
/plugin install ai-debate@ai-debate-tools
```

Update later with `/plugin marketplace update` after pushing changes here.

## Quick start in a repo

```shell
/review-init                 # scaffold llm_wiki/ai_debate/ + scripts + rules
/review-new my-first-topic   # create a topic
/review-run --watch          # run the coordinator (unattended)
/review-wait <topic> --until-owner claude   # block-then-resume when it's your turn
/review-status               # see what needs attention
```

## HARD RULE (carried by the skill)

Never write another agent's review round on its behalf; never call `codex:*` skills for review docs.
When `status.json` shows `owner=<other agent>` or `owner=human`, stop and report. Code changes require
a finalized `decision.md` + `allow_code_change=true` + human approval.

## Layout

```text
ai-debate-plugin/                  (marketplace repo root)
├─ .claude-plugin/marketplace.json
└─ ai-debate/                      (the plugin)
   ├─ .claude-plugin/plugin.json
   ├─ commands/   (5 slash commands)
   ├─ skills/ai-debate/SKILL.md
   └─ scripts/    (.ps1 + templates/)
```
