# AI Debate Review (`ai-debate`)

**다른 언어로 보기 / Other languages: [English](./README.md) · 한국어**

여러 AI(Claude · Codex)가 한 주제를 라운드로 **토론·적대검증**(설계 → 공격 → 반박 → 결정)해
근거 있는 **결론을 당신에게 전달**하는 Claude Code 플러그인. 무인 코디네이터 + 리뷰 완료 자동재개 감시자 포함.

**git / 비-git 프로젝트 양쪽에서 동작**합니다. 신규 토픽은 기본 **자율 모드**: 코디네이터를 한 번 띄우면
에이전트끼리 `decision.md`까지 **알아서 끝까지** 진행하며 라운드별 사람 개입이 없습니다.
사람 승인은 이후 **코드 변경**에만 필요합니다(`--manual`로 라운드별 검토로 되돌릴 수 있음).

---

## 🚀 설치

```text
/plugin marketplace add https://github.com/Eivor79/ai-debate-plugin
/plugin install ai-debate@ai-debate-tools
```

설치 후 **Claude Code를 완전히 재시작**하세요. 명령에는 네임스페이스가 붙습니다 — `/ai-debate:review-init`.
업데이트: 이 repo에 push → 팀원이 `/plugin marketplace update`.

---

## 💡 사용 팁 & 예제

**명령을 외울 필요 없습니다.** Claude에게 자연어로 의도를 말하면 `ai-debate` 스킬이 자동 발동해 알맞은 동작을 합니다.

| 이렇게 말하면 | 일어나는 일 |
|---|---|
| "이 레포에 리뷰 셋업해" | 워크스페이스 스캐폴딩 (`review-init`) |
| "〈주제〉로 새 리뷰 주제 열어" | 토픽 생성 + 설계 라운드 (`review-new`) |
| "리뷰 진행" / "리뷰 돌려" / "pr 진행" | 코디네이터 실행 — Claude·Codex 라운드 (`review-run`) |
| "리뷰 끝나면 이어서 해" | 완료까지 대기 후 자동 재개 (`review-wait`) |
| "리뷰 현황 / 뭐 막혔어?" | 큐·blocked 요약 (`review-status`) |

**실제 사용 흐름 예**

```text
나: "ai-debate 플러그인 개선점으로 리뷰 주제 하나 열어줘"
  → Claude가 topic.md + 001 설계(DESIGNER) 작성

나: "리뷰 진행"
  → 코디네이터가 Codex 공격(002 ATTACKER) 실행
  → 완료 시 세션 자동 재개 → Claude 반박(003 REBUTTER) → finding별 평결
  → 쟁점이 사람 결정이면 owner=human 으로 멈추고 질문

나: (질문에 답)
  → Claude가 decision.md 확정 → 채택분 구현
```

> 팁: 코드까지 바꾸려면 `decision.md` 확정 + `allow_code_change=true` + **당신의 승인**이 필요합니다(안전장치).
> 처음엔 가볍게 `/ai-debate:review-status`로 현황만 봐도 됩니다.

---

## 🧩 무엇인가요

리뷰 워크스페이스는 **파일 기반 멀티에이전트 토론장**입니다. 에이전트들이 한 토픽에 대해
`topic.md` → `001_..._design.md` → `002_..._attack.md` → `003_..._rebuttal.md` → `decision.md`
문서를 주고받으며 서로의 주장을 **적대적으로 검증**하고, 합의된 결정을 사용자에게 전달합니다.
기본 폴더 `llm_wiki/ai_debate/`(설정 가능, 코디네이터는 폴더명 독립). 상태는 토픽별 `status.json`이 관리.

### 빠른 시작

```text
/ai-debate:review-init                 # 워크스페이스 셋업
/ai-debate:review-new my-first-topic   # 새 토픽 생성
/ai-debate:review-run --watch          # 코디네이터 무인 실행
/ai-debate:review-wait <topic> --until-owner claude   # 리뷰 끝나면 자동 재개
/ai-debate:review-status               # 현황
```

### 명령 / 스킬

| 명령 | 설명 |
|---|---|
| `/ai-debate:review-init [dir]` | 워크스페이스·스크립트·템플릿·규칙 셋업 (git/비-git; `.gitignore`는 git일 때만) |
| `/ai-debate:review-new <slug> [priority] [--manual]` | 새 토픽 생성 (기본 자율; `--manual`은 라운드별 사람검토) |
| `/ai-debate:review-run [--watch ...]` | 코디네이터 실행(owner 기준 Claude/Codex 호출) |
| `/ai-debate:review-wait <topic> [--until-...]` | 진전까지 대기 → 자동 재개 |
| `/ai-debate:review-status [topic]` | 큐/blocked/human 요약 |

스킬 `ai-debate:ai-debate` — 워크플로 규칙·역할·검증 체계. "리뷰 진행"/"ai debate" 등에 자동 발동.

### 리뷰 품질 (역할 · findings · 평결)

각 라운드는 **역할**을 갖고 구조화된 `## Findings`(`id`/`severity`/`confidence`/`claim`/`evidence`/`refutable_by`)를 씁니다.
- **DESIGNER** 설계+자가비판 · **ATTACKER** 강한 구체 반박 · **REBUTTER** finding별 평결(`CONFIRMED`/`PLAUSIBLE`/`REFUTED`) · **JUDGE** 생존분만 채택.
- 이 적대적 검증이 "그럴듯하지만 틀린" 결론을 걸러냅니다.

### 규칙 (HARD RULE)

- 다른 에이전트의 라운드를 대신 쓰지 않는다(`owner=<다른 에이전트>`면 멈추고 보고).
- 리뷰 문서에 `codex:*` 스킬 호출 금지.
- 코드 변경은 `decision.md` 확정 + `allow_code_change=true` + 사람 승인 후에만.

### 코디네이터 안전장치

per-topic 타임아웃, 진전-정체 감지(→`owner=human`), 턴 단위 오류 격리, 단일 인스턴스 뮤텍스, JSONL 로그,
**scope guard**(worker가 워크스페이스 밖 변경 시 warn+log), `-ClaudeModel`/`-CodexModel` 모델 고정.

### 플랫폼

PowerShell(**Windows 우선**), UTF-8 BOM. **macOS/Linux 지원은 예정**(크로스플랫폼 포팅, 후순위).
프로젝트 유형 **git/비-git**: 프로젝트 루트는 git 있으면 `git rev-parse --show-toplevel`, 없으면 워크스페이스 부모로
자동 해석됩니다(`run_auto.ps1 -RepoRoot <경로>`로 지정 가능). git이 아니면 git 전용 단계는 건너뜁니다.

---

## 📦 구조 / 라이선스

```text
ai-debate-plugin/
├─ .claude-plugin/marketplace.json
├─ LICENSE                         (MIT)
└─ ai-debate/
   ├─ .claude-plugin/plugin.json
   ├─ commands/   (5 slash commands)
   ├─ skills/ai-debate/SKILL.md
   └─ scripts/    (.ps1 + templates/)
```

라이선스: **MIT**.
