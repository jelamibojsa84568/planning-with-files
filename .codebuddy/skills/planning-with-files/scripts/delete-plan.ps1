# delete-plan.ps1
# Deletes a plan file and its associated metadata from the plans directory.
# Usage: .\delete-plan.ps1 -PlanId <plan-id> [-PlansDir <path>] [-Force]

param(
    [Parameter(Mandatory = $true)]
    [string]$PlanId,

    [Parameter(Mandatory = $false)]
    [string]$PlansDir = ".plans",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve plans directory
$PlansDir = $PlansDir.TrimEnd("/", "\")

if (-not (Test-Path $PlansDir)) {
    Write-Error "Plans directory '$PlansDir' does not exist."
    exit 1
}

# Sanitize plan ID to prevent path traversal
if ($PlanId -match '[/\\<>:"|?*]') {
    Write-Error "Invalid plan ID '$PlanId'. Plan IDs must not contain path separators or special characters."
    exit 1
}

# Locate the plan file (supports .md and .txt extensions)
$PlanFile = $null
foreach ($ext in @(".md", ".txt", "")) {
    $candidate = Join-Path $PlansDir "$PlanId$ext"
    if (Test-Path $candidate -PathType Leaf) {
        $PlanFile = $candidate
        break
    }
}

if ($null -eq $PlanFile) {
    Write-Error "Plan '$PlanId' not found in '$PlansDir'."
    exit 1
}

# Prompt for confirmation unless -Force is specified
if (-not $Force) {
    $confirmation = Read-Host "Are you sure you want to delete plan '$PlanId'? This action cannot be undone. [y/N]"
    if ($confirmation -notmatch '^[Yy]$') {
        Write-Host "Deletion cancelled."
        exit 0
    }
}

# Remove the plan file
try {
    Remove-Item -Path $PlanFile -Force
    Write-Host "Deleted plan file: $PlanFile"
} catch {
    Write-Error "Failed to delete plan file '$PlanFile': $_"
    exit 1
}

# Remove associated attestation file if present
$AttestFile = Join-Path $PlansDir ".attestations" "$PlanId.json"
if (Test-Path $AttestFile -PathType Leaf) {
    try {
        Remove-Item -Path $AttestFile -Force
        Write-Host "Deleted attestation file: $AttestFile"
    } catch {
        Write-Warning "Could not delete attestation file '$AttestFile': $_"
    }
}

# Remove associated metadata file if present
$MetaFile = Join-Path $PlansDir ".meta" "$PlanId.json"
if (Test-Path $MetaFile -PathType Leaf) {
    try {
        Remove-Item -Path $MetaFile -Force
        Write-Host "Deleted metadata file: $MetaFile"
    } catch {
        Write-Warning "Could not delete metadata file '$MetaFile': $_"
    }
}

# Clean up empty subdirectories
foreach ($subDir in @(".attestations", ".meta")) {
    $dirPath = Join-Path $PlansDir $subDir
    if (Test-Path $dirPath -PathType Container) {
        $remaining = Get-ChildItem -Path $dirPath -Force
        if ($remaining.Count -eq 0) {
            Remove-Item -Path $dirPath -Force
            Write-Host "Removed empty directory: $dirPath"
        }
    }
}

Write-Host "Plan '$PlanId' successfully deleted."
exit 0
