param(
    [Parameter(Mandatory = $true)] [string] $Topic,   # review_bus topic folder name or full path
    [string] $UntilOwner = "",                          # exit when status.owner equals this (e.g. 'claude','human')
    [string] $UntilStatusLike = "",                     # exit when status.status -like matches (e.g. 'decided','ready_for_claude*')
    [string] $UntilDocExists = "",                      # exit when this file appears (e.g. 'decision.md','003_*.md')
    [int] $PollSeconds = 15,
    [int] $TimeoutMinutes = 180,
    [switch] $CheckOnce                                 # evaluate once (test) - exit 2 if not yet met
)

# review_bus review-completion watcher.
# Launch this with run_in_background from the waiting session. When the review
# advances (status.json owner/status changes, or a named doc appears), this exits
# and the harness re-invokes the launching session, which then reads the result
# and continues to the next step.
#
# Exit codes: 0 = condition met (review advanced) / 2 = timeout or CheckOnce not met / 1 = topic/status missing.

$ErrorActionPreference = "Stop"

$topicDir = if (Test-Path -LiteralPath $Topic -PathType Container) {
    (Resolve-Path -LiteralPath $Topic).Path
}
else {
    Join-Path $PSScriptRoot $Topic
}
$statusPath = Join-Path $topicDir "status.json"
if (-not (Test-Path -LiteralPath $statusPath)) {
    Write-Output "[wait_for_review] status.json not found: $statusPath"
    exit 1
}

function Read-Status {
    try { Get-Content -LiteralPath $statusPath -Raw -Encoding utf8 | ConvertFrom-Json }
    catch { $null }
}

function Get-Field($obj, $name) {
    if ($null -eq $obj) { return "" }
    $p = $obj.PSObject.Properties[$name]
    if ($null -eq $p) { return "" } else { return [string]$p.Value }
}

function Test-DocExists {
    if (-not $UntilDocExists) { return $false }
    return [bool](Get-ChildItem -LiteralPath $topicDir -Filter $UntilDocExists -File -ErrorAction SilentlyContinue)
}

# Start snapshot. With no explicit condition, "advanced" = owner/status/current_doc changed.
$start = Read-Status
$startOwner = Get-Field $start "owner"
$startStatus = Get-Field $start "status"
$startCurDoc = Get-Field $start "current_doc"
$hasExplicit = ($UntilOwner -or $UntilStatusLike -or $UntilDocExists)

function Test-Done {
    $s = Read-Status
    if ($null -eq $s) { return $null }   # transient read failure -> keep polling
    $owner = Get-Field $s "owner"
    $status = Get-Field $s "status"
    $curDoc = Get-Field $s "current_doc"

    $met = $false
    $why = ""
    if ($hasExplicit) {
        if ($UntilOwner -and $owner -eq $UntilOwner) { $met = $true; $why = "owner=$owner" }
        if ((-not $met) -and $UntilStatusLike -and ($status -like $UntilStatusLike)) { $met = $true; $why = "status=$status" }
        if ((-not $met) -and (Test-DocExists)) { $met = $true; $why = "doc '$UntilDocExists' exists" }
    }
    else {
        if ($owner -ne $startOwner) { $met = $true; $why = "owner $startOwner -> $owner" }
        elseif ($status -ne $startStatus) { $met = $true; $why = "status $startStatus -> $status" }
        elseif ($curDoc -ne $startCurDoc) { $met = $true; $why = "current_doc $startCurDoc -> $curDoc" }
    }
    if (-not $met) { return $null }

    $latest = Get-ChildItem -LiteralPath $topicDir -Filter "*.md" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    return [pscustomobject]@{
        topic = Split-Path $topicDir -Leaf
        why = $why
        owner = $owner
        status = $status
        current_doc = $curDoc
        next_action = (Get-Field $s "next_action")
        blocked_reason = (Get-Field $s "blocked_reason")
        latest_doc = if ($latest) { $latest.Name } else { "" }
    }
}

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ($true) {
    $done = Test-Done
    if ($null -ne $done) {
        Write-Output "[wait_for_review] DONE topic=$($done.topic) ($($done.why))"
        Write-Output ($done | ConvertTo-Json -Compress)
        Write-Output "NEXT: read latest_doc='$($done.latest_doc)' / status='$($done.status)' / next_action='$($done.next_action)' under $topicDir and continue."
        exit 0
    }
    if ($CheckOnce) { Write-Output "[wait_for_review] not yet (CheckOnce)"; exit 2 }
    if ((Get-Date) -gt $deadline) {
        Write-Output "[wait_for_review] TIMEOUT after $TimeoutMinutes min - topic=$Topic not advanced"
        exit 2
    }
    Start-Sleep -Seconds $PollSeconds
}
