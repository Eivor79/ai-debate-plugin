param(
    [Parameter(Mandatory = $true)] [string] $TopicDir,
    [Parameter(Mandatory = $true)] [hashtable] $Set,
    [switch] $Force
)

# Atomically update review_bus/<topic>/status.json:
#   1. Validates required fields are present in the result.
#   2. Refuses to overwrite if next_doc is named and the file already exists (collision).
#   3. Writes to status.json.tmp then renames over the original.
# On any failure, sets blocked_reason and owner=human and re-throws.

$ErrorActionPreference = "Stop"

$requiredFields = @(
    "status",
    "owner",
    "next_action",
    "current_doc",
    "auto",
    "allow_code_change",
    "updated_at"
)

if (-not (Test-Path -LiteralPath $TopicDir -PathType Container)) {
    throw "TopicDir not found: $TopicDir"
}

$statusPath = Join-Path $TopicDir "status.json"
if (-not (Test-Path -LiteralPath $statusPath)) {
    throw "status.json missing in $TopicDir"
}

$current = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
$merged = @{}
foreach ($prop in $current.PSObject.Properties) {
    $merged[$prop.Name] = $prop.Value
}
foreach ($key in $Set.Keys) {
    $merged[$key] = $Set[$key]
}
$merged["updated_at"] = (Get-Date).ToString("yyyy-MM-dd")

foreach ($field in $requiredFields) {
    if (-not $merged.ContainsKey($field) -or $null -eq $merged[$field]) {
        throw "missing required field after merge: $field"
    }
}

$nextDoc = [string]$merged["next_doc"]
if ($nextDoc -and -not $Force) {
    $nextDocPath = Join-Path $TopicDir $nextDoc
    if (Test-Path -LiteralPath $nextDocPath) {
        throw "next_doc already exists: $nextDocPath (use -Force to override)"
    }
}

# Number-collision check: if next_doc starts with NNN_, refuse if any NNN_*.md already in dir
if ($nextDoc -match '^(\d{3})_') {
    $prefix = $Matches[1] + "_"
    $existing = Get-ChildItem -LiteralPath $TopicDir -Filter "${prefix}*.md" -File -ErrorAction SilentlyContinue
    if ($existing -and -not $Force) {
        throw "number collision: $prefix already used by $($existing[0].Name)"
    }
}

$tmpPath = "$statusPath.tmp"
try {
    $json = $merged | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($tmpPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmpPath -Destination $statusPath -Force
}
catch {
    $errorMsg = $_.Exception.Message
    if (Test-Path -LiteralPath $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force }
    # Best-effort blocked marker write (non-atomic fallback)
    try {
        $current | Add-Member -NotePropertyName blocked_reason -NotePropertyValue "atomic write failed: $errorMsg" -Force
        $current | Add-Member -NotePropertyName owner -NotePropertyValue "human" -Force
        ($current | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $statusPath -Encoding utf8
    }
    catch { }
    throw
}

Write-Host "[update_status] wrote $statusPath" -ForegroundColor Green
