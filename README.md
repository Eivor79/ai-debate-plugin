# AI Debate Review (`ai-debate`)

여러 AI(Claude · Codex)가 한 주제를 **라운드로 토론·적대검증**(설계 → 공격 → 반박 → 결정)해
근거 있는 **결론을 당신에게 전달**하는 Claude Code 플러그인. 무인 코디네이터 + 리뷰 완료 자동재개 감시자 포함.

---

## 🚀 설치 (가장 먼저)

Claude Code 앱에서 두 줄:

```text
/plugin marketplace add https://github.com/Eivor79/ai-debate-plugin
/plugin install ai-debate@ai-debate-tools
```

설치 후 **Claude Code를 완전히 종료했다가 다시 켜세요.** (플러그인의 명령·스킬은 재시작 때 로드됩니다. `/reload-skills`만으로는 안 잡힙니다.)

> ⚠️ 명령에는 **네임스페이스 접두**가 붙습니다 — `/review-init`이 아니라 **`/ai-debate:review-init`** 입니다.
> 매번 치기 번거로우면, "리뷰 진행" 같은 **자연어로 말하면** Claude가 알아서 해당 스킬을 호출하게 둘 수 있습니다.

업데이트: 이 repo에 변경을 push한 뒤 사용자가 `/plugin marketplace update`.

---

## ⚡ 빠른 시작

아무 레포(또는 새 폴더)에서:

```text
/ai-debate:review-init                 # 워크스페이스 llm_wiki/ai_debate/ + 스크립트·규칙 셋업
/ai-debate:review-new my-first-topic   # 새 리뷰 토픽 생성 (topic.md + status.json)
/ai-debate:review-run --watch          # 코디네이터 무인 실행 (Claude/Codex 라운드 자동)
/ai-debate:review-wait <topic> --until-owner claude   # 리뷰 끝나면 자동 재개
/ai-debate:review-status               # 큐 / 막힌 것 / 사람 대기 현황
```

---

## 🧩 무엇인가요

리뷰 워크스페이스는 **파일 기반 멀티에이전트 토론장**입니다. 에이전트들이 한 토픽에 대해
`topic.md` → `001_..._design.md` → `002_..._attack.md` → `003_..._rebuttal.md` → `decision.md`
문서를 주고받으며 서로의 주장을 **적대적으로 검증**하고, 합의된 결정을 사용자에게 전달합니다.
완성된 지식은 위키로 졸업하고, 진행 중 논쟁은 워크스페이스에 남습니다. 기본 폴더 `llm_wiki/ai_debate/`(설정 가능, 코디네이터는 폴더명 독립).

상태는 토픽별 `status.json`이 관리합니다: `status`, `owner`(claude/codex/human), `next_action`,
`current_doc`, `next_doc`, `auto`, `allow_code_change`, `priority` 등.

---

## 🗂 명령 / 스킬

| 명령 | 설명 |
|---|---|
| `/ai-debate:review-init [dir]` | 현재 레포에 워크스페이스·스크립트·템플릿·규칙 셋업 |
| `/ai-debate:review-new <slug> [priority]` | 새 토픽(topic.md + status.json) 생성 |
| `/ai-debate:review-run [--watch ...]` | 코디네이터 실행 (status.json owner 기준 Claude/Codex 호출, 역할별 프롬프트) |
| `/ai-debate:review-wait <topic> [--until-...]` | 리뷰 진전까지 백그라운드 대기 → 자동 재개 |
| `/ai-debate:review-status [topic]` | 큐/blocked/human 대기 요약 + 최근 활동 |

- **스킬 `ai-debate:ai-debate`** — 워크플로 규칙(HARD RULE), 라운드 역할, 구조화 findings + 적대적 검증, 자동재개 결정트리. "리뷰 진행"/"ai debate" 등에 자동 발동.

---

## 🎯 리뷰 품질 (역할 · findings · 평결)

각 라운드는 **역할**을 갖고, 리뷰어는 구조화된 `## Findings`(`id`/`severity`/`confidence`/`claim`/`evidence`/`refutable_by`)를 씁니다.

- **DESIGNER** — 설계 + 자가 비판(공격자 선제).
- **ATTACKER** — 가장 강하고 구체적인 반박, 봐주기 없음.
- **REBUTTER** — finding마다 평결: `CONFIRMED` / `PLAUSIBLE` / `REFUTED`(REFUTED는 구체 반례 필수).
- **JUDGE** — 생존한 finding(CONFIRMED + 근거 있는 PLAUSIBLE)만 채택, REFUTED 폐기.

이 **적대적 검증** 단계가 "그럴듯하지만 틀린" 결론을 최종 결정에서 걸러냅니다.

---

## 🔒 규칙 (HARD RULE)

- 다른 에이전트의 리뷰 라운드를 **대신 쓰지 않는다.** `status.json`이 `owner=<다른 에이전트>`면 멈추고 보고.
- 리뷰 문서 작성에 `codex:*` 스킬을 호출하지 않는다(Codex 라운드는 별도 codex 프로세스).
- 코드 변경은 `decision.md` 확정 + `allow_code_change=true` + 사람 승인 후에만.
- 커밋/푸시는 사용자가 명시적으로 요청할 때만.

---

## 🛡 코디네이터 안전장치

`run_auto.ps1 -Watch`는 무인 루프로, 토픽별 락을 잡고 owner의 CLI를 역할별 프롬프트로 호출 후 진전을 검증합니다. 강건화 포함:
- per-topic 타임아웃, 진전-정체 감지(→`owner=human` 에스컬레이션), 턴 단위 오류 격리(에이전트 실패해도 루프 생존), 단일 인스턴스 뮤텍스, JSONL 실행 로그.
- **scope guard** — worker가 워크스페이스 밖 파일을 바꾸면 경고+로그(record-first).
- `-ClaudeModel`/`-CodexModel`로 모델 고정(대화형 세션과 품질 패리티).

---

## 💻 플랫폼

- 현재 스크립트는 **PowerShell(Windows 우선)**, UTF-8 BOM으로 코드페이지 안전.
- **macOS/Linux 지원은 예정**(크로스플랫폼 포팅, 후순위). 그 전까지 비Windows 환경은 미지원.

---

## 📦 구조 / 라이선스

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

라이선스: **MIT**.

---

## English (summary)

**AI Debate Review** is a Claude Code plugin where multiple AI agents (Claude, Codex) debate and
adversarially verify a topic across structured rounds (design → attack → rebuttal → decision) and
deliver a reasoned decision. Install: `/plugin marketplace add https://github.com/Eivor79/ai-debate-plugin`
then `/plugin install ai-debate@ai-debate-tools` and restart Claude Code. Commands are namespaced
(`/ai-debate:review-*`). Each round has a role and writes structured findings; a rebuttal verdict
(`CONFIRMED`/`PLAUSIBLE`/`REFUTED`) gates what the decision adopts. Scripts are PowerShell (Windows-first);
macOS/Linux support is planned. License: MIT.
