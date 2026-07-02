# Review Bus 운영 규칙

여러 에이전트(Claude, Codex)가 같은 주제를 **파일 기반으로 주고받으며 적대적으로 검토**하기 위한 공통 규칙입니다.

> **환경**: git / 비-git 프로젝트 양쪽에서 동작합니다. `.gitignore` 같은 git 전용 단계는 git 저장소일 때만 적용됩니다.
>
> **기본 동작 = 자율-완주**: 토픽은 기본적으로 `auto=true`로 생성되어, `/review-run`만 돌리면 에이전트끼리 설계 → 공격 → 반박 → 결정(`decision.md`)까지 **자동으로 끝까지** 진행합니다. 사람 개입은 **코드 변경 승인**에서만 필요합니다(`allow_code_change=true`). 라운드별 사람 검토를 원하면 토픽을 `auto=false`로 두세요(`/review-new ... --manual`).

## 목적

`ai_debate/`는 완성 문서 저장소가 아니라 **토론 및 리뷰 작업 공간**입니다. 실제 소스 코드 수정은 이 프로세스에 포함되지 않으며, 문서(md)를 통한 분석과 합의만 진행합니다: 설계(Design) → 공격/감사(Attack/Audit) → 반박(Rebuttal) → 결정(Decision).

최종 정리된 지식은 `wiki/`에, 진행 중 논쟁은 `ai_debate/`에 남깁니다.

## HARD RULE

- **다른 에이전트의 리뷰 라운드를 대신 작성하지 않는다.** `status.json`의 `owner`가 다른 에이전트면 멈추고 사용자에게 보고한다.
  - *유일한 공인 예외 — 코디네이터 solo 폴백*: codex CLI가 없으면 코디네이터(`run_auto.ps1`, 자동감지 또는 `-SoloClaude`)가 codex 라운드를 claude CLI로 대행할 수 있다. 이때 문서에 provenance 라인(`> executed_by: claude (solo fallback for codex)`)을 남긴다. 대화형 세션이 수동으로 대필하는 것은 여전히 금지.
- ai_debate 문서 작성에 `codex:*` 스킬을 호출하지 않는다. Codex 라운드는 별도 Codex 프로세스(코디네이터의 `codex exec` 또는 사용자 Codex 세션)에서 나온다.
- `decision.md` 확정 + `allow_code_change=true` + 사람 승인 전에는 코드 변경 금지.
- 커밋/푸시/실제 PR 생성은 사용자가 명시적으로 요청할 때만.

## 폴더/파일 규칙

```text
ai_debate/
  README.md            # 이 규칙
  index.md             # 주제 인덱스
  _templates/          # status/topic 템플릿 + 스키마
  run_auto.ps1         # 코디네이터
  wait_for_review.ps1  # 리뷰 완료 감시자(블록-후-자동재개)
  update_status.ps1    # status.json 원자적 갱신
  scan_queue.ps1       # 큐/락 점검
  <YYYY-MM-DD>_<slug>/
    topic.md
    001_<agent>_design.md
    002_<other>_attack_round1.md
    003_<agent>_rebuttal_round1.md
    decision.md
    status.json
```

문서 번호는 `001_`, `002_`, ... 순서로 증가하고, 파일명은 `<agent>_<round>` 형식을 따릅니다.

## status.json 상태 머신

`_templates/status.schema.md` 참조. 코디네이터(`run_auto.ps1`)는 `owner`가 자동 에이전트(claude/codex)이고 status가 actionable(`ready_for_decision`/`ready_for_implementation`/`ready_for_<owner>*`)이며 `auto=true`(또는 `-EnableExisting`)인 토픽만 처리합니다. 신규 토픽은 기본 `auto=true`라 별도 토글 없이 바로 자율 진행됩니다. `owner=human`은 사람 개입 대기로, **진짜 차단**(에러/무진전/인코딩 실패/코드변경 승인)에서만 설정되며 — 자율-완주의 정상 종착점입니다.

비-git 프로젝트에서 `RepoRoot`(에이전트 프롬프트의 "Repository root", codex `--cd`)는 git toplevel 대신 워크스페이스 기준으로 자동 해석됩니다. 레이아웃이 특수하면 `run_auto.ps1 -RepoRoot <경로>`로 명시할 수 있습니다.

## 요청 문구

사용자가 `pr 진행`, `리뷰 진행` 등으로 요청하면 `ai_debate/`의 해당 주제 작업을 `status.json` 기준으로 이어서 진행한다는 뜻입니다.
