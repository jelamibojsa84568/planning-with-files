# update-plan.ps1
# Updates an existing plan file with new step statuses, notes, or additional steps
# Usage: .\update-plan.ps1 -PlanFile <path> [-StepNumber <n>] [-Status <status>] [-Note <text>] [-AddStep <description>]

param(
    [Parameter(Mandatory=$true)]
    [string]$PlanFile,

    [Parameter(Mandatory=$false)]
    [int]$StepNumber = 0,

    [Parameter(Mandatory=$false)]
    [ValidateSet("pending", "in-progress", "complete", "blocked", "skipped")]
    [string]$Status = "",

    [Parameter(Mandatory=$false)]
    [string]$Note = "",

    [Parameter(Mandatory=$false)]
    [string]$AddStep = ""
)

# Validate plan file exists
if (-not (Test-Path $PlanFile)) {
    Write-Error "Plan file not found: $PlanFile"
    exit 1
}

# Read current plan content
$content = Get-Content $PlanFile -Raw
$lines = Get-Content $PlanFile

# Helper: get timestamp
function Get-Timestamp {
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

# Helper: find step line index by step number
function Find-StepLine {
    param([string[]]$Lines, [int]$StepNum)
    for ($i = 0; $i -lt $Lines.Length; $i++) {
        if ($Lines[$i] -match "^\s*[-*]\s*\[\s*[xX ]?\s*\]\s*\*?\*?Step\s+$StepNum\b" -or
            $Lines[$i] -match "^\s*\d+\.\s+.*Step\s+$StepNum\b" -or
            $Lines[$i] -match "^#+\s+Step\s+$StepNum\b") {
            return $i
        }
    }
    return -1
}

# Helper: map status to checkbox
function Get-Checkbox {
    param([string]$StatusValue)
    switch ($StatusValue) {
        "complete"    { return "[x]" }
        "in-progress" { return "[-]" }
        "blocked"     { return "[!]" }
        "skipped"     { return "[~]" }
        default       { return "[ ]" }
    }
}

$updated = $false

# --- Update step status ---
if ($StepNumber -gt 0 -and $Status -ne "") {
    $checkbox = Get-Checkbox -StatusValue $Status
    $newLines = @()
    $stepFound = $false

    foreach ($line in $lines) {
        # Match lines like: - [ ] Step N or - [x] Step N
        if ($line -match "^(\s*[-*]\s*)\[[ xX\-!~]?\](\s*\*?\*?Step\s+$StepNumber\b.*)") {
            $newLines += "$($Matches[1])$checkbox$($Matches[2])"
            $stepFound = $true
            $updated = $true
        } else {
            $newLines += $line
        }
    }

    if (-not $stepFound) {
        Write-Warning "Step $StepNumber not found in plan. Status not updated."
    } else {
        $lines = $newLines
        Write-Host "Updated Step $StepNumber status to '$Status'."
    }
}

# --- Add a note to a step ---
if ($StepNumber -gt 0 -and $Note -ne "") {
    $timestamp = Get-Timestamp
    $noteEntry = "  > **Note** ($timestamp): $Note"
    $newLines = @()
    $stepFound = $false
    $noteInserted = $false

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $newLines += $lines[$i]
        if (-not $noteInserted -and
            ($lines[$i] -match "^\s*[-*]\s*\[[ xX\-!~]?\]\s*\*?\*?Step\s+$StepNumber\b")) {
            $stepFound = $true
            $newLines += $noteEntry
            $noteInserted = $true
            $updated = $true
        }
    }

    if (-not $stepFound) {
        Write-Warning "Step $StepNumber not found. Note not added."
    } else {
        $lines = $newLines
        Write-Host "Added note to Step $StepNumber."
    }
}

# --- Append a new step ---
if ($AddStep -ne "") {
    # Count existing steps to determine next step number
    $maxStep = 0
    foreach ($line in $lines) {
        if ($line -match "Step\s+(\d+)") {
            $num = [int]$Matches[1]
            if ($num -gt $maxStep) { $maxStep = $num }
        }
    }
    $nextStep = $maxStep + 1
    $timestamp = Get-Timestamp
    $newStepLine = "- [ ] **Step $nextStep**: $AddStep"
    $lines += ""
    $lines += $newStepLine
    $updated = $true
    Write-Host "Added Step $nextStep: $AddStep"
}

# --- Write back if changes were made ---
if ($updated) {
    $lines | Set-Content $PlanFile -Encoding UTF8
    Write-Host "Plan file updated: $PlanFile"
} else {
    Write-Host "No changes made to plan file."
}
