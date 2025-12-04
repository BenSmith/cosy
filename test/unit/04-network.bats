#!/usr/bin/env bats

# Network configuration tests
# Tests network isolation and host network modes

load '../helpers/common'

# === No Network Tests ===

@test "--network none shows network flag" {
    run "${COSY_SCRIPT}" --dry-run create --network none test-container
    assert_success
    assert_has_flag "--network"
}

@test "--network none uses --network none" {
    run "${COSY_SCRIPT}" --dry-run create --network none test-container
    assert_success
    # Should use --network and none (may be on separate lines)
    assert_has_flag "--network"
    assert_output_contains "none"
}

# === Host Network Tests ===

@test "--network host shows network flag" {
    run "${COSY_SCRIPT}" --dry-run create --network host test-container
    assert_success
    assert_has_flag "--network"
}

@test "--network host uses --network host" {
    run "${COSY_SCRIPT}" --dry-run create --network host test-container
    assert_success
    # Should use --network and host (may be on separate lines)
    assert_has_flag "--network"
    assert_output_contains "host"
}

@test "does NOT use --net=host alias" {
    run "${COSY_SCRIPT}" --dry-run create --network host test-container
    assert_success
    assert_has_flag "--network"
    assert_output_not_contains "--net="
    assert_output_not_contains "--net "
}
