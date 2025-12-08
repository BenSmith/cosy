#!/usr/bin/env bash

# Common test helpers for cosy test suite

# Get path to cosy script (works from any test subdirectory)
COSY_SCRIPT="${BATS_TEST_DIRNAME}/../../cosy"

setup_test_container() {
    export TEST_CONTAINER="bats-test-${BATS_SUITE_TEST_NUMBER:-${BATS_TEST_NUMBER}}-$$"
    export COSY_LOG=false
    # Use test-specific directory instead of ~/.local/share/cosy
    # Include test number and PID to allow concurrent test execution
    export COSY_HOMES_DIR="${COSY_HOMES_DIR:-/tmp/cosy-bats-tests-${BATS_SUITE_TEST_NUMBER:-${BATS_TEST_NUMBER}}-$$}"
    mkdir -p "$COSY_HOMES_DIR"
}

cleanup_test_container() {
    "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER" >/dev/null 2>&1 || true
}

# Handles multi-line dry-run output where flags and values may be on separate lines
assert_has_flag() {
    local flag="$1"
    # Replace spaces in flag with regex pattern that matches space, newline, backslash, or combinations
    local pattern="${flag// /[[:space:]\\]*}"
    [[ "$output" =~ $pattern ]]
}

assert_no_flag() {
    local flag="$1"
    ! [[ "$output" =~ "$flag" ]]
}

assert_success() {
    [ "$status" -eq 0 ]
}

assert_failure() {
    [ "$status" -ne 0 ]
}

# Handles multi-line dry-run output where flags and values may be on separate lines
assert_output_contains() {
    local pattern="$1"
    # Escape regex special characters
    pattern="${pattern//\\/\\\\}"
    pattern="${pattern//\[/\\[}"
    pattern="${pattern//\]/\\]}"
    pattern="${pattern//\(/\\(}"
    pattern="${pattern//\)/\\)}"
    pattern="${pattern//\./\\.}"
    pattern="${pattern//\*/\\*}"
    pattern="${pattern//\+/\\+}"
    pattern="${pattern//\?/\\?}"
    pattern="${pattern//\^/\\^}"
    pattern="${pattern//\$/\\$}"
    pattern="${pattern//\|/\\|}"

    local regex_pattern="${pattern// /[[:space:]\\]*}"
    [[ "$output" =~ $regex_pattern ]]
}

assert_output_not_contains() {
    local pattern="$1"
    ! [[ "$output" =~ "$pattern" ]]
}
