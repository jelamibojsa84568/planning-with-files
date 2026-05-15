# reorder-steps.ps1
# Reorders steps within a plan file by specifying a new order of step indices
# Usage: .\reorder-steps.ps1 -PlanName <name> -NewOrder <comma-separated indices>

param(
    [Parameter(Mandatory=$true)]
    [string]$PlanName,

    [Parameter(Mandatory=$true)]
    [string]$NewOrder,

    [Parameter(Mandatory=$false)]
    [string]$PlansDir = ".plans"
)

$ErrorActionPreference = "Stop"

# Resolve plan file path
$planFile = Join-Path $PlansDir "$PlanName.md"

if (-not (Test-Path $planFile)) {
    Write-Error "Plan file not found: $planFile"
    exit 1
}

# Parse the new order from comma-separated string (1-based indices)
try {
    $orderIndices = $NewOrder -split ',' | ForEach-Object { [int]$_.Trim() }
} catch {
    Write-Error "Invalid NewOrder format. Expected comma-separated integers (e.g. '2,1,3')."
    exit 1
}

# Read the plan file content
$content = Get-Content $planFile -Raw
$lines = Get-Content $planFile

# Extract step blocks from the markdown
# Steps are identified by lines starting with '## Step' or '### Step'
$stepPattern = '^#{2,3}\s+Step\s+\d+'
$stepStartLines = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $stepPattern) {
        $stepStartLines += $i
    }
}

$stepCount = $stepStartLines.Count

if ($stepCount -eq 0) {
    Write-Error "No steps found in plan '$PlanName'."
    exit 1
}

# Validate that the provided indices match the number of steps
if ($orderIndices.Count -ne $stepCount) {
    Write-Error "NewOrder must contain exactly $stepCount indices (one per step). Got $($orderIndices.Count)."
    exit 1
}

# Validate that indices are a valid permutation (1-based)
$sorted = $orderIndices | Sort-Object
for ($i = 0; $i -lt $sorted.Count; $i++) {
    if ($sorted[$i] -ne ($i + 1)) {
        Write-Error "NewOrder must be a permutation of 1..$stepCount. Invalid value or duplicate found."
        exit 1
    }
}

# Extract each step block as an array of lines
$stepBlocks = @()
for ($s = 0; $s -lt $stepCount; $s++) {
    $start = $stepStartLines[$s]
    $end = if ($s + 1 -lt $stepCount) { $stepStartLines[$s + 1] - 1 } else { $lines.Count - 1 }
    $block = $lines[$start..$end]
    $stepBlocks += , $block
}

# Extract the header section (everything before the first step)
$headerLines = if ($stepStartLines[0] -gt 0) { $lines[0..($stepStartLines[0] - 1)] } else { @() }

# Build the new content with reordered steps, renumbering them sequentially
$newLines = [System.Collections.Generic.List[string]]::new()

foreach ($headerLine in $headerLines) {
    $newLines.Add($headerLine)
}

$newStepNumber = 1
foreach ($idx in $orderIndices) {
    $block = $stepBlocks[$idx - 1]
    foreach ($blockLine in $block) {
        # Renumber the step heading line
        $updatedLine = $blockLine -replace '^(#{2,3}\s+Step\s+)\d+', "${1}$newStepNumber"
        $newLines.Add($updatedLine)
    }
    $newStepNumber++
}

# Write the updated content back to the file
$newLines | Set-Content $planFile -Encoding UTF8

Write-Host "Steps in plan '$PlanName' reordered successfully."
Write-Host "New order applied: $NewOrder"
