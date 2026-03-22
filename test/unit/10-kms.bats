#!/usr/bin/env bats

# KMS feature tests - composite feature flag behavior
# Tests that --kms correctly implies gpu, input, systemd, network host, no-display

load '../helpers/common'

# === Composite feature flags ===

@test "KMS implies GPU device access" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_contains "/dev/dri"
}

@test "KMS implies input device access" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_contains "/dev/input"
}

@test "KMS implies systemd mode" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_contains "cosy.systemd=always"
}

@test "KMS implies host networking" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_has_flag "--network host"
}

@test "KMS disables display forwarding" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_not_contains "cosy.display=true"
}

@test "KMS mounts seatd socket" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_contains "/run/seatd.sock"
}

@test "KMS mounts host udev database" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_contains "/run/udev"
}

@test "KMS adds SYS_NICE capability" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_contains "SYS_NICE"
}

@test "KMS sets kms label" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_contains "cosy.kms=true"
}

# === Feature ordering ===

@test "KMS does not mount X11 socket" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_not_contains ".X11-unix"
}

@test "KMS does not mount Wayland socket" {
    run "${COSY_SCRIPT}" --dry-run create --kms test-container
    assert_success
    assert_output_not_contains "wayland-"
}
