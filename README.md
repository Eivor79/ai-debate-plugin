# AI Debate Review (`ai-debate`)

**Read in other languages / 다른 언어: English · [한국어](./README.ko.md)**

A Claude Code plugin where multiple AI agents (Claude, Codex) **debate and adversarially verify** a topic
across structured rounds (design → attack → rebuttal → decision) and deliver a reasoned **decision to you**.
Includes a hardened unattended coordinator and an async-review auto-resume watcher.

**Works in git and non-git projects.** By default a new topic is **autonomous**: start the coordinator
once and the agents run the entire debate to `decision.md` by themselves — no per-round human toggling.
Human approval is required only for **code changes** afterward (`--manual` opts back into per-round review).
**No codex? Still works** — the coordinator falls back to solo mode (claude executes codex rounds,
provenance-marked in the doc), so the debate completes with just the claude CLI installed.

---

## 🚀 Install

```text
/plugin marketplace add https://github.com/Eivor79/ai-debate-plugin
/plugin install ai-debate@ai-debate-tools
```

After installing, **fully restart Claude Code** (plugin commands/skills load at startup). Commands are
namespaced — `/ai-debate:review-init`. Update later: push to this repo → users run `/plugin marketplace update`.

---

## 💡 Tips & Examples

**You don't need to memorize commands.** Just say the intent in natural language — the `ai-debate` skill
auto-activates and picks the right action.

| Say this | What happens |
|---|---|
| "set up reviews in this repo" | scaffold the workspace (`review-init`) |
| "open a review topic on `<subject>`" | create topic + design round (`review-new`) |
| "run the review" / "start the AI debate" | run the coordinator — Claude·Codex rounds (`review-run`) |
| "resume when the review is done" | wait then auto-resume (`review-wait`) |
| "what's the review status / what's blocked?" | queue / blocked summary (`review-status`) |

**Example flow**

```text
You: "open a review topic on the ai-debate plugin improvements"
  → Claude writes topic.md + 001 design (DESIGNER)

You: "run the review"
  → coordinator runs Codex attack (002 ATTACKER)
  → on completion the session auto-resumes → Claude rebuttal (003 REBUTTER) → per-finding verdicts
  → if a call is the human's, it stops at owner=human and asks you

You: (answer)
  → Claude finalizes decision.md → implements the adopted items
```

> Tip: to change code you still need a finalized `decision.md` + `allow_code_change=true` + **your approval** (safety gate).
> Start light: `/ai-debate:review-status` just shows the current state.

---

## 🧩 What it is

The review workspace is a **file-based multi-agent debate space**. Agents exchange
`topic.md` → `001_..._design.md` → `002_..._attack.md` → `003_..._rebuttal.md` → `decision.md`,
**adversarially verifying** each other's claims and delivering a reasoned decision to you.
Default workspace `llm_wiki/ai_debate/` (configurable; the coordinator is folder-name-agnostic).
State is tracked per topic in `status.json`.

### Quick start

```text
/ai-debate:review-init                 # scaffold the workspace
/ai-debate:review-new my-first-topic   # create a topic
/ai-debate:review-run --watch          # run the coordinator (unattended)
/ai-debate:review-wait <topic> --until-owner claude   # block-then-resume when it's your turn
/ai-debate:review-status               # queue / blocked / human-pending
```

### Commands / Skill

| Command | Purpose |
|---|---|
| `/ai-debate:review-init [dir]` | Scaffold workspace, scripts, templates, rules into the project (git or non-git; `.gitignore` only when git is present) |
| `/ai-debate:review-new <slug> [priority] [--manual]` | Open a new topic (autonomous by default; `--manual` for per-round human review) |
| `/ai-debate:review-run [--watch ...]` | Start the coordinator (invokes Claude/Codex by `owner`, role-specific prompts) |
| `/ai-debate:review-wait <topic> [--until-...]` | Wait in background for progress → auto-resume |
| `/ai-debate:review-status [topic]` | Queue / blocked / human-pending summary |
| `/ai-debate:review-update [dir] [--with-rules]` | Re-sync workspace scripts/templates after a plugin update |

Skill `ai-debate:ai-debate` — workflow rules, roles, verification scheme. Auto-invoked on review intent.

### Review quality (roles · findings · verdicts)

Each round has a **role** and writes structured `## Findings` (`id`/`severity`/`confidence`/`claim`/`evidence`/`refutable_by`).
- **DESIGNER** design + self-critique · **ATTACKER** strongest concrete refutations · **REBUTTER** per-finding verdict (`CONFIRMED`/`PLAUSIBLE`/`REFUTED`) · **JUDGE** adopts only survivors.
- This adversarial-verification step keeps plausible-but-wrong findings out of the decision.

### HARD RULE

- Never write another agent's round (`owner=<other agent>` → stop and report).
- Never call `codex:*` skills for review docs (Codex rounds come from a separate codex process).
- Code changes require a finalized `decision.md` + `allow_code_change=true` + human approval.

### Coordinator hardening

Per-topic timeout, progress-stall detection (→ `owner=human`), turn-level error isolation, single-instance mutex,
JSONL run log, **scope guard** (warns+logs worker changes outside the workspace), `-ClaudeModel`/`-CodexModel` pinning.

### Platform

PowerShell (**Windows-first**), UTF-8 BOM. **macOS/Linux support is planned** (cross-platform port, deferred).
Project type **git or non-git**: the project root is resolved via `git rev-parse --show-toplevel` when git is
available, else the workspace parent (override with `run_auto.ps1 -RepoRoot <path>`); git-only steps are skipped without a repo.

---

## 📦 Layout / License

```text
ai-debate-plugin/
├─ .claude-plugin/marketplace.json
├─ LICENSE                         (MIT)
└─ ai-debate/
   ├─ .claude-plugin/plugin.json
   ├─ commands/   (6 slash commands)
   ├─ skills/ai-debate/SKILL.md
   └─ scripts/    (.ps1 + templates/)
```

License: **MIT**.
