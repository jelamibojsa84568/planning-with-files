#!/bin/bash
# remove-step.sh - Remove a step from an existing plan
# Usage: ./remove-step.sh <plan-name> <step-number>

set -euo pipefail

# Configuration
PLANS_DIR="${PLANS_DIR:-./plans}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

usage() {
    echo "Usage: $0 <plan-name> <step-number>"
    echo ""
    echo "Arguments:"
    echo "  plan-name    Name of the plan (without .md extension)"
    echo "  step-number  Step number to remove (1-based index)"
    echo ""
    echo "Examples:"
    echo "  $0 my-feature-plan 3"
    echo "  $0 refactor-auth 1"
    exit 1
}

# Validate arguments
if [[ $# -lt 2 ]]; then
    log_error "Missing required arguments."
    usage
fi

PLAN_NAME="$1"
STEP_NUMBER="$2"
PLAN_FILE="${PLANS_DIR}/${PLAN_NAME}.md"

# Validate step number is a positive integer
if ! [[ "$STEP_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    log_error "Step number must be a positive integer, got: '${STEP_NUMBER}'"
    exit 1
fi

# Check plan file exists
if [[ ! -f "$PLAN_FILE" ]]; then
    log_error "Plan file not found: ${PLAN_FILE}"
    exit 1
fi

# Count existing steps
STEP_COUNT=$(grep -c '^## Step [0-9]' "$PLAN_FILE" || true)

if [[ "$STEP_COUNT" -eq 0 ]]; then
    log_error "No steps found in plan '${PLAN_NAME}'."
    exit 1
fi

if [[ "$STEP_NUMBER" -gt "$STEP_COUNT" ]]; then
    log_error "Step ${STEP_NUMBER} does not exist. Plan '${PLAN_NAME}' has ${STEP_COUNT} step(s)."
    exit 1
fi

# Extract the step title before removing for confirmation message
STEP_TITLE=$(grep -n "^## Step ${STEP_NUMBER}:" "$PLAN_FILE" | head -1 | sed 's/^[0-9]*:## Step [0-9]*: //' || echo "(untitled)")

log_info "Removing step ${STEP_NUMBER}: '${STEP_TITLE}' from plan '${PLAN_NAME}'..."

# Create a backup before modification
BACKUP_FILE="${PLAN_FILE}.bak"
cp "$PLAN_FILE" "$BACKUP_FILE"

# Use awk to remove the target step block and renumber remaining steps
awk -v target="$STEP_NUMBER" '
    BEGIN { in_target = 0; current_step = 0; offset = 0 }
    /^## Step [0-9]+/ {
        match($0, /^## Step ([0-9]+)/, arr)
        current_step = arr[1] + 0
        if (current_step == target) {
            in_target = 1
            next
        } else {
            in_target = 0
            if (current_step > target) {
                # Renumber: decrease step number by 1
                new_step = current_step - 1
                sub(/^## Step [0-9]+/, "## Step " new_step)
            }
        }
    }
    in_target { next }
    { print }
' "$BACKUP_FILE" > "$PLAN_FILE"

# Verify the modification was successful
NEW_STEP_COUNT=$(grep -c '^## Step [0-9]' "$PLAN_FILE" || true)
EXPECTED_COUNT=$(( STEP_COUNT - 1 ))

if [[ "$NEW_STEP_COUNT" -ne "$EXPECTED_COUNT" ]]; then
    log_error "Step removal failed. Restoring backup..."
    cp "$BACKUP_FILE" "$PLAN_FILE"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Remove backup on success
rm -f "$BACKUP_FILE"

log_info "Successfully removed step ${STEP_NUMBER} from plan '${PLAN_NAME}'."
if [[ "$NEW_STEP_COUNT" -gt 0 ]]; then
    log_info "Remaining steps have been renumbered. Plan now has ${NEW_STEP_COUNT} step(s)."
else
    log_warn "Plan '${PLAN_NAME}' now has no steps."
fi
