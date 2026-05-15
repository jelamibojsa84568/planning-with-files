#!/usr/bin/env bash
# reorder-steps.sh - Reorder steps within an existing plan
# Usage: ./reorder-steps.sh <plan-name> <step-number> <new-position>
#        ./reorder-steps.sh <plan-name> --swap <step-a> <step-b>

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
PLANS_DIR="${PLANS_DIR:-.plans}"

# ── Helpers ──────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage:
  $(basename "$0") <plan-name> <step-number> <new-position>
  $(basename "$0") <plan-name> --swap <step-a> <step-b>

Options:
  <plan-name>      Name of the plan (without .md extension)
  <step-number>    Current step number to move
  <new-position>   Target position for the step
  --swap           Swap two steps instead of moving one
  <step-a>         First step number to swap
  <step-b>         Second step number to swap

Environment:
  PLANS_DIR        Directory containing plan files (default: .plans)
EOF
  exit 1
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "INFO: $*"
}

# Resolve the plan file path
resolve_plan_file() {
  local name="$1"
  local file="${PLANS_DIR}/${name}.md"
  [[ -f "$file" ]] || error "Plan not found: $file"
  echo "$file"
}

# Extract step lines with their line numbers from the plan file
# Steps are markdown checkboxes: '- [ ] Step N: ...' or '- [x] Step N: ...'
get_step_lines() {
  local file="$1"
  grep -n '^ *- \[[ xX]\]' "$file" || true
}

# Count total steps in the plan
count_steps() {
  local file="$1"
  get_step_lines "$file" | wc -l | tr -d ' '
}

# Move a step from its current position to a new position
move_step() {
  local file="$1"
  local from="$2"
  local to="$3"

  local total
  total=$(count_steps "$file")

  [[ "$from" -ge 1 && "$from" -le "$total" ]] || \
    error "Step number $from is out of range (1-${total})"
  [[ "$to" -ge 1 && "$to" -le "$total" ]] || \
    error "Target position $to is out of range (1-${total})"
  [[ "$from" -ne "$to" ]] || { info "Step is already at position $to. Nothing to do."; exit 0; }

  # Collect all step line numbers in document order
  local step_line_nums
  mapfile -t step_line_nums < <(get_step_lines "$file" | cut -d: -f1)

  local from_line="${step_line_nums[$((from - 1))]}"
  local to_line="${step_line_nums[$((to - 1))]}"

  # Read the file into an array for manipulation
  mapfile -t lines < "$file"

  # Extract the step content (single line, 0-indexed)
  local step_content="${lines[$((from_line - 1))]}"

  # Build new file: remove the step from its original position, insert at target
  local tmp_file
  tmp_file=$(mktemp)

  awk -v from="$from_line" -v to="$to_line" -v step="$step_content" '
    BEGIN { inserted = 0 }
    NR == from { next }                          # skip original line
    NR == to {
      if (from > to) { print step; inserted = 1 } # insert before target
      print $0
      if (from < to) { print step; inserted = 1 } # insert after target
      next
    }
    { print }
  ' "$file" > "$tmp_file"

  mv "$tmp_file" "$file"
  info "Moved step $from to position $to in plan '$(basename "$file" .md)'."
}

# Swap two steps in the plan
swap_steps() {
  local file="$1"
  local a="$2"
  local b="$3"

  local total
  total=$(count_steps "$file")

  [[ "$a" -ge 1 && "$a" -le "$total" ]] || error "Step $a is out of range (1-${total})"
  [[ "$b" -ge 1 && "$b" -le "$total" ]] || error "Step $b is out of range (1-${total})"
  [[ "$a" -ne "$b" ]] || { info "Cannot swap a step with itself."; exit 0; }

  # Ensure a < b for simpler logic
  [[ "$a" -lt "$b" ]] || { local tmp=$a; a=$b; b=$tmp; }

  local step_line_nums
  mapfile -t step_line_nums < <(get_step_lines "$file" | cut -d: -f1)

  local line_a="${step_line_nums[$((a - 1))]}"
  local line_b="${step_line_nums[$((b - 1))]}"

  mapfile -t lines < "$file"
  local content_a="${lines[$((line_a - 1))]}"
  local content_b="${lines[$((line_b - 1))]}"

  local tmp_file
  tmp_file=$(mktemp)

  awk -v la="$line_a" -v lb="$line_b" -v ca="$content_a" -v cb="$content_b" '
    NR == la { print cb; next }
    NR == lb { print ca; next }
    { print }
  ' "$file" > "$tmp_file"

  mv "$tmp_file" "$file"
  info "Swapped steps $a and $b in plan '$(basename "$file" .md)'."
}

# ── Main ─────────────────────────────────────────────────────────────────────
[[ $# -ge 3 ]] || usage

PLAN_NAME="$1"
shift

PLAN_FILE=$(resolve_plan_file "$PLAN_NAME")

if [[ "$1" == "--swap" ]]; then
  [[ $# -eq 3 ]] || usage
  swap_steps "$PLAN_FILE" "$2" "$3"
else
  [[ $# -eq 2 ]] || usage
  move_step "$PLAN_FILE" "$1" "$2"
fi
