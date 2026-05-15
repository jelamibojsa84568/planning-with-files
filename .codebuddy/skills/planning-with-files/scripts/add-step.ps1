# add-step.ps1
# Adds a new step to an existing plan file
# Usage: .\add-step.ps1 -PlanName <name> -StepDescription <description> [-StepIndex <index>]

param(
    [Parameter(Mandatory=$true)]
    [string]$PlanName,

    [Parameter(Mandatory=$true)]
    [string]$StepDescription,

    [Parameter(Mandatory=$false)]
    [int]$StepIndex = -1,

    [Parameter(Mandatory=$false)]
    [string]$PlansDir = ".plans"
)

# Normalize plan name to filename
function Get-PlanFileName {
    param([string]$Name)
    $normalized = $Name.ToLower() -replace '[^a-z0-9-]', '-' -replace '-+', '-'
    return "$normalized.md"
}

# Resolve plans directory relative to repo root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not inside a git repository."
    exit 1
}

$plansDirPath = Join-Path $repoRoot $PlansDir

if (-not (Test-Path $plansDirPath)) {
    Write-Error "Plans directory '$plansDirPath' does not exist."
    exit 1
}

$planFile = Join-Path $plansDirPath (Get-PlanFileName $PlanName)

if (-not (Test-Path $planFile)) {
    Write-Error "Plan file '$planFile' not found."
    exit 1
}

# Read existing plan content
$lines = Get-Content $planFile

# Find existing steps and determine next step number
$stepPattern = '^- \[([ x])\] \*\*Step (\d+)\*\*:'
$existingSteps = $lines | Where-Object { $_ -match $stepPattern }
$nextStepNumber = ($existingSteps.Count) + 1

# Build new step line
$newStepLine = "- [ ] **Step $nextStepNumber**: $StepDescription"

# Find the index of the steps section
$stepsHeaderIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^## Steps') {
        $stepsHeaderIndex = $i
        break
    }
}

if ($stepsHeaderIndex -eq -1) {
    Write-Error "Could not find '## Steps' section in plan file."
    exit 1
}

# Collect lines before and after insertion point
$newLines = [System.Collections.Generic.List[string]]::new()

if ($StepIndex -gt 0 -and $StepIndex -le $existingSteps.Count) {
    # Insert at specific position and renumber subsequent steps
    $insertedAtStep = $false
    $currentStep = 0

    foreach ($line in $lines) {
        if ($line -match $stepPattern) {
            $currentStep++
            if ($currentStep -eq $StepIndex -and -not $insertedAtStep) {
                # Insert new step before this one
                $newLines.Add("- [ ] **Step $StepIndex**: $StepDescription")
                $insertedAtStep = $true
                # Renumber this and all subsequent steps
                $renumbered = $line -replace "\*\*Step $currentStep\*\*", "**Step $($currentStep + 1)**"
                $newLines.Add($renumbered)
            } elseif ($insertedAtStep) {
                $renumbered = $line -replace "\*\*Step $currentStep\*\*", "**Step $($currentStep + 1)**"
                $newLines.Add($renumbered)
            } else {
                $newLines.Add($line)
            }
        } else {
            $newLines.Add($line)
        }
    }
} else {
    # Append step at the end of the steps section
    $appendDone = $false
    $inStepsSection = $false

    foreach ($line in $lines) {
        if ($line -match '^## Steps') {
            $inStepsSection = $true
            $newLines.Add($line)
            continue
        }

        if ($inStepsSection -and $line -match '^## ' -and $line -notmatch '^## Steps') {
            # We've hit the next section — insert step before it
            if (-not $appendDone) {
                $newLines.Add($newStepLine)
                $appendDone = $true
            }
            $inStepsSection = $false
        }

        $newLines.Add($line)
    }

    # If steps section was the last section
    if (-not $appendDone) {
        $newLines.Add($newStepLine)
    }
}

# Write updated content back to file
$newLines | Set-Content $planFile -Encoding UTF8

Write-Host "Step added to plan '$PlanName' successfully."
Write-Host "  File: $planFile"
Write-Host "  Step: $newStepLine"
