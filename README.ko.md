# AI Debate Review (`ai-debate`)

**다른 언어로 보기 / Other languages: [English](./README.md) · 한국어**

여러 AI(Claude · Codex)가 한 주제를 라운드로 **토론·적대검증**(설계 → 공격 → 반박 → 결정)해
근거 있는 **결론을 당신에게 전달**하는 Claude Code 플러그인.

## ⚡ 토픽 하나 열고, 자리 비우고, 돌아와서 결론만 읽으세요

워크플로 전부가 이겁니다:

```text
/ai-debate:review-new api-응답-캐싱-할까     # ← 필요한 명령은 이거 하나
        ...스캐폴드→코디네이터 기동→에이전트끼리 알아서 토론...
   001_claude_design.md → 002_codex_attack.md → 003_claude_rebuttal.md → decision.md
```

라운드 사이에 봐줄 필요가 없습니다: 코디네이터가 토픽을 에이전트 간에 자동으로 넘겨가며
`decision.md`에 수렴할 때까지 토론을 이어갑니다(**라운드 캡**이 종결을 보장). **토픽 여러 개**를
쌓아두면 우선순위대로 전부 처리합니다. 당신은 결론만 읽으면 되고, 뭔가 물어보는 건 **코드 변경 승인** 그 한 번뿐입니다.

덧붙여: **git / 비-git** 프로젝트, **Windows** + (베타) **macOS/Linux** 모두 동작하고,
**codex가 없어도 됩니다** — claude가 solo로 토론을 대행(provenance 표기)해 라운드가 멈추지 않습니다.
라운드마다 직접 심판하고 싶으면 `--manual`로 토픽을 만드세요.

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
| "〈주제〉 토론해봐" / "〈주제〉로 리뷰 열어" | 전체 파이프라인: 스캐폴드→토픽→코디네이터 기동→에이전트 토론→평결 보고 (`review-new`) |
| "리뷰 현황 / 뭐 막혔어?" | 큐·blocked 요약 (`review-status`) |
| "리뷰 환경 괜찮아?" | 사전 진단, `--fix`로 낡은 스크립트 복구 (`review-doctor`) |
| "코디네이터 재시작해" | 코디네이터 수동 제어 (`review-run`) |

**실제 사용 흐름 예**

```text
나: "ai-debate 플러그인 개선점으로 리뷰 주제 하나 열어줘"
  → topic.md 생성, 기본이 자율 모드(auto=true)

나: "리뷰 진행"
  → 코디네이터가 넘겨받아 라운드를 "알아서" 순환:
     Claude 설계(001) → Codex 공격(002) → Claude 반박(003)
     → finding별 평결 → decision.md
  → 그 사이 할 일 없음 — 커피 한 잔 (토픽을 더 쌓아둬도 됨)

나: (decision.md 읽기)
  → 채택분을 구현까지? 코드 변경만 승인하면 끝 — 그게 유일한 게이트
```

> 팁: 코드까지 바꾸려면 `decision.md` 확정 + `allow_code_change=true` + **당신의 승인**이 필요합니다(안전장치).
> 처음엔 가볍게 `/ai-debate:review-status`로 현황만 봐도 됩니다.

---

## 📜 실제 결과물 (이 플러그인 자신을 리뷰한 dogfood 사례)

워크플로를 **플러그인 자기 자신에게** 돌렸습니다: Claude가 개선안을 설계 → Codex가 공격 → Claude가 반박 → 판정.

```text
ATTACKER (codex) — 구조화 findings 8건, 예:
  F5  severity:high  claim: 코디네이터 워커가 자동수락(acceptEdits)로 실행되어
      리뷰 워크스페이스 "밖" 파일 변경이 감지되지 않음
  F6  severity:med   claim: -EnableExisting 문서가 실제 session-only
      동작과 모순 (문서-구현 불일치)

REBUTTER (claude) — finding별 평결: 7 CONFIRMED / 1 하향
      (F5는 설계자 자가비판에선 low였음 — 공격자가 high로 승격,
       반박 라운드에서 수용)

JUDGE — decision.md 는 생존 findings만 채택:
  ✔ 보안 scope guard (warn-first)   ✔ 문서 정정   ✔ MIT 라이선스+메타데이터
  ✔ 크로스플랫폼 포팅을 별도 우선순위 토픽으로 분리
```

적대적 검증이 솔로 설계가 놓친 것을 실제로 잡았습니다: **과소평가된 보안 구멍**, **설계자 본인이 쓴 문서-구현 불일치**, 증거 미고정. 이게 이 워크플로의 존재 이유입니다.

---

## 🧩 무엇인가요

리뷰 워크스페이스는 **파일 기반 멀티에이전트 토론장**입니다. 에이전트들이 한 토픽에 대해
`topic.md` → `001_..._design.md` → `002_..._attack.md` → `003_..._rebuttal.md` → `decision.md`
문서를 주고받으며 서로의 주장을 **적대적으로 검증**하고, 합의된 결정을 사용자에게 전달합니다.
기본 폴더 `llm_wiki/ai_debate/`(설정 가능, 코디네이터는 폴더명 독립). 상태는 토픽별 `status.json`이 관리.

### 빠른 시작

```text
/ai-debate:review-new my-first-topic   # 이거면 끝 — 스캐폴드, 토론, 평결 보고까지
/ai-debate:review-status               # (선택) 큐 지켜보기
```

### 명령 / 스킬 — 단 4개

| 명령 | 설명 |
|---|---|
| `/ai-debate:review-new <주제> [priority] [--rounds N] [--manual] [--no-run]` | **진입점**: 스캐폴드→토픽→코디네이터 기동→`decision.md`까지 토론→평결 보고. `--rounds N`=라운드 예산(1라운드=문서 1개); 진행 중 "해당 주제 5라운드로"라고 하면 다음 턴부터 즉시 반영 |
| `/ai-debate:review-run [--watch ...]` | 코디네이터 수동 제어(재시작, 모델 고정) |
| `/ai-debate:review-status [topic]` | 큐/blocked/human 요약 |
| `/ai-debate:review-doctor [dir] [--fix]` | 사전 진단: pwsh/CLI/워크스페이스 최신성; `--fix`로 낡은 스크립트 재동기화 |

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

per-topic 타임아웃, 진전-정체 감지(→`owner=human`), **라운드 캡**(기본 5문서, 토픽별 `max_rounds` —
핑퐁 토론을 강제 JUDGE 평결로 종결 보장), 턴 단위 오류 격리, 단일 인스턴스 뮤텍스, JSONL 로그(5MB 로테이션),
**scope guard**(worker가 워크스페이스 밖 변경 시 warn+log), `-ClaudeModel`/`-CodexModel` 모델 고정.

### 플랫폼

- **Windows**: 그대로 동작 (Windows PowerShell 5.1 또는 PowerShell 7).
- **macOS/Linux (베타)**: [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) 필요(`brew install --cask powershell` / `apt-get install powershell`), 코디네이터는 `pwsh`로 실행 — 예: `pwsh ./llm_wiki/ai_debate/run_auto.ps1 -Watch`. 스크립트는 크로스플랫폼(호스트셸/트리킬/폴더열기/경로가 OS별 분기)이지만 실제 macOS/Linux 기기 검증 전 — 이슈 환영.
- 프로젝트 유형 **git/비-git**: 프로젝트 루트는 git 있으면 `git rev-parse --show-toplevel`, 없으면 워크스페이스 부모로
자동 해석됩니다(`run_auto.ps1 -RepoRoot <경로>`로 지정 가능). git이 아니면 git 전용 단계는 건너뜁니다.

---

## 📦 구조 / 라이선스

```text
ai-debate-plugin/
├─ .claude-plugin/marketplace.json
├─ LICENSE                         (MIT)
└─ ai-debate/
   ├─ .claude-plugin/plugin.json
   ├─ commands/   (4 slash commands)
   ├─ skills/ai-debate/SKILL.md
   └─ scripts/    (.ps1 + templates/)
```

라이선스: **MIT**.
