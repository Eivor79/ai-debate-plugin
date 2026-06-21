# AI Debate Review (`ai-debate`)

여러 AI(Claude · Codex)가 한 주제를 라운드로 토론·적대검증(설계 → 공격 → 반박 → 결정)해 근거 있는 결론을 전달하는 Claude Code 플러그인.
A Claude Code plugin where multiple AI agents (Claude, Codex) **debate and adversarially verify** a topic across structured rounds (design → attack → rebuttal → decision) and deliver a reasoned **decision to you**.

**[한국어](#한국어) · [English](#english)**

---

## 🚀 설치 / Install

```text
/plugin marketplace add https://github.com/Eivor79/ai-debate-plugin
/plugin install ai-debate@ai-debate-tools
```

설치 후 **Claude Code를 완전히 재시작**하세요. 명령에는 네임스페이스가 붙습니다 — `/ai-debate:review-init`.
After installing, **fully restart Claude Code**. Commands are namespaced — `/ai-debate:review-init`.

업데이트 / Update: push to this repo → users run `/plugin marketplace update`.

---

## 한국어

리뷰 워크스페이스는 **파일 기반 멀티에이전트 토론장**입니다. 에이전트들이 한 토픽에 대해
`topic.md` → `001_..._design.md` → `002_..._attack.md` → `003_..._rebuttal.md` → `decision.md`
문서를 주고받으며 서로의 주장을 **적대적으로 검증**하고, 합의된 결정을 사용자에게 전달합니다.
기본 폴더 `llm_wiki/ai_debate/`(설정 가능, 코디네이터는 폴더명 독립). 상태는 토픽별 `status.json`이 관리.

> 명령이 길어 번거로우면 "리뷰 진행" 같은 **자연어로 말하면** Claude가 알아서 스킬을 호출하게 둘 수 있습니다.

### 빠른 시작

```text
/ai-debate:review-init                 # 워크스페이스 llm_wiki/ai_debate/ + 스크립트·규칙 셋업
/ai-debate:review-new my-first-topic   # 새 토픽 생성 (topic.md + status.json)
/ai-debate:review-run --watch          # 코디네이터 무인 실행
/ai-debate:review-wait <topic> --until-owner claude   # 리뷰 끝나면 자동 재개
/ai-debate:review-status               # 큐 / 막힌 것 / 사람 대기 현황
```

### 명령 / 스킬

| 명령 | 설명 |
|---|---|
| `/ai-debate:review-init [dir]` | 현재 레포에 워크스페이스·스크립트·템플릿·규칙 셋업 |
| `/ai-debate:review-new <slug> [priority]` | 새 토픽 생성 |
| `/ai-debate:review-run [--watch ...]` | 코디네이터 실행(owner 기준 Claude/Codex 호출, 역할별 프롬프트) |
| `/ai-debate:review-wait <topic> [--until-...]` | 진전까지 백그라운드 대기 → 자동 재개 |
| `/ai-debate:review-status [topic]` | 큐/blocked/human 대기 요약 |

스킬 `ai-debate:ai-debate` — 워크플로 규칙·역할·검증 체계. "리뷰 진행"/"ai debate" 등에 자동 발동.

### 리뷰 품질 (역할 · findings · 평결)

각 라운드는 **역할**을 갖고 구조화된 `## Findings`(`id`/`severity`/`confidence`/`claim`/`evidence`/`refutable_by`)를 씁니다.
- **DESIGNER** 설계+자가비판 · **ATTACKER** 강한 구체 반박 · **REBUTTER** finding별 평결(`CONFIRMED`/`PLAUSIBLE`/`REFUTED`) · **JUDGE** 생존분만 채택.
- 이 적대적 검증이 "그럴듯하지만 틀린" 결론을 걸러냅니다.

### 규칙 (HARD RULE)

- 다른 에이전트의 라운드를 대신 쓰지 않는다(`owner=<다른 에이전트>`면 멈추고 보고).
- 리뷰 문서에 `codex:*` 스킬 호출 금지(Codex 라운드는 별도 codex 프로세스).
- 코드 변경은 `decision.md` 확정 + `allow_code_change=true` + 사람 승인 후에만.

### 코디네이터 안전장치

per-topic 타임아웃, 진전-정체 감지(→`owner=human`), 턴 단위 오류 격리, 단일 인스턴스 뮤텍스, JSONL 로그,
**scope guard**(worker가 워크스페이스 밖 변경 시 warn+log), `-ClaudeModel`/`-CodexModel` 모델 고정.

### 플랫폼

PowerShell(**Windows 우선**), UTF-8 BOM. **macOS/Linux 지원은 예정**(크로스플랫폼 포팅, 후순위).

---

## English

The review workspace is a **file-based multi-agent debate space**. Agents exchange
`topic.md` → `001_..._design.md` → `002_..._attack.md` → `003_..._rebuttal.md` → `decision.md`,
**adversarially verifying** each other's claims and delivering a reasoned decision to you.
Default workspace `llm_wiki/ai_debate/` (configurable; the coordinator is folder-name-agnostic).
State is tracked per topic in `status.json`.

> Tedious to type? Just say the intent in natural language and let Claude invoke the right skill.

### Quick start

```text
/ai-debate:review-init                 # scaffold llm_wiki/ai_debate/ + scripts + rules
/ai-debate:review-new my-first-topic   # create a topic (topic.md + status.json)
/ai-debate:review-run --watch          # run the coordinator (unattended)
/ai-debate:review-wait <topic> --until-owner claude   # block-then-resume when it's your turn
/ai-debate:review-status               # queue / blocked / human-pending
```

### Commands / Skill

| Command | Purpose |
|---|---|
| `/ai-debate:review-init [dir]` | Scaffold workspace, scripts, templates, rules into the repo |
| `/ai-debate:review-new <slug> [priority]` | Open a new topic |
| `/ai-debate:review-run [--watch ...]` | Start the coordinator (invokes Claude/Codex by `owner`, role-specific prompts) |
| `/ai-debate:review-wait <topic> [--until-...]` | Wait in background for progress → auto-resume |
| `/ai-debate:review-status [topic]` | Queue / blocked / human-pending summary |

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

---

## 📦 구조 / Layout · License

```text
ai-debate-plugin/                  (marketplace repo root)
├─ .claude-plugin/marketplace.json
├─ LICENSE                         (MIT)
└─ ai-debate/                      (the plugin)
   ├─ .claude-plugin/plugin.json
   ├─ commands/   (5 slash commands)
   ├─ skills/ai-debate/SKILL.md
   └─ scripts/    (.ps1 + templates/)
```

License: **MIT**.
