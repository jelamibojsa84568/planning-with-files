#!/usr/bin/env bash
# list-plans.sh - List all planning files in the current project
# Usage: ./list-plans.sh [--dir <plans_directory>] [--format <table|json|simple>] [--status <all|pending|complete>]

set -euo pipefail

# Default values
PLANS_DIR=".plans"
FORMAT="table"
STATUS_FILTER="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      PLANS_DIR="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --status)
      STATUS_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--dir <plans_directory>] [--format <table|json|simple>] [--status <all|pending|complete>]"
      echo ""
      echo "Options:"
      echo "  --dir       Directory containing plan files (default: .plans)"
      echo "  --format    Output format: table, json, or simple (default: table)"
      echo "  --status    Filter by status: all, pending, or complete (default: all)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Check if plans directory exists
if [[ ! -d "$PLANS_DIR" ]]; then
  echo "No plans directory found at: $PLANS_DIR" >&2
  exit 0
fi

# Collect plan files
PLAN_FILES=()
while IFS= read -r -d '' file; do
  PLAN_FILES+=("$file")
done < <(find "$PLANS_DIR" -maxdepth 2 -name "*.md" -print0 | sort -z)

if [[ ${#PLAN_FILES[@]} -eq 0 ]]; then
  echo "No plan files found in: $PLANS_DIR"
  exit 0
fi

# Parse a plan file and extract metadata
parse_plan() {
  local file="$1"
  local title=""
  local status="pending"
  local created=""
  local updated=""
  local step_total=0
  local step_done=0

  while IFS= read -r line; do
    if [[ "$line" =~ ^#[[:space:]](.+)$ ]]; then
      [[ -z "$title" ]] && title="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[-*][[:space:]]\[x\] ]]; then
      (( step_done++ )) || true
      (( step_total++ )) || true
    elif [[ "$line" =~ ^[-*][[:space:]]\[[[:space:]]\] ]]; then
      (( step_total++ )) || true
    elif [[ "$line" =~ Created:[[:space:]](.+)$ ]]; then
      created="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Updated:[[:space:]](.+)$ ]]; then
      updated="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Status:[[:space:]](.+)$ ]]; then
      status="${BASH_REMATCH[1]}"
    fi
  done < "$file"

  # Derive status from checkboxes if not explicitly set
  if [[ "$status" == "pending" && "$step_total" -gt 0 && "$step_done" -eq "$step_total" ]]; then
    status="complete"
  fi

  echo "$title|$status|$step_done|$step_total|$created|$updated"
}

# Output results
if [[ "$FORMAT" == "json" ]]; then
  echo "["
  first=true
fi

for file in "${PLAN_FILES[@]}"; do
  IFS='|' read -r title status step_done step_total created updated <<< "$(parse_plan "$file")"

  # Apply status filter
  if [[ "$STATUS_FILTER" != "all" && "$STATUS_FILTER" != "$status" ]]; then
    continue
  fi

  relative_path="${file#./}"

  case "$FORMAT" in
    table)
      printf "%-40s %-10s %s/%s steps\n" "$relative_path" "[$status]" "$step_done" "$step_total"
      [[ -n "$title" ]] && printf "  Title: %s\n" "$title"
      ;;
    simple)
      echo "$relative_path"
      ;;
    json)
      [[ "$first" == "false" ]] && echo ","
      printf '  {"file": "%s", "title": "%s", "status": "%s", "steps_done": %s, "steps_total": %s}' \
        "$relative_path" "$title" "$status" "$step_done" "$step_total"
      first=false
      ;;
  esac
done

if [[ "$FORMAT" == "json" ]]; then
  echo ""
  echo "]"
fi
