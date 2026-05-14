# create-plan.ps1
# PowerShell equivalent of create-plan.sh
# Creates a new plan file with the specified name and optional description

param(
    [Parameter(Mandatory = $false)]
    [string]$PlanName,

    [Parameter(Mandatory = $false)]
    [string]$Description = "",

    [Parameter(Mandatory = $false)]
    [string]$PlansDir = "plans"
)

# ── helpers ────────────────────────────────────────────────────────────────────

function Write-Info  { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Fail  { param([string]$Msg) Write-Host "[FAIL]  $Msg" -ForegroundColor Red }

function Get-Timestamp {
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Get-DateSlug {
    return (Get-Date -Format "yyyy-MM-dd")
}

# ── validate input ─────────────────────────────────────────────────────────────

if (-not $PlanName) {
    Write-Fail "Plan name is required."
    Write-Host "Usage: create-plan.ps1 -PlanName <name> [-Description <desc>] [-PlansDir <dir>]"
    exit 1
}

# Sanitise plan name: lowercase, replace spaces/special chars with hyphens
$SafeName = $PlanName -replace '[^a-zA-Z0-9\-_]', '-'
$SafeName = $SafeName -replace '-+', '-'
$SafeName = $SafeName.Trim('-').ToLower()

if (-not $SafeName) {
    Write-Fail "Plan name '$PlanName' produced an empty safe name after sanitisation."
    exit 1
}

# ── ensure plans directory exists ──────────────────────────────────────────────

if (-not (Test-Path $PlansDir)) {
    Write-Info "Creating plans directory: $PlansDir"
    New-Item -ItemType Directory -Path $PlansDir | Out-Null
}

# ── resolve file path ──────────────────────────────────────────────────────────

$DateSlug  = Get-DateSlug
$FileName  = "${DateSlug}-${SafeName}.md"
$FilePath  = Join-Path $PlansDir $FileName

if (Test-Path $FilePath) {
    Write-Warn "Plan file already exists: $FilePath"
    Write-Warn "Delete or rename the existing file before creating a new one."
    exit 1
}

# ── build front-matter and template ───────────────────────────────────────────

$Timestamp = Get-Timestamp

$DescriptionLine = if ($Description) { $Description } else { "<!-- Add a short description of this plan -->" }

$Template = @"
---
title: $PlanName
date: $DateSlug
created_at: $Timestamp
status: draft
---

# $PlanName

$DescriptionLine

## Objective

<!-- What is the goal of this plan? -->

## Steps

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

## Notes

<!-- Any additional context, dependencies, or risks -->

## Completion Criteria

<!-- How will you know this plan is done? -->
"@

# ── write file ─────────────────────────────────────────────────────────────────

try {
    # Use UTF-8 without BOM for cross-platform compatibility
    $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText(
        (Resolve-Path $PlansDir | Join-Path -ChildPath $FileName),
        $Template,
        $Utf8NoBom
    )
    Write-Ok "Plan created: $FilePath"
} catch {
    Write-Fail "Failed to write plan file: $_"
    exit 1
}

# ── summary ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  Plan : $PlanName"
Write-Host "  File : $FilePath"
Write-Host "  Date : $DateSlug"
Write-Host ""
Write-Info "Open the file and fill in the steps, objective, and completion criteria."
