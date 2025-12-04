#!/usr/bin/env bats

# Seccomp integration test
# Tests that cosy correctly handles the --seccomp flag

load '../helpers/common'

# Use test fixture
SECCOMP_PROFILE="${BATS_TEST_DIRNAME}/../fixtures/seccomp/test.json"

setup_file() {
    # Check if jq is available for JSON validation
    if ! command -v jq &> /dev/null; then
        echo "# jq is required for seccomp tests" >&3
        exit 1
    fi
}

setup() {
    setup_test_container
}

teardown() {
    cleanup_test_container
}

# === Validation Tests ===

@test "seccomp profile is valid JSON" {
    run jq empty "${SECCOMP_PROFILE}"
    assert_success
}

@test "seccomp profile has required fields" {
    run jq -e '.defaultAction' "${SECCOMP_PROFILE}"
    assert_success

    run jq -e '.syscalls | type == "array"' "${SECCOMP_PROFILE}"
    assert_success
}

# === Integration Tests ===

@test "cosy accepts seccomp profile via --security-opt in dry-run" {
    run "${COSY_SCRIPT}" --dry-run create \
        --security-opt "seccomp=${SECCOMP_PROFILE}" \
        test-seccomp

    assert_success
    assert_output_contains "seccomp="
}

@test "cosy can create container with seccomp profile" {
    local test_container="test-seccomp-${BATS_TEST_NUMBER}-$$"

    run "${COSY_SCRIPT}" create \
        --security-opt "seccomp=${SECCOMP_PROFILE}" \
        "${test_container}"

    assert_success

    # Clean up
    "${COSY_SCRIPT}" rm "${test_container}"
}

@test "created container has seccomp annotation" {
    local test_container="test-seccomp-annotation-${BATS_TEST_NUMBER}-$$"

    "${COSY_SCRIPT}" create \
        --security-opt "seccomp=${SECCOMP_PROFILE}" \
        "${test_container}"

    # Check podman inspect shows seccomp was applied
    run podman inspect "${test_container}" --format '{{.HostConfig.SecurityOpt}}'
    assert_success
    assert_output_contains "seccomp"

    # Clean up
    "${COSY_SCRIPT}" rm "${test_container}"
}
