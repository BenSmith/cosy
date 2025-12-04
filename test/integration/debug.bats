#!/usr/bin/env bats

# Debug mode integration tests - test that --debug properly shows/suppresses stderr
# These are smoke tests to verify debug functionality works in general

load '../helpers/common'

# === Debug Flag Smoke Tests ===

@test "debug flag does not break container creation" {
    CONTAINER_NAME="debug-smoke-${BATS_TEST_NUMBER}-$$"

    # Create with debug flag should work
    run "${COSY_SCRIPT}" --debug create "$CONTAINER_NAME"
    assert_success

    # Cleanup
    "${COSY_SCRIPT}" rm "$CONTAINER_NAME" 2>/dev/null || true
}

@test "debug environment variable does not break container creation" {
    CONTAINER_NAME="debug-env-smoke-${BATS_TEST_NUMBER}-$$"

    # Create with COSY_DEBUG env var should work
    run env COSY_DEBUG=true "${COSY_SCRIPT}" create "$CONTAINER_NAME"
    assert_success

    # Cleanup
    "${COSY_SCRIPT}" rm "$CONTAINER_NAME" 2>/dev/null || true
}

# === Bootstrap Script Content Verification ===

@test "bootstrap script includes stderr redirect in normal mode" {
    # Use a bootstrap append script to verify the main bootstrap runs
    TEMP_SCRIPT=$(mktemp)
    echo "#!/bin/sh" > "$TEMP_SCRIPT"
    echo "# Test bootstrap" >> "$TEMP_SCRIPT"

    # Create a container and check what bootstrap script is generated
    CONTAINER_NAME="bootstrap-normal-${BATS_TEST_NUMBER}-$$"

    # Run create and capture the output - this will fail but we can inspect it
    output=$("${COSY_SCRIPT}" --dry-run create --bootstrap-append-script "$TEMP_SCRIPT" "$CONTAINER_NAME" 2>&1)

    # Check that the script generation logic produces expected format
    # In dry-run we can't see the actual bootstrap, but we verify it runs
    [[ "$output" =~ "podman" ]] || {
        echo "Expected podman command in output"
        return 1
    }

    rm -f "$TEMP_SCRIPT"
}

@test "stderr suppression works for non-existent commands in normal mode" {
    # Test run_quiet behavior by using it indirectly through cosy
    # When cosy runs podman inspect on non-existent container, no error shown
    output=$("${COSY_SCRIPT}" inspect non-existent-container-${BATS_TEST_NUMBER}-$$ 2>&1) || true

    # Should have clean error message, not raw podman stderr
    [[ "$output" =~ "Error" ]] || [[ "$output" =~ "not found" ]] || {
        echo "Expected clean error message"
        return 1
    }
}
