#!/usr/bin/env bash
# delete-plan.sh - Delete a plan file and its associated attestation
# Usage: ./delete-plan.sh <plan-name> [--force]

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
DEFAULT_PLANS_DIR=".plans"
ATTEST_SUFFIX=".attested"

# ─── Helpers ──────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") <plan-name> [OPTIONS]

Delete a plan file and its associated attestation file (if present).

Arguments:
  plan-name       Name of the plan to delete (with or without .md extension)

Options:
  --force, -f     Skip confirmation prompt
  --plans-dir     Directory where plans are stored (default: ${DEFAULT_PLANS_DIR})
  --help, -h      Show this help message

Examples:
  $(basename "$0") my-feature
  $(basename "$0") my-feature.md --force
  $(basename "$0") my-feature --plans-dir ./docs/plans
EOF
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────
PLAN_NAME=""
PLANS_DIR="${DEFAULT_PLANS_DIR}"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --plans-dir)
      PLANS_DIR="$2"
      shift 2
      ;;
    --plans-dir=*)
      PLANS_DIR="${1#*=}"
      shift
      ;;
    -*)
      error "Unknown option: $1. Use --help for usage."
      ;;
    *)
      if [[ -z "${PLAN_NAME}" ]]; then
        PLAN_NAME="$1"
      else
        error "Unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

[[ -z "${PLAN_NAME}" ]] && { usage; exit 1; }

# ─── Normalise plan name ───────────────────────────────────────────────────────
# Strip .md extension if provided so we can build paths consistently
PLAN_BASENAME="${PLAN_NAME%.md}"
PLAN_FILE="${PLANS_DIR}/${PLAN_BASENAME}.md"
ATTEST_FILE="${PLANS_DIR}/${PLAN_BASENAME}${ATTEST_SUFFIX}"

# ─── Validation ───────────────────────────────────────────────────────────────
[[ -d "${PLANS_DIR}" ]] || error "Plans directory not found: ${PLANS_DIR}"
[[ -f "${PLAN_FILE}" ]] || error "Plan not found: ${PLAN_FILE}"

# ─── Confirmation ─────────────────────────────────────────────────────────────
if [[ "${FORCE}" == false ]]; then
  echo "The following files will be permanently deleted:"
  echo "  ${PLAN_FILE}"
  [[ -f "${ATTEST_FILE}" ]] && echo "  ${ATTEST_FILE}"
  echo
  read -r -p "Are you sure? [y/N] " CONFIRM
  case "${CONFIRM}" in
    [yY][eE][sS]|[yY]) ;;
    *)
      info "Deletion cancelled."
      exit 0
      ;;
  esac
fi

# ─── Deletion ─────────────────────────────────────────────────────────────────
rm -f "${PLAN_FILE}"
info "Deleted plan: ${PLAN_FILE}"

if [[ -f "${ATTEST_FILE}" ]]; then
  rm -f "${ATTEST_FILE}"
  info "Deleted attestation: ${ATTEST_FILE}"
else
  warn "No attestation file found for '${PLAN_BASENAME}' — skipping."
fi

info "Plan '${PLAN_BASENAME}' has been removed successfully."
