# AI Debate Review (`ai-debate`)

**Read in other languages / 다른 언어: English · [한국어](./README.ko.md)**

A Claude Code plugin where multiple AI agents (Claude, Codex) **debate and adversarially verify** a topic
across structured rounds (design → attack → rebuttal → decision) and deliver a reasoned **decision to you**.

## ⚡ Open a topic. Walk away. Come back to a verdict.

That's the whole workflow:

```text
/ai-debate:review-new should-we-cache-api-responses     # 1. open a topic
/ai-debate:review-run --watch                           # 2. start the coordinator once
        ...agents debate round after round, hands-free...
   001_claude_design.md → 002_codex_attack.md → 003_claude_rebuttal.md → decision.md
```

No babysitting between rounds: the coordinator hands the topic back and forth between the agents
automatically until the debate converges on `decision.md`. Queue **several topics** and it works
through all of them by priority. You read the verdict — the only time you're asked anything is
when a **code change** needs your approval.

Also: works in **git and non-git** projects, on **Windows** and (beta) **macOS/Linux**, and
**no codex? still works** — claude debates solo (provenance-marked) so the rounds never stall.
Prefer to referee each round yourself? Create the topic with `--manual`.

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
  → topic.md created, autonomous by default (auto=true)

You: "run the review"
  → the coordinator takes over and cycles the rounds BY ITSELF:
     Claude design (001) → Codex attack (002) → Claude rebuttal (003)
     → per-finding verdicts → decision.md
  → you do nothing in between — go grab a coffee (or queue more topics)

You: (read decision.md)
  → want the adopted items implemented? approve the code change — that's your only gate
```

> Tip: to change code you still need a finalized `decision.md` + `allow_code_change=true` + **your approval** (safety gate).
> Start light: `/ai-debate:review-status` just shows the current state.

---

## 📜 Real output (dogfooded on this very plugin)

We ran the workflow **on itself**: Claude designed plugin improvements, Codex attacked the design, Claude rebutted, then a judge decided.

```text
ATTACKER (codex) — 8 structured findings, e.g.:
  F5  severity:high  claim: coordinator workers run with auto-accepted edits;
      changes OUTSIDE the review workspace would go undetected
  F6  severity:med   claim: -EnableExisting docs contradict the actual
      session-only behavior (doc–implementation mismatch)

REBUTTER (claude) — per-finding verdicts: 7 CONFIRMED / 1 downgraded
      (F5 was filed low by the designer's self-critique — the attacker
       escalated it to high, and the rebuttal conceded)

JUDGE — decision.md adopted only the survivors:
  ✔ security scope guard (warn-first)   ✔ doc fixes   ✔ MIT license + metadata
  ✔ cross-platform port spun off as its own prioritized topic
```

The adversarial pass caught what the solo design missed: an **underrated security hole**, a **doc–implementation mismatch the designer wrote himself**, and unpinned evidence. That's the point of the workflow.

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

- **Windows**: works out of the box (Windows PowerShell 5.1 or PowerShell 7).
- **macOS/Linux (beta)**: requires [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) (`brew install --cask powershell` / `apt-get install powershell`), then run the coordinator with `pwsh`, e.g. `pwsh ./llm_wiki/ai_debate/run_auto.ps1 -Watch`. The scripts are cross-platform (host-shell/tree-kill/folder-open/path handling all branch per OS) but have not yet been verified on real macOS/Linux hardware — issues welcome.
- Project type **git or non-git**: the project root is resolved via `git rev-parse --show-toplevel` when git is
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
