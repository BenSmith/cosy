#!/usr/bin/env bats

# Input validation tests
# Ensures proper validation of container names, flags, and configurations

load '../helpers/common'

# === Container Name Validation ===

@test "invalid container name with spaces is rejected" {
    run "${COSY_SCRIPT}" --dry-run create "invalid name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "invalid container name with special characters is rejected" {
    run "${COSY_SCRIPT}" --dry-run create "test@#$"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "invalid container name with slash is rejected" {
    run "${COSY_SCRIPT}" --dry-run create "test/slash"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "valid container name with hyphens is accepted" {
    run "${COSY_SCRIPT}" --dry-run create test-container-name
    assert_success
    assert_output_contains "test-container-name"
}

@test "valid container name with underscores is accepted" {
    run "${COSY_SCRIPT}" --dry-run create test_container_name
    assert_success
    assert_output_contains "test_container_name"
}

@test "valid container name with numbers is accepted" {
    run "${COSY_SCRIPT}" --dry-run create test123
    assert_success
    assert_output_contains "test123"
}

@test "very long container name is accepted" {
    local long_name="test-container-with-a-very-long-name-that-is-still-valid"
    run "${COSY_SCRIPT}" --dry-run create "$long_name"
    assert_success
    assert_output_contains "$long_name"
}

# === Flag Conflict Validation ===

@test "network flag accepts custom bridge networks" {
    # Since we now support custom bridge networks, any network name is valid
    run "${COSY_SCRIPT}" --dry-run create --network custom-network test
    assert_success
    assert_output_contains "custom-network"
}

# === Volume Mount Tests ===

@test "single volume mount is accepted" {
    run "${COSY_SCRIPT}" --dry-run create -v /tmp:/tmp test-container
    assert_success
    assert_output_contains "/tmp:/tmp"
}

@test "multiple volume mounts are accepted" {
    run "${COSY_SCRIPT}" --dry-run create -v /tmp:/tmp -v /home:/home test-container
    assert_success
    assert_output_contains "/tmp:/tmp"
    assert_output_contains "/home:/home"
}

@test "volume mount with options is accepted" {
    run "${COSY_SCRIPT}" --dry-run create -v /tmp:/tmp:ro test-container
    assert_success
    assert_output_contains "/tmp:/tmp:ro"
}
