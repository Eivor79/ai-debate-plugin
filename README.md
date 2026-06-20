# review-bus-tools

A Claude Code **plugin marketplace** that distributes the `review-bus` plugin — a file-based,
multi-agent (Claude/Codex) adversarial-review workflow with a hardened coordinator and an
async-review auto-resume watcher.

## What's inside

The `review-bus` plugin provides:

- **Commands**
  - `/review-init [dir]` — scaffold the workflow into the current repo (folders, scripts, templates, rules, `.gitignore`).
  - `/review-new <slug> [priority]` — open a new review topic (`topic.md` + `status.json`).
  - `/review-run [--watch ...]` — start the `run_auto.ps1` coordinator (drives Claude/Codex rounds by `status.json` owner).
  - `/review-wait <topic> [--until-...]` — wait in background for a review to advance, then auto-resume to continue the next step.
  - `/review-status [topic]` — queue / blocked / human-pending summary + recent coordinator activity.
- **Skill** `review-bus` — the workflow rules (HARD RULE), state machine, and the async-review decision tree. Auto-invoked when working with review_bus.
- **Scripts** (`scripts/`) — `run_auto.ps1` (coordinator), `wait_for_review.ps1` (autoresume watcher), `update_status.ps1` (atomic status writes), `scan_queue.ps1`, plus `templates/`.

> Scripts are PowerShell (Windows-first). `/review-init` copies them into the target repo's review_bus dir, where they resolve paths relative to that repo.

## Install (teammates)

```shell
# Add this marketplace (git URL or local path)
/plugin marketplace add <git-url-of-this-repo>

# Install the plugin
/plugin install review-bus@review-bus-tools
```

Update later with `/plugin marketplace update` after pushing changes here.

## Quick start in a repo

```shell
/review-init                 # scaffold llm_wiki/review_bus/ + scripts + rules
/review-new my-first-topic   # create a topic
/review-run --watch          # run the coordinator (unattended)
/review-wait <topic> --until-owner claude   # block-then-resume when it's your turn
/review-status               # see what needs attention
```

## HARD RULE (carried by the skill)

Never write another agent's review round on its behalf; never call `codex:*` skills for
review_bus docs. When `status.json` shows `owner=<other agent>` or `owner=human`, stop and
report. Code changes require a finalized `decision.md` + `allow_code_change=true` + human approval.

## Layout

```text
review-bus-plugin/                 (marketplace repo root)
├─ .claude-plugin/marketplace.json
└─ review-bus/                     (the plugin)
   ├─ .claude-plugin/plugin.json
   ├─ commands/   (5 slash commands)
   ├─ skills/review-bus/SKILL.md
   └─ scripts/    (.ps1 + templates/)
```
