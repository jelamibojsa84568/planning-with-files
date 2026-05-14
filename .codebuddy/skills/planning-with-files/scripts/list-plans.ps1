# list-plans.ps1
# Lists all planning files in the plans directory with their status and metadata
# Usage: .\list-plans.ps1 [-PlansDir <path>] [-Filter <status>] [-Verbose]

param(
    [string]$PlansDir = "plans",
    [ValidateSet("all", "active", "complete", "draft", "")]
    [string]$Filter = "all",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Resolve plans directory relative to repo root
$RepoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not inside a git repository."
    exit 1
}

$PlansPath = Join-Path $RepoRoot $PlansDir

if (-not (Test-Path $PlansPath)) {
    Write-Host "No plans directory found at: $PlansPath" -ForegroundColor Yellow
    Write-Host "Create your first plan with: create-plan.ps1"
    exit 0
}

# Collect all markdown plan files
$PlanFiles = Get-ChildItem -Path $PlansPath -Filter "*.md" -File | Sort-Object Name

if ($PlanFiles.Count -eq 0) {
    Write-Host "No plans found in: $PlansPath" -ForegroundColor Yellow
    Write-Host "Create your first plan with: create-plan.ps1"
    exit 0
}

# Parse metadata from a plan file
function Get-PlanMetadata {
    param([System.IO.FileInfo]$File)

    $meta = @{
        Title  = $File.BaseName
        Status = "unknown"
        Date   = ""
        Tasks  = 0
        Done   = 0
    }

    $lines = Get-Content $File.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { return $meta }

    foreach ($line in $lines) {
        if ($line -match '^#\s+(.+)$') {
            $meta.Title = $Matches[1].Trim()
        }
        if ($line -match '^[-*]\s+\*\*Status\*\*:\s*(.+)$' -or $line -match '^Status:\s*(.+)$') {
            $meta.Status = $Matches[1].Trim().ToLower()
        }
        if ($line -match '^[-*]\s+\*\*Date\*\*:\s*(.+)$' -or $line -match '^Date:\s*(.+)$') {
            $meta.Date = $Matches[1].Trim()
        }
        # Count checkboxes
        if ($line -match '^\s*-\s+\[x\]' ) { $meta.Done++ ; $meta.Tasks++ }
        elseif ($line -match '^\s*-\s+\[[ ]\]') { $meta.Tasks++ }
    }

    return $meta
}

# Status colour mapping
function Get-StatusColor {
    param([string]$Status)
    switch ($Status) {
        "complete"   { return "Green" }
        "active"     { return "Cyan" }
        "draft"      { return "Yellow" }
        default      { return "Gray" }
    }
}

# Header
Write-Host ""
Write-Host "Planning Files" -ForegroundColor White
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ("  {0,-30} {1,-10} {2,-10} {3}" -f "Title", "Status", "Progress", "Date") -ForegroundColor DarkGray
Write-Host ("  {0,-30} {1,-10} {2,-10} {3}" -f ("─" * 30), ("─" * 10), ("─" * 10), ("─" * 12)) -ForegroundColor DarkGray

$shown = 0

foreach ($file in $PlanFiles) {
    $meta = Get-PlanMetadata -File $file

    # Apply filter
    if ($Filter -ne "all" -and $Filter -ne "" -and $meta.Status -ne $Filter) {
        continue
    }

    $progress = if ($meta.Tasks -gt 0) {
        "{0}/{1}" -f $meta.Done, $meta.Tasks
    } else {
        "n/a"
    }

    $color = Get-StatusColor -Status $meta.Status
    $titleShort = if ($meta.Title.Length -gt 30) { $meta.Title.Substring(0, 27) + "..." } else { $meta.Title }

    Write-Host ("  {0,-30} " -f $titleShort) -NoNewline
    Write-Host ("{0,-10} " -f $meta.Status) -ForegroundColor $color -NoNewline
    Write-Host ("{0,-10} " -f $progress) -NoNewline
    Write-Host $meta.Date

    if ($Verbose) {
        Write-Host ("    File: {0}" -f $file.Name) -ForegroundColor DarkGray
    }

    $shown++
}

Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host "  Total shown: $shown of $($PlanFiles.Count)" -ForegroundColor DarkGray
Write-Host ""
