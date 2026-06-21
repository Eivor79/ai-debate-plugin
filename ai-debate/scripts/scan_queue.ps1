param(
    [string]$Root = $PSScriptRoot,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$actionableStatuses = @(
    "ready_for_codex",
    "ready_for_decision",
    "ready_for_implementation"
)

$requiredFields = @(
    "status",
    "owner",
    "next_action",
    "current_doc",
    "auto",
    "allow_code_change",
    "updated_at"
)

function Get-FieldValue {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

$items = Get-ChildItem -Path $Root -Directory |
    Where-Object { $_.Name -ne "_templates" } |
    ForEach-Object {
        $topicDir = $_
        $statusPath = Join-Path $topicDir.FullName "status.json"

        if (-not (Test-Path -LiteralPath $statusPath)) {
            [pscustomobject]@{
                topic = $topicDir.Name
                path = $topicDir.FullName
                has_status = $false
                actionable = $false
                status = ""
                owner = ""
                next_action = ""
                current_doc = ""
                next_doc = ""
                priority = ""
                allow_code_change = $false
                warnings = @("missing status.json")
            }
            return
        }

        $warnings = New-Object System.Collections.Generic.List[string]
        try {
            $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        }
        catch {
            [pscustomobject]@{
                topic = $topicDir.Name
                path = $topicDir.FullName
                has_status = $true
                actionable = $false
                status = ""
                owner = ""
                next_action = ""
                current_doc = ""
                next_doc = ""
                priority = ""
                allow_code_change = $false
                warnings = @("invalid JSON: $($_.Exception.Message)")
            }
            return
        }

        foreach ($field in $requiredFields) {
            if ($null -eq (Get-FieldValue -Object $status -Name $field)) {
                $warnings.Add("missing required field: $field")
            }
        }

        $blockedReason = Get-FieldValue -Object $status -Name "blocked_reason"
        $auto = [bool](Get-FieldValue -Object $status -Name "auto")
        $owner = [string](Get-FieldValue -Object $status -Name "owner")
        $statusValue = [string](Get-FieldValue -Object $status -Name "status")
        $allowCodeChange = [bool](Get-FieldValue -Object $status -Name "allow_code_change")
        $touchesPaths = Get-FieldValue -Object $status -Name "touches_paths"
        $nextDoc = [string](Get-FieldValue -Object $status -Name "next_doc")

        if ($allowCodeChange -and ($null -eq $touchesPaths -or $touchesPaths.Count -eq 0)) {
            $warnings.Add("allow_code_change=true but touches_paths is empty")
        }

        if ($nextDoc) {
            $nextDocPath = Join-Path $topicDir.FullName $nextDoc
            if (Test-Path -LiteralPath $nextDocPath) {
                $warnings.Add("next_doc already exists")
            }
        }

        $isActionable = (
            $auto -and
            $owner -eq "codex" -and
            $actionableStatuses -contains $statusValue -and
            [string]::IsNullOrWhiteSpace([string]$blockedReason)
        )

        $upgradeDocVal = [string](Get-FieldValue -Object $status -Name "upgrade_doc")
        $upgradeDocStatus = [string](Get-FieldValue -Object $status -Name "upgrade_doc_status")

        $classification = "other"
        if (-not [string]::IsNullOrWhiteSpace([string]$blockedReason)) {
            $classification = "blocked"
        }
        elseif ($isActionable) {
            $classification = "actionable"
        }
        elseif ($statusValue -eq "done") {
            if ($upgradeDocVal -and $upgradeDocStatus -ne "created") {
                $classification = "upgrade-doc-needed"
                $warnings.Add("upgrade_doc declared but status not 'created'")
            }
            elseif (-not $upgradeDocVal -and (Get-FieldValue -Object $status -Name "upgrade_doc") -eq $null) {
                $classification = "done"
            }
            else {
                $classification = "done"
            }
        }
        elseif ($statusValue) {
            $classification = $statusValue
        }

        # Race detection: lock_owner set but lock_until expired or empty
        $lockOwner = [string](Get-FieldValue -Object $status -Name "lock_owner")
        $lockUntil = [string](Get-FieldValue -Object $status -Name "lock_until")
        if ($lockOwner) {
            $expired = $false
            if (-not $lockUntil) {
                $expired = $true
            }
            else {
                try {
                    $lockUntilDt = [datetime]::Parse($lockUntil)
                    if ($lockUntilDt -lt (Get-Date)) { $expired = $true }
                }
                catch { $expired = $true }
            }
            if ($expired) {
                $warnings.Add("stale lock: lock_owner=$lockOwner lock_until=$lockUntil")
            }
        }

        [pscustomobject]@{
            topic = $topicDir.Name
            path = $topicDir.FullName
            has_status = $true
            actionable = $isActionable
            classification = $classification
            status = $statusValue
            owner = $owner
            next_action = [string](Get-FieldValue -Object $status -Name "next_action")
            current_doc = [string](Get-FieldValue -Object $status -Name "current_doc")
            next_doc = $nextDoc
            priority = [string](Get-FieldValue -Object $status -Name "priority")
            allow_code_change = $allowCodeChange
            upgrade_doc = $upgradeDocVal
            upgrade_doc_status = $upgradeDocStatus
            warnings = @($warnings)
        }
    } |
    Sort-Object @{ Expression = "actionable"; Descending = $true }, @{ Expression = {
        $order = @("actionable","upgrade-doc-needed","blocked","other","done")
        $idx = [array]::IndexOf($order, $_.classification)
        if ($idx -lt 0) { 99 } else { $idx }
    } }, priority, topic

if ($Json) {
    $items | ConvertTo-Json -Depth 5
}
else {
    $items |
        Select-Object classification, status, owner, next_action, topic, current_doc, next_doc, @{Name = "warnings"; Expression = { ($_.warnings -join "; ") } } |
        Format-Table -AutoSize
}
