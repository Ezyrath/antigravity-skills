#!/usr/bin/env bash
# ==============================================================================
# validate_webapp.sh
# Universal validation runner for Vue 3 / TypeScript / Vuetify web applications.
# Checks: Type checking (vue-tsc), Linting (ESLint), Unit tests (Vitest),
# and optionally End-to-End tests (Cypress).
# ==============================================================================

set -euo pipefail

# ANSI color codes
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_RED="\033[31m"
C_BLUE="\033[34m"

log_info() {
    echo -e "${C_BLUE}${C_BOLD}[INFO]${C_RESET} $1"
}

log_success() {
    echo -e "${C_GREEN}${C_BOLD}[PASS]${C_RESET} $1"
}

log_warn() {
    echo -e "${C_YELLOW}${C_BOLD}[WARN]${C_RESET} $1"
}

log_error() {
    echo -e "${C_RED}${C_BOLD}[FAIL]${C_RESET} $1" >&2
}

PROJECT_DIR="${1:-$PWD}"
RUN_E2E=false

for arg in "$@"; do
    case "$arg" in
        --e2e)
            RUN_E2E=true
            ;;
        --help|-h)
            echo "Usage: $0 [PROJECT_DIR] [--e2e]"
            echo "  PROJECT_DIR : Root directory of the web application (default: current directory)"
            echo "  --e2e       : Also run Cypress End-to-End tests"
            exit 0
            ;;
    esac
done

cd "$PROJECT_DIR"

if [[ ! -f "package.json" ]]; then
    log_error "No package.json found in '$PWD'."
    exit 1
fi

log_info "Starting validation for $(basename "$PWD")..."

# 1. Type Checking
if grep -q '"type-check"' package.json; then
    log_info "Running TypeScript type check (npm run type-check)..."
    npm run type-check
    log_success "Type checking passed."
elif command -v vue-tsc &>/dev/null || npx vue-tsc --version &>/dev/null; then
    log_info "Running vue-tsc --noEmit..."
    npx vue-tsc --noEmit
    log_success "Type checking passed."
else
    log_warn "No type-check script or vue-tsc found, skipping type check."
fi

# 2. Linting
if grep -q '"lint"' package.json; then
    log_info "Running linter (npm run lint)..."
    npm run lint
    log_success "Linting passed."
else
    log_warn "No lint script found in package.json, skipping."
fi

# 3. Unit / Integration Tests (Vitest)
if grep -q '"test"' package.json; then
    log_info "Running unit tests (npm run test)..."
    npm run test
    log_success "Unit tests passed."
else
    log_warn "No test script found in package.json, skipping."
fi

# 4. Optional E2E Tests (Cypress)
if [[ "$RUN_E2E" == true ]]; then
    if grep -q '"test:e2e:all"' package.json; then
        log_info "Running full E2E test stack (npm run test:e2e:all)..."
        npm run test:e2e:all
        log_success "E2E tests passed."
    elif grep -q '"test:e2e"' package.json; then
        log_info "Running E2E tests (npm run test:e2e)..."
        npm run test:e2e
        log_success "E2E tests passed."
    else
        log_warn "No E2E test script found in package.json."
    fi
fi

log_success "All validation stages completed successfully!"
