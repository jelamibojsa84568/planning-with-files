#!/usr/bin/env bash
# create-plan.sh
# Creates a new planning file with the standard structure and metadata.
# Usage: ./create-plan.sh <plan-name> [output-dir]

set -euo pipefail

# ─── Helpers ────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $(basename "$0") <plan-name> [output-dir]

Arguments:
  plan-name   Short identifier for the plan (e.g. "add-auth", "refactor-db")
  output-dir  Directory to write the plan file into (default: ./plans)

Examples:
  $(basename "$0") add-user-auth
  $(basename "$0") migrate-database ./docs/plans
EOF
  exit 1
}

log()  { echo "[create-plan] $*"; }
err()  { echo "[create-plan] ERROR: $*" >&2; exit 1; }

# ─── Argument parsing ───────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage

PLAN_NAME="$1"
OUTPUT_DIR="${2:-./plans}"

# Validate plan name: lowercase letters, digits, hyphens only
if ! [[ "$PLAN_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$ ]]; then
  err "Plan name must contain only lowercase letters, digits, and hyphens (e.g. 'add-auth')"
fi

# ─── Derived values ─────────────────────────────────────────────────────────

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_SLUG=$(date -u +"%Y%m%d")
FILE_NAME="${DATE_SLUG}-${PLAN_NAME}.md"
FILE_PATH="${OUTPUT_DIR}/${FILE_NAME}"

# Title: replace hyphens with spaces and title-case each word
PLAN_TITLE=$(echo "$PLAN_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}')

# ─── Create output directory ────────────────────────────────────────────────

mkdir -p "$OUTPUT_DIR"

if [[ -e "$FILE_PATH" ]]; then
  err "File already exists: $FILE_PATH"
fi

# ─── Write plan template ────────────────────────────────────────────────────

cat > "$FILE_PATH" <<TEMPLATE
# Plan: ${PLAN_TITLE}

<!-- meta
id: ${PLAN_NAME}
created: ${TIMESTAMP}
status: draft
attested: false
-->

## Overview

<!-- Briefly describe what this plan accomplishes and why it is needed. -->

TODO: Add overview.

## Goals

- [ ] TODO: Define goal 1
- [ ] TODO: Define goal 2

## Non-Goals

- TODO: List anything explicitly out of scope.

## Steps

### Step 1 — TODO: Name this step

**Status:** pending

TODO: Describe the step.

```bash
# TODO: Add commands or code snippets if applicable
\`\`\`

### Step 2 — TODO: Name this step

**Status:** pending

TODO: Describe the step.

## Verification

Describe how to confirm the plan was executed successfully.

- [ ] TODO: Verification criterion 1
- [ ] TODO: Verification criterion 2

## Rollback

Describe how to undo the changes if something goes wrong.

TODO: Add rollback instructions.

## Notes

<!-- Any additional context, links, or references. -->
TEMPLATE

# ─── Done ───────────────────────────────────────────────────────────────────

log "Plan created: $FILE_PATH"
log "Next steps:"
log "  1. Edit $FILE_PATH to fill in the details."
log "  2. Run attest-plan.sh once the plan is ready for review."
log "  3. Run check-complete.sh to verify all steps are done."
