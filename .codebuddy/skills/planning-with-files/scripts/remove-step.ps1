# remove-step.ps1
# Removes a step from an existing plan by step number
# Usage: .\remove-step.ps1 -PlanName <name> -StepNumber <number> [-PlansDir <dir>]

param(
    [Parameter(Mandatory=$true)]
    [string]$PlanName,

    [Parameter(Mandatory=$true)]
    [int]$StepNumber,

    [Parameter(Mandatory=$false)]
    [string]$PlansDir = ".plans"
)

$ErrorActionPreference = "Stop"

# Resolve plans directory
$PlansDir = $PlansDir.TrimEnd('/\')

if (-not (Test-Path $PlansDir)) {
    Write-Error "Plans directory '$PlansDir' does not exist."
    exit 1
}

# Build plan file path
$PlanFile = Join-Path $PlansDir "$PlanName.md"

if (-not (Test-Path $PlanFile)) {
    Write-Error "Plan '$PlanName' not found at '$PlanFile'."
    exit 1
}

# Read plan content
$lines = Get-Content $PlanFile

# Parse steps from the plan file
# Steps are lines matching: - [ ] N. or - [x] N.
$stepPattern = '^(\s*- \[[ x]\] )(\d+)\. (.+)$'

$stepLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $stepPattern) {
        $stepLines += @{ Index = $i; Number = [int]$Matches[2]; Line = $lines[$i] }
    }
}

if ($stepLines.Count -eq 0) {
    Write-Error "No steps found in plan '$PlanName'."
    exit 1
}

# Find the step to remove
$targetStep = $stepLines | Where-Object { $_.Number -eq $StepNumber }

if (-not $targetStep) {
    Write-Error "Step $StepNumber not found in plan '$PlanName'."
    exit 1
}

# Check if step is already completed
if ($lines[$targetStep.Index] -match '^\s*- \[x\]') {
    Write-Warning "Step $StepNumber is already completed. Removing anyway..."
}

# Remove the step line
$newLines = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($i -ne $targetStep.Index) {
        $newLines.Add($lines[$i])
    }
}

# Renumber remaining steps
$renumbered = [System.Collections.Generic.List[string]]::new()
$currentStep = 1
foreach ($line in $newLines) {
    if ($line -match $stepPattern) {
        $prefix = $Matches[1]
        $description = $Matches[3]
        $renumbered.Add("$prefix$currentStep. $description")
        $currentStep++
    } else {
        $renumbered.Add($line)
    }
}

# Write updated plan back to file
$renumbered | Set-Content $PlanFile -Encoding UTF8

Write-Host "Successfully removed step $StepNumber from plan '$PlanName'."
Write-Host "Remaining steps have been renumbered."

# Show updated step count
$remainingSteps = $renumbered | Where-Object { $_ -match $stepPattern }
$completedSteps = $remainingSteps | Where-Object { $_ -match '^\s*- \[x\]' }

Write-Host ""
Write-Host "Plan summary:"
Write-Host "  Total steps : $($remainingSteps.Count)"
Write-Host "  Completed   : $($completedSteps.Count)"
Write-Host "  Remaining   : $($remainingSteps.Count - $completedSteps.Count)"
