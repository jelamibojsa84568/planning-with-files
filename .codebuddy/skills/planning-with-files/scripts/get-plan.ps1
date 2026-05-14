# get-plan.ps1
# Retrieves and displays the contents of a specific plan file
# Usage: .\get-plan.ps1 -PlanName <name> [-PlansDir <directory>] [-Format <format>]

param(
    [Parameter(Mandatory = $true)]
    [string]$PlanName,

    [Parameter(Mandatory = $false)]
    [string]$PlansDir = ".plans",

    [Parameter(Mandatory = $false)]
    [ValidateSet("full", "summary", "steps", "metadata")]
    [string]$Format = "full"
)

# Normalize plan name (strip .md extension if provided)
$PlanName = $PlanName -replace '\.md$', ''

# Build the plan file path
$PlanFile = Join-Path $PlansDir "$PlanName.md"

# Verify the plans directory exists
if (-not (Test-Path $PlansDir -PathType Container)) {
    Write-Error "Plans directory '$PlansDir' does not exist."
    exit 1
}

# Verify the plan file exists
if (-not (Test-Path $PlanFile -PathType Leaf)) {
    Write-Error "Plan '$PlanName' not found at '$PlanFile'."
    exit 1
}

# Read the plan file content
$Content = Get-Content $PlanFile -Raw
$Lines = Get-Content $PlanFile

function Get-MetadataBlock {
    param([string[]]$Lines)
    $meta = @{}
    $inMeta = $false
    foreach ($line in $Lines) {
        if ($line -match '^<!--\s*meta') { $inMeta = $true; continue }
        if ($line -match '^-->') { $inMeta = $false; continue }
        if ($inMeta -and $line -match '^(\w[\w\s]*):\s*(.+)$') {
            $meta[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $meta
}

function Get-PlanSteps {
    param([string[]]$Lines)
    $steps = @()
    foreach ($line in $Lines) {
        if ($line -match '^- \[([ xX])\]\s+(.+)$') {
            $steps += [PSCustomObject]@{
                Completed = ($Matches[1] -ne ' ')
                Description = $Matches[2].Trim()
            }
        }
    }
    return $steps
}

function Get-PlanTitle {
    param([string[]]$Lines)
    foreach ($line in $Lines) {
        if ($line -match '^#\s+(.+)$') {
            return $Matches[1].Trim()
        }
    }
    return $null
}

switch ($Format) {
    "full" {
        Write-Host $Content
    }

    "summary" {
        $title = Get-PlanTitle -Lines $Lines
        $steps = Get-PlanSteps -Lines $Lines
        $total = $steps.Count
        $done = ($steps | Where-Object { $_.Completed }).Count
        $pct = if ($total -gt 0) { [math]::Round(($done / $total) * 100) } else { 0 }

        Write-Host "Plan   : $PlanName"
        if ($title) { Write-Host "Title  : $title" }
        Write-Host "Steps  : $done / $total completed ($pct%)"
        Write-Host "File   : $PlanFile"
    }

    "steps" {
        $steps = Get-PlanSteps -Lines $Lines
        if ($steps.Count -eq 0) {
            Write-Host "No steps found in plan '$PlanName'."
        } else {
            foreach ($step in $steps) {
                $marker = if ($step.Completed) { "[x]" } else { "[ ]" }
                Write-Host "$marker $($step.Description)"
            }
        }
    }

    "metadata" {
        $meta = Get-MetadataBlock -Lines $Lines
        if ($meta.Count -eq 0) {
            Write-Host "No metadata block found in plan '$PlanName'."
        } else {
            foreach ($key in $meta.Keys) {
                Write-Host "${key}: $($meta[$key])"
            }
        }
    }
}

exit 0
