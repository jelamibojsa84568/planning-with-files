#!/usr/bin/env bash
# complete-step.sh - Mark a specific step in a plan as complete
# Usage: ./complete-step.sh <plan-id> <step-number> [--notes "completion notes"]

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PLANS_DIR="${PLANS_DIR:-./plans}"
DATE_CMD="date"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") <plan-id> <step-number> [OPTIONS]

Mark a specific step in a plan as complete.

Arguments:
  plan-id       The unique identifier of the plan
  step-number   The step number to mark as complete (1-based)

Options:
  --notes TEXT  Optional completion notes to append to the step
  --help        Show this help message

Examples:
  $(basename "$0") my-feature 2
  $(basename "$0") my-feature 3 --notes "Resolved edge case in validation"
EOF
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "INFO: $*"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

PLAN_ID="$1"
STEP_NUMBER="$2"
shift 2

NOTES=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes)
      NOTES="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [[ ! "$STEP_NUMBER" =~ ^[0-9]+$ ]] || [[ "$STEP_NUMBER" -lt 1 ]]; then
  error "Step number must be a positive integer, got: $STEP_NUMBER"
fi

PLAN_FILE="${PLANS_DIR}/${PLAN_ID}.md"

if [[ ! -f "$PLAN_FILE" ]]; then
  error "Plan not found: $PLAN_ID (looked for $PLAN_FILE)"
fi

# ---------------------------------------------------------------------------
# Read plan and locate step
# ---------------------------------------------------------------------------
TOTAL_STEPS=$(grep -c '^- \[' "$PLAN_FILE" 2>/dev/null || true)

if [[ "$TOTAL_STEPS" -eq 0 ]]; then
  error "No steps found in plan: $PLAN_ID"
fi

if [[ "$STEP_NUMBER" -gt "$TOTAL_STEPS" ]]; then
  error "Step $STEP_NUMBER does not exist. Plan '$PLAN_ID' has $TOTAL_STEPS step(s)."
fi

# Check if step is already complete
STEP_LINE=$(grep -n '^- \[' "$PLAN_FILE" | sed -n "${STEP_NUMBER}p")
LINE_NUM=$(echo "$STEP_LINE" | cut -d: -f1)
LINE_CONTENT=$(echo "$STEP_LINE" | cut -d: -f2-)

if echo "$LINE_CONTENT" | grep -q '^- \[x\]'; then
  info "Step $STEP_NUMBER is already marked as complete."
  exit 0
fi

# ---------------------------------------------------------------------------
# Mark step as complete
# ---------------------------------------------------------------------------
TIMESTAMP=$(${DATE_CMD} -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || ${DATE_CMD} +"%Y-%m-%dT%H:%M:%SZ")

# Replace '- [ ]' with '- [x]' on the target line
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "${LINE_NUM}s/^- \[ \]/- [x]/" "$PLAN_FILE"
else
  sed -i "${LINE_NUM}s/^- \[ \]/- [x]/" "$PLAN_FILE"
fi

# Append completion notes if provided
if [[ -n "$NOTES" ]]; then
  # Find the line after the step and insert a note
  NOTE_LINE="  > Completed ${TIMESTAMP}: ${NOTES}"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "${LINE_NUM}a\\
${NOTE_LINE}" "$PLAN_FILE"
  else
    sed -i "${LINE_NUM}a\  > Completed ${TIMESTAMP}: ${NOTES}" "$PLAN_FILE"
  fi
fi

# Update the last-modified metadata if present
if grep -q '^updated:' "$PLAN_FILE"; then
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^updated:.*/updated: ${TIMESTAMP}/" "$PLAN_FILE"
  else
    sed -i "s/^updated:.*/updated: ${TIMESTAMP}/" "$PLAN_FILE"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
COMPLETED=$(grep -c '^- \[x\]' "$PLAN_FILE" 2>/dev/null || true)
REMAINING=$(grep -c '^- \[ \]' "$PLAN_FILE" 2>/dev/null || true)

info "Step $STEP_NUMBER marked as complete in plan '$PLAN_ID'."
info "Progress: $COMPLETED/$TOTAL_STEPS step(s) complete, $REMAINING remaining."

if [[ "$REMAINING" -eq 0 ]]; then
  info "All steps complete! Consider running check-complete.sh to finalise the plan."
fi
