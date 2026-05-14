#!/usr/bin/env bash
# get-plan.sh — Retrieve and display a specific plan by ID or name
# Usage: ./get-plan.sh <plan-id-or-name> [--format json|text] [--plans-dir <dir>]

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
PLANS_DIR="${PLANS_DIR:-./plans}"
FORMAT="text"
PLAN_ID=""

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --plans-dir)
      PLANS_DIR="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $(basename "$0") <plan-id-or-name> [--format json|text] [--plans-dir <dir>]"
      echo ""
      echo "Options:"
      echo "  --format     Output format: 'json' or 'text' (default: text)"
      echo "  --plans-dir  Directory where plan files are stored (default: ./plans)"
      exit 0
      ;;
    -*)
      echo "ERROR: Unknown option '$1'" >&2
      exit 1
      ;;
    *)
      if [[ -z "$PLAN_ID" ]]; then
        PLAN_ID="$1"
      else
        echo "ERROR: Unexpected argument '$1'" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [[ -z "$PLAN_ID" ]]; then
  echo "ERROR: Plan ID or name is required." >&2
  echo "Usage: $(basename "$0") <plan-id-or-name> [--format json|text]" >&2
  exit 1
fi

if [[ "$FORMAT" != "text" && "$FORMAT" != "json" ]]; then
  echo "ERROR: --format must be 'text' or 'json', got '$FORMAT'" >&2
  exit 1
fi

if [[ ! -d "$PLANS_DIR" ]]; then
  echo "ERROR: Plans directory not found: $PLANS_DIR" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Locate the plan file
# ---------------------------------------------------------------------------
PLAN_FILE=""

# Try exact filename match first (with and without .md extension)
for candidate in "$PLANS_DIR/$PLAN_ID" "$PLANS_DIR/$PLAN_ID.md"; do
  if [[ -f "$candidate" ]]; then
    PLAN_FILE="$candidate"
    break
  fi
done

# Fall back to searching by ID field inside files
if [[ -z "$PLAN_FILE" ]]; then
  while IFS= read -r -d '' file; do
    if grep -qiE "^(id|plan[_-]?id):[[:space:]]*${PLAN_ID}[[:space:]]*$" "$file" 2>/dev/null; then
      PLAN_FILE="$file"
      break
    fi
  done < <(find "$PLANS_DIR" -maxdepth 2 -name '*.md' -print0 2>/dev/null)
fi

if [[ -z "$PLAN_FILE" ]]; then
  echo "ERROR: No plan found matching '${PLAN_ID}' in ${PLANS_DIR}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [[ "$FORMAT" == "json" ]]; then
  # Emit a minimal JSON representation by parsing front-matter key: value lines
  echo "{"
  echo "  \"file\": \"${PLAN_FILE}\","

  # Parse YAML-style front matter between --- delimiters
  in_frontmatter=0
  first_field=1
  while IFS= read -r line; do
    if [[ "$line" == '---' ]]; then
      (( in_frontmatter++ )) || true
      [[ $in_frontmatter -ge 2 ]] && break
      continue
    fi
    if [[ $in_frontmatter -eq 1 && "$line" =~ ^([A-Za-z_-]+):[[:space:]]*(.*) ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Escape double-quotes in value
      value="${value//\"/\\\"}"
      [[ $first_field -eq 0 ]] && echo ","
      printf '  "%s": "%s"' "$key" "$value"
      first_field=0
    fi
  done < "$PLAN_FILE"

  echo ""
  echo "}"
else
  # Plain text: just print the file contents with a header
  echo "=== Plan: ${PLAN_ID} ==="
  echo "File: ${PLAN_FILE}"
  echo "---"
  cat "$PLAN_FILE"
fi
