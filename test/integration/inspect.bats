#!/usr/bin/env bats

# Inspect command tests
# Tests for the cosy inspect command with different output formats

load '../helpers/common'

setup() {
    setup_test_container
    # Create test container for inspection
    export TEST_CONTAINER="test-inspect-${BATS_TEST_NUMBER}-$$"
    export TEST_CONTAINER_COMPLEX="test-inspect-complex-${BATS_TEST_NUMBER}-$$"
}

teardown() {
    # Clean up test containers and their home directories
    "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER" 2>/dev/null || true
    "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER_COMPLEX" 2>/dev/null || true
}

# === Basic Inspect Tests ===

@test "inspect with no arguments shows error" {
    run "${COSY_SCRIPT}" inspect
    assert_failure
    assert_output_contains "Container name required"
}

@test "inspect nonexistent container shows error" {
    run "${COSY_SCRIPT}" inspect nonexistent-container-xyz
    assert_failure
    assert_output_contains "does not exist"
}

@test "inspect shows human format by default" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Container: $TEST_CONTAINER"
    assert_output_contains "Base image:"
    assert_output_contains "Network mode:"
    assert_output_contains "Display:"
    assert_output_contains "Audio:"
}

# === Format Tests ===

@test "inspect --format=human shows human-readable output" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect --format=human "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Container: $TEST_CONTAINER"
    assert_output_contains "Display:"
    assert_output_contains "Audio:"
}

@test "inspect --format=cli shows command-line flags" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--image"
    # Note: --network is omitted when it's the default value
    assert_output_not_contains "--network"
}

@test "inspect --format=cli shows non-default network mode" {
    "${COSY_SCRIPT}" create --network host "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--network host"
}

@test "inspect with invalid format shows error" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect --format=invalid "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "Invalid format"
}

# === Feature Detection Tests ===

@test "inspect detects audio feature" {
    "${COSY_SCRIPT}" create --audio "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Audio: enabled"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--audio"
}

@test "inspect detects GPU feature" {
    "${COSY_SCRIPT}" create --gpu "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER" || true

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "GPU: enabled"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--gpu"
}

@test "inspect detects D-Bus features" {
    "${COSY_SCRIPT}" create --dbus "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "D-Bus session: enabled"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--dbus"
}

@test "inspect detects accessibility bus feature" {
    "${COSY_SCRIPT}" create --a11y "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Accessibility bus: enabled"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--a11y"
}

@test "inspect detects no-display feature" {
    "${COSY_SCRIPT}" create --no-display "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Display: disabled"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--no-display"
}

# === Security Options Tests ===

@test "inspect detects tmpfs mounts" {
    "${COSY_SCRIPT}" create --tmpfs /var/tmp "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Tmpfs mounts:"
    assert_output_contains "/var/tmp"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--tmpfs /var/tmp"
}

@test "inspect detects multiple tmpfs mounts" {
    "${COSY_SCRIPT}" create --tmpfs /var/tmp --tmpfs /app/data "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Tmpfs mounts:"
    assert_output_contains "/var/tmp"
    assert_output_contains "/app/data"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--tmpfs /var/tmp"
    assert_output_contains "--tmpfs /app/data"
}

# === Device Detection Tests ===

@test "inspect detects custom device" {
    "${COSY_SCRIPT}" create --device /dev/kvm "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Devices: /dev/kvm"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--device /dev/kvm"
}

@test "inspect detects multiple devices" {
    "${COSY_SCRIPT}" create --device /dev/null --device /dev/zero "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Devices:"
    assert_output_contains "/dev/null"
    assert_output_contains "/dev/zero"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--device /dev/null"
    assert_output_contains "--device /dev/zero"
}

# === Network Mode Tests ===

@test "inspect detects default network mode" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Network mode: default"
}

@test "inspect detects host network mode" {
    "${COSY_SCRIPT}" create --network host "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Network mode: host"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--network host"
}

@test "inspect detects none network mode" {
    "${COSY_SCRIPT}" create --network none "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Network mode: none"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--network none"
}

# === Mount Detection Tests ===

@test "inspect shows additional mounts" {
    # Create container with a mount
    "${COSY_SCRIPT}" create -v /tmp:/testmount "$TEST_CONTAINER"

    # Container must be running or created for podman inspect to work
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success

    # Start the container so mounts can be inspected
    podman start "$TEST_CONTAINER" || true

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "/tmp:/testmount"
}

@test "inspect shows read-only mount flag" {
    "${COSY_SCRIPT}" create -v /tmp:/testmount:ro "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER" || true

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "/tmp:/testmount:ro"

    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER"
    assert_success
    assert_output_contains "-v /tmp:/testmount:ro"
}

@test "inspect filters out automatic mounts" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER" || true

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success

    # Should not show home directory mount
    assert_output_not_contains "/.local/share/cosy/$TEST_CONTAINER:"

    # Should not show X11 mount in the additional mounts section
    # (it will be in the output, but as part of the automatic display feature)
}

# === Complex Container Test ===

@test "inspect handles container with multiple features" {
    "${COSY_SCRIPT}" create --audio --gpu --network host -v /tmp:/testmount:ro "$TEST_CONTAINER_COMPLEX"
    podman start "$TEST_CONTAINER_COMPLEX" || true

    # Test human format
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER_COMPLEX"
    assert_success
    assert_output_contains "Audio: enabled"
    assert_output_contains "GPU: enabled"
    assert_output_contains "Network mode: host"
    assert_output_contains "/tmp:/testmount:ro"

    # Test CLI format
    run "${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER_COMPLEX"
    assert_success
    assert_output_contains "--audio"
    assert_output_contains "--gpu"
    assert_output_contains "--network host"
    assert_output_contains "-v /tmp:/testmount:ro"
}

# === CLI Format Usability Test ===

@test "cli format output can be parsed" {
    "${COSY_SCRIPT}" create --audio --gpu "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER" || true

    # Get the CLI format output
    CLI_OUTPUT=$("${COSY_SCRIPT}" inspect --format=cli "$TEST_CONTAINER")

    # Verify it contains expected flags
    echo "$CLI_OUTPUT" | grep -q -- "--audio"
    echo "$CLI_OUTPUT" | grep -q -- "--gpu"
    echo "$CLI_OUTPUT" | grep -q -- "--image"
}

# === Image CMD Detection Tests ===

@test "container uses sleep infinity for shell CMDs" {
    "${COSY_SCRIPT}" create --image fedora:43 "$TEST_CONTAINER"

    run podman inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains '"sleep"'
    assert_output_contains '"infinity"'
}

@test "container respects explicit --cmd flag" {
    "${COSY_SCRIPT}" create --image fedora:43 --cmd "sleep 999" "$TEST_CONTAINER"

    run podman inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains '"sleep"'
    assert_output_contains '"999"'
}
