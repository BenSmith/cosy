#!/usr/bin/env bats

# Clone command specific tests
# Tests for edge cases and features not covered in recreate.bats

load '../helpers/common'

setup() {
    setup_test_container
    export TEST_CONTAINER="test-clone-${BATS_TEST_NUMBER}-$$"
    export TEST_CLONE="test-clone-dest-${BATS_TEST_NUMBER}-$$"
}

teardown() {
    "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER" 2>/dev/null || true
    "${COSY_SCRIPT}" rm --home "$TEST_CLONE" 2>/dev/null || true
}

# === Error Handling Tests ===

@test "clone nonexistent container without args shows error" {
    run "${COSY_SCRIPT}" clone nonexistent-source-xyz "$TEST_CLONE"
    assert_failure
    assert_output_contains "does not exist"
    assert_output_contains "No container found and no options provided"
}

@test "clone with no arguments shows usage" {
    run "${COSY_SCRIPT}" clone
    assert_failure
    assert_output_contains "Usage:"
}

@test "clone with only source shows usage" {
    run "${COSY_SCRIPT}" clone "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "Usage:"
}

# === Create-if-Missing Tests ===

@test "clone nonexistent container with feature args creates new container" {
    # Clone a non-existent source with --audio flag
    # Should create new container with that feature
    run "${COSY_SCRIPT}" clone --yes --audio nonexistent-source "$TEST_CLONE"
    assert_success
    assert_output_contains "does not exist"
    assert_output_contains "Creating new container"

    # Verify new container was created with the feature
    run "${COSY_SCRIPT}" inspect "$TEST_CLONE"
    assert_success
    assert_output_contains "Audio: enabled"
}

@test "clone nonexistent container with multiple features" {
    run "${COSY_SCRIPT}" clone --yes --audio --gpu nonexistent-source "$TEST_CLONE"
    assert_success

    run "${COSY_SCRIPT}" inspect "$TEST_CLONE"
    assert_success
    assert_output_contains "Audio: enabled"
    assert_output_contains "GPU: enabled"
}

@test "clone nonexistent uses existing home directory if present" {
    # Create home directory manually
    HOME_DIR="$COSY_HOMES_DIR/$TEST_CLONE"
    mkdir -p "$HOME_DIR"
    echo "pre-existing data" > "$HOME_DIR/testfile.txt"

    "${COSY_SCRIPT}" clone --yes --audio nonexistent-source "$TEST_CLONE"

    # Verify home directory was used
    [ -f "$HOME_DIR/testfile.txt" ]
    [ "$(cat "$HOME_DIR/testfile.txt")" = "pre-existing data" ]
}

# === Show Diff Tests ===

@test "clone --show-diff displays feature comparison" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" clone --show-diff --audio --gpu "$TEST_CONTAINER" "$TEST_CLONE"
    assert_success
    assert_output_contains "Current configuration"
    assert_output_contains "Requested changes"
}

@test "clone --show-diff does not create container" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" clone --show-diff --audio "$TEST_CONTAINER" "$TEST_CLONE"

    # Verify clone was NOT created
    run podman container exists "$TEST_CLONE"
    assert_failure
}

@test "clone --show-diff shows added features" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" clone --show-diff --audio "$TEST_CONTAINER" "$TEST_CLONE"
    assert_success
    assert_output_contains "Audio"
}

@test "clone --show-diff shows removed features" {
    "${COSY_SCRIPT}" create --audio "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" clone --show-diff "$TEST_CONTAINER" "$TEST_CLONE"
    assert_success
    # Original has audio, new would not
    assert_output_contains "Audio"
}

# === Feature Change Tests ===

@test "clone can remove features from original" {
    "${COSY_SCRIPT}" create --audio --gpu "$TEST_CONTAINER"

    # Clone without audio (should only have GPU)
    "${COSY_SCRIPT}" clone --yes --gpu "$TEST_CONTAINER" "$TEST_CLONE"

    run "${COSY_SCRIPT}" inspect "$TEST_CLONE"
    assert_success
    assert_output_not_contains "Audio: enabled"
    assert_output_contains "GPU: enabled"
}

@test "clone resets network mode to default" {
    "${COSY_SCRIPT}" create --network host "$TEST_CONTAINER"

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "$TEST_CLONE"

    # Inspect the cloned container to verify its network mode
    run "${COSY_SCRIPT}" inspect "$TEST_CLONE"
    assert_success
    assert_output_contains "Network mode: default"
}

@test "clone with systemd mode change" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" clone --yes --systemd always "$TEST_CONTAINER" "$TEST_CLONE"

    run "${COSY_SCRIPT}" inspect "$TEST_CLONE"
    assert_success
    assert_output_contains "Systemd: always"
}

# === Home Directory Tests ===

@test "clone with --home flag is not supported" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # --home is not a valid flag for clone (only for rm)
    # Use --yes to skip confirmation so podman rejects the unknown flag
    run "${COSY_SCRIPT}" clone --yes --home "$TEST_CONTAINER" "$TEST_CLONE"
    assert_failure
    assert_output_contains "unknown flag"
}

@test "clone automatically creates home directory for clone" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "$TEST_CLONE"

    CLONE_HOME="$COSY_HOMES_DIR/$TEST_CLONE"
    [ -d "$CLONE_HOME" ]
}

# === Interactive Confirmation Tests ===

@test "clone without --yes would prompt (testing with --yes)" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # With --yes, should not prompt
    run "${COSY_SCRIPT}" clone --yes --audio "$TEST_CONTAINER" "$TEST_CLONE"
    assert_success
    assert_output_not_contains "Proceed"
}

# === Image Preservation Tests ===

@test "clone preserves original image" {
    "${COSY_SCRIPT}" create --image fedora:41 "$TEST_CONTAINER"

    ORIGINAL_IMAGE=$(podman inspect -f '{{.Config.Image}}' "$TEST_CONTAINER")

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "$TEST_CLONE"

    CLONE_IMAGE=$(podman inspect -f '{{.Config.Image}}' "$TEST_CLONE")
    [ "$ORIGINAL_IMAGE" = "$CLONE_IMAGE" ]
}

@test "clone preserves image from original" {
    "${COSY_SCRIPT}" create --image fedora:41 "$TEST_CONTAINER"

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "$TEST_CLONE"

    CLONE_IMAGE=$(podman inspect -f '{{.Config.Image}}' "$TEST_CLONE")
    [[ "$CLONE_IMAGE" == *"fedora:41"* ]]
}
