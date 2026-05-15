# complete-step.ps1
# Marks a specific step in a plan as complete
# Usage: .\complete-step.ps1 -PlanName <name> -StepNumber <number> [-PlansDir <path>]

param(
    [Parameter(Mandatory=$true)]
    [string]$PlanName,

    [Parameter(Mandatory=$true)]
    [int]$StepNumber,

    [Parameter(Mandatory=$false)]
    [string]$PlansDir = ".plans"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve the plans directory
$PlansDir = $PlansDir.TrimEnd('/\\')

if (-not (Test-Path $PlansDir -PathType Container)) {
    Write-Error "Plans directory '$PlansDir' does not exist."
    exit 1
}

# Locate the plan file
$PlanFile = Join-Path $PlansDir "$PlanName.md"

if (-not (Test-Path $PlanFile -PathType Leaf)) {
    Write-Error "Plan '$PlanName' not found at '$PlanFile'."
    exit 1
}

# Read the plan content
$lines = Get-Content $PlanFile -Encoding UTF8

# Pattern to match incomplete steps: '- [ ] Step N:' or '- [ ] N.'
$incompletePattern = '^(\s*- \[ \]\s*)(.*)$'
$stepFound = $false
$stepCount = 0
$updatedLines = @()

foreach ($line in $lines) {
    if ($line -match $incompletePattern) {
        $stepCount++
        if ($stepCount -eq $StepNumber) {
            # Mark this step as complete
            $updatedLine = $line -replace '\[ \]', '[x]'
            $updatedLines += $updatedLine
            $stepFound = $true
            Write-Host "Marked step $StepNumber as complete: $($Matches[2])"
            continue
        }
    }
    $updatedLines += $line
}

if (-not $stepFound) {
    # Check if step number exceeds total incomplete steps
    if ($StepNumber -gt $stepCount) {
        Write-Error "Step $StepNumber not found. Plan '$PlanName' has $stepCount incomplete step(s)."
    } else {
        Write-Error "Could not locate incomplete step $StepNumber in plan '$PlanName'."
    }
    exit 1
}

# Write updated content back to the plan file
$updatedLines | Set-Content $PlanFile -Encoding UTF8

Write-Host "Plan '$PlanName' updated successfully."

# Check if all steps are now complete
$remainingIncomplete = $updatedLines | Where-Object { $_ -match '^\s*- \[ \]' }

if ($remainingIncomplete.Count -eq 0) {
    Write-Host ""
    Write-Host "All steps in plan '$PlanName' are now complete!"
    Write-Host "Consider running attest-plan to finalize and archive the plan."
} else {
    Write-Host ""
    Write-Host "Remaining incomplete steps: $($remainingIncomplete.Count)"
}

exit 0
