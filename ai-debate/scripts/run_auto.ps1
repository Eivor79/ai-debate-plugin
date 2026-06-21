param(
    [string] $Root = $PSScriptRoot,
    [int] $MaxTurns = 20,
    [int] $SleepSeconds = 2,
    [int] $IdleSleepSeconds = 10,
    [int] $MaxIdlePolls = 0,
    [int] $LockTimeoutMinutes = 20,
    [int] $AgentTimeoutMinutes = 10,
    [int] $ProgressMaxAttempts = 2,
    [int] $WatchMaxActions = 0,
    [string] $ClaudeModel = "",
    [string] $CodexModel = "",
    [switch] $Once,
    [switch] $Watch,
    [switch] $EnableExisting,
    [switch] $DryRun
)

# Coordinate review_bus work across separate Claude and Codex CLIs.
# This script does not decide the review content itself; it only reads
# status.json, invokes the agent named by owner, and loops until the queue stops.

$ErrorActionPreference = "Stop"

try {
    chcp.com 65001 | Out-Null
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $PSDefaultParameterValues["Get-Content:Encoding"] = "utf8"
    $PSDefaultParameterValues["Set-Content:Encoding"] = "utf8"
    $PSDefaultParameterValues["Add-Content:Encoding"] = "utf8"
    $PSDefaultParameterValues["Out-File:Encoding"] = "utf8"
    $env:PYTHONUTF8 = "1"
    $env:PYTHONIOENCODING = "utf-8"
    $env:LANG = "ko_KR.UTF-8"
    $env:LC_ALL = "ko_KR.UTF-8"
}
catch {
    Write-Warning "[review_bus_auto] failed to force UTF-8 console encoding: $($_.Exception.Message)"
}

$QueueRoot = (Resolve-Path -LiteralPath $Root).Path
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $QueueRoot "..\..")).Path

$automatedOwners = @("claude", "codex")

# 이 코디네이터 인스턴스 식별자 (per-topic 락 소유자 표기)
$myId = "$env:COMPUTERNAME:$PID"

function Get-FieldValue {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-PriorityRank {
    param([string] $Priority)

    switch ($Priority) {
        "p0" { return 0 }
        "urgent" { return 0 }
        "p1" { return 1 }
        "high" { return 1 }
        "p2" { return 2 }
        "normal" { return 2 }
        "p3" { return 3 }
        "low" { return 3 }
        default { return 4 }
    }
}

function Test-ActionableStatus {
    param(
        [string] $Status,
        [string] $Owner
    )

    if ($Status -in @("ready_for_decision", "ready_for_implementation")) {
        return $true
    }

    if ($Owner -and $Status -like "ready_for_$Owner*") {
        return $true
    }

    return $false
}

function Get-ReviewBusQueue {
    param([string] $QueueRoot)

    Get-ChildItem -Path $QueueRoot -Directory |
        Where-Object { $_.Name -ne "_templates" } |
        ForEach-Object {
            $topicDir = $_
            $statusPath = Join-Path $topicDir.FullName "status.json"
            if (-not (Test-Path -LiteralPath $statusPath)) { return }

            try {
                $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
            }
            catch {
                [pscustomobject]@{
                    topic = $topicDir.Name
                    path = $topicDir.FullName
                    actionable = $false
                    owner = "human"
                    status = "blocked"
                    priority = "normal"
                    reason = "invalid status.json: $($_.Exception.Message)"
                }
                return
            }

            $owner = [string](Get-FieldValue -Object $status -Name "owner")
            $statusValue = [string](Get-FieldValue -Object $status -Name "status")
            $blockedReason = [string](Get-FieldValue -Object $status -Name "blocked_reason")
            $auto = [bool](Get-FieldValue -Object $status -Name "auto")
            $nextDoc = [string](Get-FieldValue -Object $status -Name "next_doc")
            $nextAction = [string](Get-FieldValue -Object $status -Name "next_action")
            $priority = [string](Get-FieldValue -Object $status -Name "priority")
            if (-not $priority) { $priority = "normal" }

            # per-topic 락: lock_owner 가 있고 lock_until 이 미래면 활성. 다른 소유자면 스킵.
            # 만료된 락(lock_until 과거)은 회수 대상 → 차단하지 않음(claim 시 덮어씀).
            $lockOwner = [string](Get-FieldValue -Object $status -Name "lock_owner")
            $lockUntil = [string](Get-FieldValue -Object $status -Name "lock_until")
            $lockedByOther = $false
            if (-not [string]::IsNullOrWhiteSpace($lockOwner)) {
                $parsedUntil = [datetime]::MinValue
                $lockLive = $true   # 파싱 불가 + 소유자 존재 시 보수적으로 활성 취급
                if ([datetime]::TryParse($lockUntil, [ref]$parsedUntil)) {
                    $lockLive = ($parsedUntil -gt (Get-Date))
                }
                $lockedByOther = $lockLive -and ($lockOwner -ne $myId)
            }

            $warnings = New-Object System.Collections.Generic.List[string]
            if ($nextDoc -and (Test-Path -LiteralPath (Join-Path $topicDir.FullName $nextDoc))) {
                $warnings.Add("next_doc already exists")
            }
            # required 필드 결손 status.json은 actionable에서 제외. 누락 시 Lock-Topic의
            # update_status 가 throw → 무인 루프가 죽는 것을 사전 차단(invoke 전 게이트).
            foreach ($req in @("status", "owner", "next_action", "current_doc", "auto", "allow_code_change", "updated_at")) {
                if ($null -eq $status.PSObject.Properties[$req]) {
                    $warnings.Add("missing required field: $req")
                }
            }

            $isEligible = (
                ($automatedOwners -contains $owner) -and
                (Test-ActionableStatus -Status $statusValue -Owner $owner) -and
                [string]::IsNullOrWhiteSpace($blockedReason) -and
                (-not $lockedByOther) -and
                ($warnings.Count -eq 0)
            )

            $isActionable = $isEligible -and ($auto -or $EnableExisting)

            [pscustomobject]@{
                topic = $topicDir.Name
                path = $topicDir.FullName
                actionable = $isActionable
                auto = $auto
                owner = $owner
                status = $statusValue
                next_action = $nextAction
                current_doc = [string](Get-FieldValue -Object $status -Name "current_doc")
                next_doc = $nextDoc
                priority = $priority
                priority_rank = Get-PriorityRank -Priority $priority
                reason = if ($warnings.Count -gt 0) { ($warnings -join "; ") } else { $blockedReason }
            }
        } |
        Sort-Object @{ Expression = "actionable"; Descending = $true }, priority_rank, topic
}

function Get-SessionAutoOverride {
    # -EnableExisting 로 auto=false 토픽을 처리할 때, 과거에는 status.json에
    # auto=true 를 영구 기록해 다음 무인 -Watch 실행에서도 그 토픽이 계속
    # 자동 처리되는 부작용이 있었다. 디스크에는 쓰지 않고, 이번 프로세스
    # 실행(turn) 한정으로만 워커 prompt에 "이번 턴은 허용됨"을 알린다.
    param([Parameter(Mandatory = $true)] $Item)

    if ($Item.auto) { return $false }
    if (-not $EnableExisting) { return $false }

    Write-Warning "[review_bus_auto] EnableExisting session-only override for topic=$($Item.topic) (auto=false stays on disk)"
    return $true
}

function Set-TopicBlocked {
    param(
        [Parameter(Mandatory = $true)] $Item,
        [Parameter(Mandatory = $true)] [string] $Reason
    )

    if ($DryRun) {
        Write-Host "[dry-run] would block $($Item.topic): $Reason"
        return
    }

    # owner=human 전환은 무인 -Watch 루프가 사람 개입을 기다리는 지점이므로
    # 콘솔에 눈에 띄게 경고 + 영속 로그에 human_handoff 로 기록한다.
    Write-Warning "[review_bus_auto] HUMAN HANDOFF: topic=$($Item.topic) reason=$Reason"
    Write-RunLog -Topic $Item.topic -Owner $Item.owner -Action $Item.next_action -Result "human_handoff" -ResultDoc $Reason

    $updateScript = Join-Path $QueueRoot "update_status.ps1"
    & $updateScript -TopicDir $Item.path -Set @{
        status = "blocked"
        owner = "human"
        blocked_reason = $Reason
    } -Force
}

function Lock-Topic {
    param([Parameter(Mandatory = $true)] $Item)

    if ($DryRun) {
        Write-Host "[dry-run] would lock $($Item.topic) as $myId"
        return
    }
    $until = (Get-Date).AddMinutes($LockTimeoutMinutes).ToString("yyyy-MM-ddTHH:mm:ss")
    $updateScript = Join-Path $QueueRoot "update_status.ps1"
    & $updateScript -TopicDir $Item.path -Set @{ lock_owner = $myId; lock_until = $until } -Force | Out-Null
}

function Unlock-Topic {
    param([Parameter(Mandatory = $true)] $Item)

    if ($DryRun) { return }
    # 현재 status.json(에이전트가 갱신했을 수 있음)에 병합 → 락만 해제, 진행상태 보존.
    $updateScript = Join-Path $QueueRoot "update_status.ps1"
    & $updateScript -TopicDir $Item.path -Set @{ lock_owner = ""; lock_until = "" } -Force | Out-Null
}

function Write-RunLog {
    # 영속 실행로그: run_auto.log.jsonl 에 매 invoke/판정마다 한 줄 append (UTF-8, no BOM).
    param(
        [Parameter(Mandatory = $true)] [string] $Topic,
        [string] $Owner = "",
        [string] $Action = "",
        [Parameter(Mandatory = $true)] [string] $Result,
        [double] $DurationSeconds = 0,
        [string] $ResultDoc = ""
    )

    if ($DryRun) { return }

    $logPath = Join-Path $QueueRoot "run_auto.log.jsonl"
    $entry = [ordered]@{
        ts = (Get-Date).ToString("o")
        topic = $Topic
        owner = $Owner
        action = $Action
        result = $Result
        duration_s = [math]::Round($DurationSeconds, 2)
        result_doc = $ResultDoc
    }
    try {
        $line = ($entry | ConvertTo-Json -Compress)
        [System.IO.File]::AppendAllText($logPath, $line + "`n", [System.Text.UTF8Encoding]::new($false))
    }
    catch {
        Write-Warning "[review_bus_auto] failed to write run log: $($_.Exception.Message)"
    }
}

function Get-TopicStatusSignature {
    param([Parameter(Mandatory = $true)] $Item)

    $statusPath = Join-Path $Item.path "status.json"
    try {
        $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }

    $nextDoc = [string](Get-FieldValue -Object $status -Name "next_doc")
    $nextDocExists = [bool]($nextDoc -and (Test-Path -LiteralPath (Join-Path $Item.path $nextDoc)))

    [pscustomobject]@{
        status = [string](Get-FieldValue -Object $status -Name "status")
        owner = [string](Get-FieldValue -Object $status -Name "owner")
        current_doc = [string](Get-FieldValue -Object $status -Name "current_doc")
        next_doc = $nextDoc
        next_doc_exists = $nextDocExists
    }
}

function Test-ProgressOrBlock {
    # exit 0 인데 next_doc 미생성/status 불변이면 같은 step 무한재호출 방지.
    # K회(ProgressMaxAttempts) 연속 무진전이면 owner=human 으로 차단.
    param(
        [Parameter(Mandatory = $true)] $Item,
        $PreSnapshot
    )

    if ($null -eq $PreSnapshot) { return }

    $post = Get-TopicStatusSignature -Item $Item
    if ($null -eq $post) { return }

    $updateScript = Join-Path $QueueRoot "update_status.ps1"
    $signature = "$($PreSnapshot.current_doc)|$($PreSnapshot.status)|$($PreSnapshot.next_doc)"

    # 상태(status/owner/current_doc/next_doc) 전진이 진짜 진전. next_doc_exists 단독은 제외.
    $stateAdvanced = (
        $post.status -ne $PreSnapshot.status -or
        $post.owner -ne $PreSnapshot.owner -or
        $post.current_doc -ne $PreSnapshot.current_doc -or
        $post.next_doc -ne $PreSnapshot.next_doc
    )

    if ($stateAdvanced) {
        try {
            & $updateScript -TopicDir $Item.path -Set @{ progress_signature = ""; progress_attempts = 0 } -Force | Out-Null
        }
        catch { }
        return
    }

    # 상태는 그대로인데 next_doc 파일만 새로 생긴 경우: 다음 폴에서 'next_doc already exists'로
    # non-actionable 처리되어 조용히 큐에서 빠진다(차단도 진전도 아님). 즉시 human 에스컬레이션.
    if ($post.next_doc_exists -and (-not $PreSnapshot.next_doc_exists)) {
        Write-Warning "[review_bus_auto] topic=$($Item.topic) wrote next_doc '$($post.next_doc)' but did not advance status — escalating to human"
        Write-RunLog -Topic $Item.topic -Owner $Item.owner -Action $Item.next_action -Result "doc_without_state" -ResultDoc $post.next_doc
        Set-TopicBlocked -Item $Item -Reason "next_doc '$($post.next_doc)' written but status not advanced"
        return
    }

    $rawStatus = Get-Content -LiteralPath (Join-Path $Item.path "status.json") -Raw | ConvertFrom-Json
    $priorSig = [string](Get-FieldValue -Object $rawStatus -Name "progress_signature")
    $priorAttempts = 0
    [void][int]::TryParse([string](Get-FieldValue -Object $rawStatus -Name "progress_attempts"), [ref]$priorAttempts)
    if ($priorSig -ne $signature) { $priorAttempts = 0 }
    $attempts = $priorAttempts + 1

    Write-Warning "[review_bus_auto] no progress for topic=$($Item.topic) step=$signature attempt=$attempts/$ProgressMaxAttempts"
    Write-RunLog -Topic $Item.topic -Owner $Item.owner -Action $Item.next_action -Result "no_progress" -ResultDoc $signature

    if ($attempts -ge $ProgressMaxAttempts) {
        Set-TopicBlocked -Item $Item -Reason "no progress after $attempts attempts at step: $signature"
        return
    }

    try {
        & $updateScript -TopicDir $Item.path -Set @{ progress_signature = $signature; progress_attempts = $attempts } -Force | Out-Null
    }
    catch { }
}

function Test-NewDocEncoding {
    # 신규 생성 .md (next_doc/decision.md)가 UTF-16 BOM 이나 깨진 UTF-8 바이트 시퀀스로
    # 저장되지 않았는지 1차 검증. 위반 시 사람이 읽을 수 없는 문서가 위키에 들어가는 것을 막는다.
    # Since 이후 수정된 파일만 검사 → 이번 턴과 무관한 기존 decision.md 오탐 방지.
    param(
        [Parameter(Mandatory = $true)] $Item,
        [datetime] $Since = [datetime]::MinValue
    )

    $candidates = @()
    if ($Item.next_doc) {
        $p = Join-Path $Item.path $Item.next_doc
        if (Test-Path -LiteralPath $p) { $candidates += $p }
    }
    $decisionPath = Join-Path $Item.path "decision.md"
    if (Test-Path -LiteralPath $decisionPath) { $candidates += $decisionPath }

    foreach ($path in ($candidates | Select-Object -Unique)) {
        if ((Get-Item -LiteralPath $path).LastWriteTime -lt $Since) { continue }
        try {
            $bytes = [System.IO.File]::ReadAllBytes($path)
        }
        catch { continue }

        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            return "UTF-16LE BOM detected in $([System.IO.Path]::GetFileName($path))"
        }
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            return "UTF-16BE BOM detected in $([System.IO.Path]::GetFileName($path))"
        }

        try {
            $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
            [void]$strictUtf8.GetString($bytes)
        }
        catch {
            return "invalid UTF-8 byte sequence in $([System.IO.Path]::GetFileName($path))"
        }
    }

    return $null
}

function Get-GitChangeSet {
    # RepoRoot의 git 변경 파일 집합(porcelain) 반환. git repo가 아니거나 git 미설치면 $null.
    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    try {
        $out = & git -C $RepoRoot status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
    }
    catch { return $null }
    $set = @{}
    foreach ($line in @($out)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -le 3) { continue }
        $p = $line.Substring(3).Trim().Trim('"')
        if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1].Trim().Trim('"') }   # rename: new path
        $set[$p] = $true
    }
    return $set
}

function Test-ScopeGuard {
    # A1 보안 가드(review_bus dogfood decision): worker 실행 후 워크스페이스 폴더 밖 변경을
    # 탐지해 warn+log 한다. record-first — 차단/롤백은 하지 않는다(오탐 관측 후 승격).
    # 목적: 자동수락(acceptEdits)+workspace-write 권한이 debate 폴더 밖(코드 등)을 건드린 걸 가시화.
    param(
        [Parameter(Mandatory = $true)] $Item,
        $PreChanges
    )
    if ($null -eq $PreChanges) { return }   # git repo 아님 → 스킵
    $post = Get-GitChangeSet
    if ($null -eq $post) { return }

    $wsRel = $QueueRoot
    if ($wsRel.StartsWith($RepoRoot)) { $wsRel = $wsRel.Substring($RepoRoot.Length) }
    $wsRel = $wsRel.TrimStart('\', '/').Replace('\', '/')

    $outOfScope = @()
    foreach ($p in $post.Keys) {
        if ($PreChanges.ContainsKey($p)) { continue }   # 이전부터 있던 변경 제외 (worker가 만든 것만)
        $norm = $p.Replace('\', '/')
        if ($norm -eq $wsRel -or $norm.StartsWith($wsRel + '/')) { continue }   # 워크스페이스 안 = 정상
        $outOfScope += $norm
    }
    if ($outOfScope.Count -gt 0) {
        $list = ($outOfScope -join ', ')
        Write-Warning "[review_bus_auto] SCOPE: topic=$($Item.topic) worker가 워크스페이스 밖 파일 변경: $list (record-only)"
        Write-RunLog -Topic $Item.topic -Owner $Item.owner -Action $Item.next_action -Result "out_of_scope_change" -ResultDoc $list
    }
}

function Invoke-AgentWithTimeout {
    param(
        [Parameter(Mandatory = $true)] $Item,
        [Parameter(Mandatory = $true)] [string] $Exe,
        [string[]] $Arguments = @(),
        [Parameter(Mandatory = $true)] [string] $Prompt,
        [Parameter(Mandatory = $true)] [string] $Label
    )

    # claude/codex 는 npm .ps1 셸이라 Start-Process로 직접 못 띄움.
    # 자식 powershell 안에서 기존 `<prompt> | & claude ...` 파이프를 재현하면
    # .ps1 셸의 stdin forward(ExpectingInput)가 보존되고, 자식 PID를 잡아
    # taskkill /T 로 node 자식까지 트리 종료할 수 있다. native exit code는
    # `exit $LASTEXITCODE` 로 부모가 회수한다.
    $startedAt = Get-Date

    if ($null -eq (Get-Command $Exe -ErrorAction SilentlyContinue)) {
        $reason = "$Label CLI not found on PATH: $Exe"
        Write-RunLog -Topic $Item.topic -Owner $Item.owner -Action $Item.next_action -Result "cli_missing"
        Set-TopicBlocked -Item $Item -Reason $reason
        throw $reason
    }

    $argString = ($Arguments | ForEach-Object {
            if ($_ -match '\s') { "'" + ($_ -replace "'", "''") + "'" } else { $_ }
        }) -join ' '

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmp, $Prompt, [System.Text.UTF8Encoding]::new($false))

        $inner = "Get-Content -Raw -Encoding utf8 -LiteralPath '$tmp' | & $Exe $argString; exit `$LASTEXITCODE"
        $proc = Start-Process powershell.exe `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $inner) `
            -NoNewWindow -PassThru

        if ($AgentTimeoutMinutes -gt 0) {
            $proc | Wait-Process -Timeout ($AgentTimeoutMinutes * 60) -ErrorAction SilentlyContinue
        }
        else {
            # 0/음수 = 타임아웃 비활성(무인 운영에선 권장하지 않음). 한 번 경고하고 무한 대기.
            Write-Warning "[review_bus_auto] AgentTimeoutMinutes<=0 — timeout disabled for $Label (will wait indefinitely)"
            $proc | Wait-Process -ErrorAction SilentlyContinue
        }
        if (-not $proc.HasExited) {
            try { & taskkill /PID $proc.Id /T /F 2>&1 | Out-Null } catch { }
            $reason = "$Label timed out after $AgentTimeoutMinutes min — process tree killed"
            Write-RunLog -Topic $Item.topic -Owner $Item.owner -Action $Item.next_action -Result "timeout" -DurationSeconds ((Get-Date) - $startedAt).TotalSeconds
            Set-TopicBlocked -Item $Item -Reason $reason
            throw $reason
        }

        $exitCode = $proc.ExitCode
        if ($null -eq $exitCode) { $exitCode = 0 }
        if ($exitCode -ne 0) {
            $reason = "$Label exited with code $exitCode"
            Write-RunLog -Topic $Item.topic -Owner $Item.owner -Action $Item.next_action -Result "nonzero" -DurationSeconds ((Get-Date) - $startedAt).TotalSeconds
            Set-TopicBlocked -Item $Item -Reason $reason
            throw $reason
        }

        Write-RunLog -Topic $Item.topic -Owner $Item.owner -Action $Item.next_action -Result "ok" -DurationSeconds ((Get-Date) - $startedAt).TotalSeconds -ResultDoc $Item.next_doc
    }
    finally {
        if (Test-Path -LiteralPath $tmp) { [System.IO.File]::Delete($tmp) }
    }
}

function Get-CodexExecArgs {
    param([string] $Model = "")

    # $args 는 PowerShell 자동변수라 섀도잉 회피 위해 $cargs 사용.
    $cargs = @("exec", "--cd", $RepoRoot, "--sandbox", "workspace-write")
    if ($Model) { $cargs += @("--model", $Model) }
    $cargs += "-"
    return $cargs
}

function New-AgentPrompt {
    param(
        [Parameter(Mandatory = $true)] $Item,
        [Parameter(Mandatory = $true)] [string] $Agent,
        [bool] $AutoOverride = $false
    )

    $rootPath = $RepoRoot
    $topicPath = (Resolve-Path -LiteralPath $Item.path).Path
    $autoLine = if ($AutoOverride) {
        "Act because the coordinator explicitly enabled this run for this session (-EnableExisting override). status.json on disk may still show auto=false on purpose (the override is session-only and is not persisted) -- do not set auto=true yourself. Still require owner=$Agent and an actionable status before proceeding."
    }
    else {
        "Act only if status.json still has auto=true, owner=$Agent, and status is actionable."
    }

    # Review-quality levers: detect the round role from next_doc/next_action and inject
    # role-specific guidance + a structured findings schema + adversarial verification rules.
    $nd = "$($Item.next_doc)".ToLower()
    $na = "$($Item.next_action)".ToLower()
    $role =
        if ($nd -match 'design' -or $na -match 'design') { 'designer' }
        elseif ($nd -match 'attack' -or $na -match 'attack') { 'attacker' }
        elseif ($nd -match 'rebuttal' -or $na -match 'rebut') { 'rebutter' }
        elseif ($nd -match 'decision' -or $na -match 'decision' -or $na -match 'decide') { 'judge' }
        else { 'generic' }

    $findingsSchema = (@(
            'Structured findings -- include a "## Findings" section; for EACH issue, one block:',
            '  - id: F1 (then F2, F3, ...)',
            '  - severity: high | medium | low',
            '  - confidence: high | medium | low',
            '  - claim: one falsifiable sentence',
            '  - evidence: concrete file:line, data, quote, or repro (no hand-waving)',
            '  - refutable_by: the specific observation that would disprove the claim'
        ) -join "`n")

    $roleLines = switch ($role) {
        'designer' { @(
                'ROLE: DESIGNER. Write the design (target files, signatures, data flow, edge cases).',
                'Then add a "## Self-critique" section that adversarially lists the strongest objections',
                'to YOUR OWN design (correctness, feasibility, measurement validity), using the schema below.',
                $findingsSchema) }
        'attacker' { @(
                'ROLE: ATTACKER (adversarial reviewer). Find the strongest, most concrete refutations of the',
                'current design/claim. Priority: correctness > feasibility > measurement validity > scope.',
                'Do not soften to be agreeable. Output every issue with the schema below:',
                $findingsSchema,
                'End with the single most likely reason this design fails in practice.') }
        'rebutter' { @(
                'ROLE: REBUTTER. For EACH finding from the latest attack round, assign a verdict + reason:',
                '  - CONFIRMED: real; concede it and state the fix or scope change.',
                '  - PLAUSIBLE: real under a realistic condition you name; keep with caveats.',
                '  - REFUTED: provably wrong; you MUST cite the concrete code/data that disproves it.',
                'Do not mark REFUTED without a constructible counter. Carry the schema fields forward.') }
        'judge' { @(
                'ROLE: JUDGE. Write decision.md. Weigh only findings that SURVIVED verification:',
                'adopt CONFIRMED findings and well-evidenced PLAUSIBLE ones; drop REFUTED.',
                'State: adopted findings (by id), the decision (adopt/reject/revise + scope), the rationale,',
                'residual risks, and the next concrete step. No new arguments -- decide.') }
        default { @() }
    }
    $roleBlock = if ($roleLines.Count -gt 0) { "Round role and review-quality rules:`n" + ($roleLines -join "`n") } else { "" }

    @"
You are running as the $Agent worker for the review automation loop.

Repository root: $rootPath
Topic directory: $topicPath

Required startup:
1. Read $rootPath\LLM_SHARED.md (if present).
2. Read the wiki index under $rootPath (if present).
3. Read $QueueRoot\README.md (the review workspace rules).
4. Read $QueueRoot\index.md.
5. Read the topic status.json, topic.md, current_doc, and latest relevant numbered docs.

Encoding/logging rule:
- On Windows PowerShell, read repository markdown/json files with explicit UTF-8, for example `Get-Content -Encoding utf8 -LiteralPath <path>`.
- Do not print long raw excerpts from Korean markdown files to stdout. Summarize what you read instead, and write new/updated files as UTF-8.
- If terminal output appears as mojibake, stop the current turn and set `blocked_reason` instead of continuing to generate unreadable logs.

$autoLine

Current queue item:
- status: $($Item.status)
- next_action: $($Item.next_action)
- current_doc: $($Item.current_doc)
- next_doc: $($Item.next_doc)

Do the requested review_bus step end to end:
- For document-only review/rebuttal/design/decision steps, write the expected next_doc or decision.md.
- Update the topic status.json to the next owner/status/action/doc.
- Update the review index.md in $QueueRoot if the visible current doc or next request changed.
- Append a concise dated line to the wiki log under $rootPath when durable review/wiki state changes.

$roleBlock

Safety:
- Keep changes limited to review_bus/wiki metadata unless status.json explicitly allows code change.
- If code changes are requested, require allow_code_change=true, non-empty touches_paths, and an existing decision.md.
- Do not edit trading/order/account paths unless the existing topic explicitly records human approval.
- If you cannot proceed safely, set blocked_reason and owner=human in status.json.

When finished, stop. Do not wait for user input.
"@
}

function Invoke-ClaudeWorker {
    param(
        [Parameter(Mandatory = $true)] $Item,
        [bool] $AutoOverride = $false
    )

    $prompt = New-AgentPrompt -Item $Item -Agent "claude" -AutoOverride $AutoOverride
    if ($DryRun) {
        Write-Host "[dry-run] claude would handle $($Item.topic) -> $($Item.next_doc)"
        return
    }

    $claudeArgs = @("--print", "--permission-mode", "acceptEdits", "--output-format", "text")
    if ($ClaudeModel) { $claudeArgs += @("--model", $ClaudeModel) }

    Invoke-AgentWithTimeout -Item $Item -Exe "claude" `
        -Arguments $claudeArgs -Prompt $prompt -Label "claude"
}

function Invoke-CodexWorker {
    param(
        [Parameter(Mandatory = $true)] $Item,
        [bool] $AutoOverride = $false
    )

    $prompt = New-AgentPrompt -Item $Item -Agent "codex" -AutoOverride $AutoOverride
    if ($DryRun) {
        Write-Host "[dry-run] codex would handle $($Item.topic) -> $($Item.next_doc)"
        return
    }

    Invoke-AgentWithTimeout -Item $Item -Exe "codex" `
        -Arguments (Get-CodexExecArgs -Model $CodexModel) -Prompt $prompt -Label "codex"
}

# 단일 인스턴스 가드: watcher 중복 기동 시 같은 토픽을 두 에이전트가 잡는 레이스 차단.
# Global\ 접두로 같은 사용자의 교차 세션(스케줄 세션 vs 대화형) 중복기동까지 차단.
$mutex = New-Object System.Threading.Mutex($false, "Global\review_bus_auto_coordinator")
$haveMutex = $false
try {
    try {
        $haveMutex = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $haveMutex = $true   # 직전 보유 인스턴스가 비정상 종료 → 회수
    }
    if (-not $haveMutex) {
        Write-Warning "[review_bus_auto] another coordinator instance is already running (mutex held) — exiting"
        return
    }

    # -Watch 무인루프는 MaxTurns(기본 20)에 묶이지 않는다(예전엔 20턴마다 watcher가
    # 죽었다). WatchMaxActions(기본 0=무제한)로만 별도 행동 상한을 둘 수 있다.
    # 비-watch(-Once 등)는 기존처럼 MaxTurns로 제한.
    $turn = 0
    $idlePolls = 0
    while ($Watch -or ($turn -lt $MaxTurns)) {
        if ($Watch -and $WatchMaxActions -gt 0 -and $turn -ge $WatchMaxActions) {
            Write-Host "[review_bus_auto] stopped after WatchMaxActions=$WatchMaxActions"
            break
        }

        $queue = @(Get-ReviewBusQueue -QueueRoot $QueueRoot)
        $item = $queue | Where-Object { $_.actionable } | Select-Object -First 1

        if ($null -eq $item) {
            Write-Host "[review_bus_auto] no actionable automated item"
            if (-not $Watch) { break }

            $idlePolls += 1
            if ($MaxIdlePolls -gt 0 -and $idlePolls -ge $MaxIdlePolls) {
                Write-Host "[review_bus_auto] stopped after MaxIdlePolls=$MaxIdlePolls"
                break
            }

            if ($IdleSleepSeconds -gt 0) { Start-Sleep -Seconds $IdleSleepSeconds }
            continue
        }

        $idlePolls = 0
        $turn += 1
        $turnLimitLabel = if ($Watch) { if ($WatchMaxActions -gt 0) { "$WatchMaxActions" } else { "unlimited" } } else { "$MaxTurns" }
        Write-Host "[review_bus_auto] turn $turn/$turnLimitLabel owner=$($item.owner) topic=$($item.topic) action=$($item.next_action) next=$($item.next_doc)"

        # 무제한 -Watch 폭주 가시화: 50액션마다 하트비트 경고.
        if ($Watch -and $WatchMaxActions -le 0 -and ($turn % 50 -eq 0)) {
            Write-Warning "[review_bus_auto] heartbeat: $turn actions processed in unlimited -Watch mode"
        }

        $autoOverride = Get-SessionAutoOverride -Item $item
        $turnStart = Get-Date
        $preChanges = if (-not $DryRun) { Get-GitChangeSet } else { $null }   # A1 scope guard 기준선

        # 턴 단위 throw(에이전트 timeout/nonzero, Lock 실패, 예기치 못한 오류)를 잡아
        # 무인 watcher를 죽이지 않고 다음 토픽으로 계속한다. block 대상은 이미 처리됨.
        try {
            # per-topic 락 claim → invoke → 반드시 해제 (크래시/throw 시에도 finally 에서 해제)
            Lock-Topic -Item $item
            try {
                $preSnapshot = if (-not $DryRun) { Get-TopicStatusSignature -Item $item } else { $null }
                switch ($item.owner) {
                    "claude" { Invoke-ClaudeWorker -Item $item -AutoOverride $autoOverride }
                    "codex" { Invoke-CodexWorker -Item $item -AutoOverride $autoOverride }
                    default { throw "unsupported owner: $($item.owner)" }
                }
                if (-not $DryRun) {
                    Test-ProgressOrBlock -Item $item -PreSnapshot $preSnapshot
                    $encodingIssue = Test-NewDocEncoding -Item $item -Since $turnStart
                    if ($encodingIssue) {
                        Set-TopicBlocked -Item $item -Reason "generated doc encoding check failed: $encodingIssue"
                    }
                    Test-ScopeGuard -Item $item -PreChanges $preChanges
                }
            }
            finally {
                Unlock-Topic -Item $item
            }
        }
        catch {
            Write-Warning "[review_bus_auto] turn error topic=$($item.topic): $($_.Exception.Message)"
            try { Write-RunLog -Topic $item.topic -Owner $item.owner -Action $item.next_action -Result "turn_error" -ResultDoc $_.Exception.Message } catch { }
        }

        if ($Once) { break }
        if ($SleepSeconds -gt 0) { Start-Sleep -Seconds $SleepSeconds }
    }

    if ((-not $Watch) -and ($turn -ge $MaxTurns)) {
        Write-Warning "[review_bus_auto] stopped after MaxTurns=$MaxTurns"
    }
}
finally {
    if ($haveMutex) {
        try { $mutex.ReleaseMutex() } catch { }
    }
    $mutex.Dispose()
}
