#!/usr/bin/env bash
# check-complete.sh
# Checks whether all tasks in a plan file are marked as complete.
# Usage: ./check-complete.sh <plan-file>
# Exit codes:
#   0 - All tasks are complete
#   1 - One or more tasks are incomplete
#   2 - Invalid usage or file not found

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $(basename "$0") <plan-file>" >&2
    echo "  plan-file  Path to the markdown plan file to check" >&2
    exit 2
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
[[ $# -eq 1 ]] || usage

PLAN_FILE="$1"

[[ -f "$PLAN_FILE" ]] || die "Plan file not found: $PLAN_FILE"

# ---------------------------------------------------------------------------
# Parse task checkboxes
# Markdown task syntax:
#   - [ ] incomplete task
#   - [x] complete task  (case-insensitive x)
# ---------------------------------------------------------------------------
TOTAL=0
COMPLETE=0
INCOMPLETE_TASKS=()

while IFS= read -r line; do
    # Match any checkbox: - [ ] or - [x] (also * [ ] / * [x])
    if [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+\[([[:space:]xX])\][[:space:]]+(.*) ]]; then
        STATUS="${BASH_REMATCH[1]}"
        TASK_TEXT="${BASH_REMATCH[2]}"
        TOTAL=$((TOTAL + 1))

        if [[ "$STATUS" =~ [xX] ]]; then
            COMPLETE=$((COMPLETE + 1))
        else
            INCOMPLETE_TASKS+=("$TASK_TEXT")
        fi
    fi
done < "$PLAN_FILE"

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
INCOMPLETE=$((TOTAL - COMPLETE))

echo "Plan file : $PLAN_FILE"
echo "Total tasks : $TOTAL"
echo "Complete    : $COMPLETE"
echo "Incomplete  : $INCOMPLETE"

if [[ $TOTAL -eq 0 ]]; then
    echo "WARNING: No tasks found in plan file." >&2
    exit 1
fi

if [[ $INCOMPLETE -gt 0 ]]; then
    echo ""
    echo "Incomplete tasks:"
    for task in "${INCOMPLETE_TASKS[@]}"; do
        echo "  - [ ] $task"
    done
    echo ""
    echo "RESULT: Plan is NOT complete ($INCOMPLETE of $TOTAL tasks remaining)."
    exit 1
fi

echo ""
echo "RESULT: Plan is COMPLETE. All $TOTAL tasks are done."
exit 0
