#!/usr/bin/env bats

# Seccomp syscall blocking verification tests
# These tests actually create containers and verify syscall blocking behavior
#
# IMPORTANT: These tests are SLOW and resource-intensive.
# They are SKIPPED by default in CI/CD.
#
# To run these tests, set:
#   export COSY_TEST_SECCOMP_SYSCALLS=true
#
# Example:
#   COSY_TEST_SECCOMP_SYSCALLS=true bats test/integration/seccomp-syscall.bats

load '../helpers/common'

# Use test fixture
SECCOMP_PROFILE="${BATS_TEST_DIRNAME}/../fixtures/seccomp/test.json"

setup() {
    if [ "${COSY_TEST_SECCOMP_SYSCALLS:-false}" != "true" ]; then
        skip "Syscall tests disabled. Set COSY_TEST_SECCOMP_SYSCALLS=true to enable"
    fi
}

teardown() {
    # Clean up any test containers
    if [ -n "${TEST_CONTAINER}" ]; then
        "${COSY_SCRIPT}" rm "${TEST_CONTAINER}" 2>/dev/null || true
    fi
}

# === Helper Functions ===

create_test_container() {
    local name="$1"
    TEST_CONTAINER="${name}"

    "${COSY_SCRIPT}" create \
        --security-opt "seccomp=${SECCOMP_PROFILE}" \
        --image fedora:43 \
        "${name}"
}

# === Basic Seccomp Verification Tests ===

@test "seccomp profile: container can start with custom profile" {
    create_test_container "test-seccomp-basic"

    # Basic operations should work
    run "${COSY_SCRIPT}" run "${TEST_CONTAINER}" -- \
        sh -c "echo test && ls / >/dev/null"

    assert_success
    assert_output_contains "test"
}
