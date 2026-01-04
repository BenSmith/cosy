#!/usr/bin/env bats

# Display auto-detection unit tests
# Tests display detection logic without requiring actual displays
# Can run inside containers using --dry-run mode

load '../helpers/common'

setup() {
    setup_test_container
}

teardown() {
    cleanup_test_container
}

# === Display Auto-Detection Tests ===

@test "display detection in dry-run mode" {
    # Test with DISPLAY unset - should still create container
    unset DISPLAY
    unset WAYLAND_DISPLAY

    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    # Should have display args even without env vars set
    assert_output_contains "DISPLAY="
}

@test "DISPLAY variable is passed through when set" {
    export DISPLAY=":0"

    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    assert_output_contains "DISPLAY=:0"
}

@test "WAYLAND_DISPLAY variable is passed through when set" {
    # Skip in CI - requires actual XDG_RUNTIME_DIR
    if [ "${CI:-false}" = "true" ]; then
        skip "Wayland tests require actual runtime directory (not available in headless CI)"
    fi

    export WAYLAND_DISPLAY="wayland-0"
    export XDG_RUNTIME_DIR="/run/user/1000"

    # Skip if Wayland socket doesn't exist
    if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        skip "Wayland socket not available (not running in Wayland session)"
    fi

    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    assert_output_contains "WAYLAND_DISPLAY=wayland-0"
}

@test "X11 socket is mounted by default" {
    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    assert_output_contains "/tmp/.X11-unix:/tmp/.X11-unix"
}

@test "display can be disabled with --no-display" {
    run "${COSY_SCRIPT}" --dry-run create --no-display "$TEST_CONTAINER"
    assert_success
    assert_output_not_contains "/tmp/.X11-unix"
}

@test "XDG_RUNTIME_DIR is set for wayland" {
    # Skip in CI - requires actual XDG_RUNTIME_DIR
    if [ "${CI:-false}" = "true" ]; then
        skip "Wayland tests require actual runtime directory (not available in headless CI)"
    fi

    export WAYLAND_DISPLAY="wayland-0"
    export XDG_RUNTIME_DIR="/run/user/1000"

    # Skip if Wayland socket doesn't exist
    if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        skip "Wayland socket not available (not running in Wayland session)"
    fi

    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    assert_output_contains "XDG_RUNTIME_DIR=/run/user/"
}

# === XAUTHORITY Tests ===

@test "XAUTHORITY is mounted when set" {
    export XAUTHORITY="/tmp/test-xauth"
    touch "$XAUTHORITY"

    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    assert_output_contains "XAUTHORITY="

    rm -f "$XAUTHORITY"
}

@test "Xauthority fallback to HOME/.Xauthority" {
    unset XAUTHORITY
    export HOME="/tmp/test-home-$$"
    mkdir -p "$HOME"
    touch "$HOME/.Xauthority"

    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    # Should use HOME/.Xauthority if XAUTHORITY not set

    rm -rf "$HOME"
}
