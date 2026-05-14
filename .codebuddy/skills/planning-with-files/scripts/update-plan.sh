#!/usr/bin/env bash
# update-plan.sh - Update an existing plan file with new steps or modifications
# Usage: ./update-plan.sh <plan-file> [--add-step <step-description>] [--mark-done <step-number>] [--set-status <status>]

set -euo pipefail

# ─── Helpers ────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $(basename "$0") <plan-file> [OPTIONS]

Options:
  --add-step <description>   Append a new step to the plan
  --mark-done <step-number>  Mark a step as completed (e.g. 1, 2, 3)
  --set-status <status>      Set the overall plan status (in-progress|blocked|complete)
  --help                     Show this help message

Examples:
  $(basename "$0") plan.md --add-step "Write unit tests"
  $(basename "$0") plan.md --mark-done 3
  $(basename "$0") plan.md --set-status in-progress
EOF
  exit 0
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

info() {
  echo "[INFO]  $*"
}

# ─── Argument Parsing ────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage
[[ "$1" == "--help" ]] && usage

PLAN_FILE="$1"
shift

[[ -f "$PLAN_FILE" ]] || error "Plan file not found: $PLAN_FILE"

ACTION=""
ACTION_VALUE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --add-step)
      [[ $# -lt 2 ]] && error "--add-step requires a description argument"
      ACTION="add-step"
      ACTION_VALUE="$2"
      shift 2
      ;;
    --mark-done)
      [[ $# -lt 2 ]] && error "--mark-done requires a step number argument"
      ACTION="mark-done"
      ACTION_VALUE="$2"
      shift 2
      ;;
    --set-status)
      [[ $# -lt 2 ]] && error "--set-status requires a status argument"
      ACTION="set-status"
      ACTION_VALUE="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

[[ -z "$ACTION" ]] && error "No action specified. Use --add-step, --mark-done, or --set-status."

# ─── Actions ─────────────────────────────────────────────────────────────────

add_step() {
  local description="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  # Count existing steps to determine next step number
  local step_count
  step_count=$(grep -cE '^- \[ \]|^- \[x\]' "$PLAN_FILE" 2>/dev/null || echo 0)
  local next_num=$(( step_count + 1 ))

  # Append the new step before the last blank line or at end of file
  cp "$PLAN_FILE" "$tmp_file"
  printf '\n- [ ] Step %d: %s\n' "$next_num" "$description" >> "$tmp_file"
  mv "$tmp_file" "$PLAN_FILE"

  info "Added step $next_num: $description"
}

mark_done() {
  local step_num="$1"
  [[ "$step_num" =~ ^[0-9]+$ ]] || error "Step number must be a positive integer, got: $step_num"

  local tmp_file
  tmp_file="$(mktemp)"

  # Replace the Nth unchecked or checked checkbox for that step number
  local pattern="^- \\[ \\] Step ${step_num}:"
  if grep -qE "$pattern" "$PLAN_FILE"; then
    sed -E "s/^(- )\\[ \\]( Step ${step_num}:)/\1[x]\2/" "$PLAN_FILE" > "$tmp_file"
    mv "$tmp_file" "$PLAN_FILE"
    info "Marked step $step_num as done."
  else
    rm -f "$tmp_file"
    error "Step $step_num not found or already marked done in $PLAN_FILE"
  fi
}

set_status() {
  local status="$1"
  case "$status" in
    in-progress|blocked|complete) ;;
    *) error "Invalid status '$status'. Must be one of: in-progress, blocked, complete" ;;
  esac

  local tmp_file
  tmp_file="$(mktemp)"

  if grep -qiE '^status:' "$PLAN_FILE"; then
    sed -E "s/^[Ss]tatus:.*/status: $status/" "$PLAN_FILE" > "$tmp_file"
    mv "$tmp_file" "$PLAN_FILE"
    info "Updated plan status to: $status"
  else
    # Prepend status line after the first heading if present, else at top
    rm -f "$tmp_file"
    error "No 'status:' field found in $PLAN_FILE. Add a 'status:' line to the front-matter first."
  fi
}

# ─── Dispatch ────────────────────────────────────────────────────────────────

case "$ACTION" in
  add-step)   add_step   "$ACTION_VALUE" ;;
  mark-done)  mark_done  "$ACTION_VALUE" ;;
  set-status) set_status "$ACTION_VALUE" ;;
esac

info "Plan file updated: $PLAN_FILE"
