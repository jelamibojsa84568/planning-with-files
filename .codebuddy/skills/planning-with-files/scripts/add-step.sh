#!/usr/bin/env bash
# add-step.sh - Add a new step to an existing plan
# Usage: ./add-step.sh <plan-name> <step-description> [--position <n>]

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PLANS_DIR="${PLANS_DIR:-.plans}"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
usage() {
  echo "Usage: $0 <plan-name> <step-description> [--position <n>]"
  echo ""
  echo "Arguments:"
  echo "  plan-name          Name of the plan to add a step to"
  echo "  step-description   Description of the new step"
  echo ""
  echo "Options:"
  echo "  --position <n>     Insert step at position n (1-based). Defaults to end."
  echo ""
  echo "Examples:"
  echo "  $0 my-feature \"Write unit tests\""
  echo "  $0 my-feature \"Write unit tests\" --position 2"
  exit 1
}

error() {
  echo "ERROR: $1" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [[ $# -lt 2 ]]; then
  usage
fi

PLAN_NAME="$1"
STEP_DESC="$2"
POSITION=""

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --position)
      [[ -z "${2:-}" ]] && error "--position requires a numeric argument"
      POSITION="$2"
      shift 2
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
[[ -z "$PLAN_NAME" ]] && error "Plan name cannot be empty"
[[ -z "$STEP_DESC" ]] && error "Step description cannot be empty"

if [[ -n "$POSITION" ]]; then
  if ! [[ "$POSITION" =~ ^[1-9][0-9]*$ ]]; then
    error "Position must be a positive integer"
  fi
fi

PLAN_FILE="${PLANS_DIR}/${PLAN_NAME}.md"

[[ ! -d "$PLANS_DIR" ]] && error "Plans directory '${PLANS_DIR}' does not exist"
[[ ! -f "$PLAN_FILE" ]] && error "Plan '${PLAN_NAME}' not found at '${PLAN_FILE}'"

# ---------------------------------------------------------------------------
# Read existing steps
# ---------------------------------------------------------------------------
# Count current steps by scanning unchecked and checked boxes
STEP_COUNT=$(grep -cE '^- \[.\]' "$PLAN_FILE" || true)

if [[ -n "$POSITION" ]] && [[ "$POSITION" -gt $((STEP_COUNT + 1)) ]]; then
  error "Position $POSITION is out of range. Plan has ${STEP_COUNT} step(s); max insert position is $((STEP_COUNT + 1))"
fi

# ---------------------------------------------------------------------------
# Build the new step line
# ---------------------------------------------------------------------------
NEW_STEP="- [ ] ${STEP_DESC}"

# ---------------------------------------------------------------------------
# Insert step into the plan file
# ---------------------------------------------------------------------------
if [[ -z "$POSITION" ]] || [[ "$POSITION" -gt "$STEP_COUNT" ]]; then
  # Append after the last step line
  # Find the line number of the last step
  LAST_STEP_LINE=$(grep -nE '^- \[.\]' "$PLAN_FILE" | tail -1 | cut -d: -f1 || true)

  if [[ -z "$LAST_STEP_LINE" ]]; then
    # No steps yet — append before any trailing newlines at end of file
    echo "$NEW_STEP" >> "$PLAN_FILE"
  else
    # Insert after the last step line using sed
    sed -i "${LAST_STEP_LINE}a\\${NEW_STEP}" "$PLAN_FILE"
  fi
else
  # Insert before the Nth step
  TARGET_LINE=$(grep -nE '^- \[.\]' "$PLAN_FILE" | sed -n "${POSITION}p" | cut -d: -f1)
  [[ -z "$TARGET_LINE" ]] && error "Could not locate step at position ${POSITION}"
  sed -i "$((TARGET_LINE - 1))a\\${NEW_STEP}" "$PLAN_FILE"
fi

# ---------------------------------------------------------------------------
# Update the metadata: bump step count in header if present
# ---------------------------------------------------------------------------
# Recalculate total steps after insertion
NEW_TOTAL=$(grep -cE '^- \[.\]' "$PLAN_FILE" || true)

echo "✅ Step added to plan '${PLAN_NAME}'"
echo "   Description : ${STEP_DESC}"
if [[ -n "$POSITION" ]]; then
  echo "   Position    : ${POSITION}"
else
  echo "   Position    : ${NEW_TOTAL} (end)"
fi
echo "   Total steps : ${NEW_TOTAL}"
