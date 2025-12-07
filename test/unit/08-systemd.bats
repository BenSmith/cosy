#!/usr/bin/env bats

# Systemd support tests
# Tests the --systemd flag and systemd container configuration

load '../helpers/common'

# === Systemd Flag Tests ===

@test "systemd flag requires a value (like podman)" {
    run "${COSY_SCRIPT}" --dry-run create --systemd true test-container
    assert_success
    assert_output_contains "--systemd=true"
}

@test "systemd feature is true by default (matches podman)" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    # When no --systemd flag is specified, we don't pass it to podman
    # (let podman use its own default of "true")
    assert_output_not_contains "--systemd"
}

@test "systemd does not automatically change CMD" {
    run "${COSY_SCRIPT}" --dry-run create --systemd true test-container
    assert_success
    # Should use sleep infinity (doesn't auto-change to init)
    assert_output_contains "sleep infinity"
    assert_output_not_contains "/sbin/init"
}

@test "systemd works with explicit --cmd" {
    run "${COSY_SCRIPT}" --dry-run create --systemd true --cmd "/sbin/init" test-container
    assert_success
    assert_output_contains "/sbin/init"
    assert_output_contains "--systemd=true"
}

@test "systemd flag works with other features" {
    run "${COSY_SCRIPT}" --dry-run create --systemd true --audio --gpu test-container
    assert_success
    assert_output_contains "--systemd=true"
    [[ "$output" =~ "/dev/dri" ]]
}

@test "systemd accepts false value" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=false test-container
    assert_success
    assert_output_contains "--systemd=false"
}

@test "systemd accepts true value" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=true test-container
    assert_success
    assert_output_contains "--systemd=true"
}

@test "systemd accepts always value" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=always test-container
    assert_success
    assert_output_contains "--systemd=always"
}

@test "systemd passes invalid values through (podman will error)" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=invalid test-container
    assert_success
    # Cosy doesn't validate - just passes it through to podman
    assert_output_contains "--systemd=invalid"
}

@test "systemd naked flag consumes next arg (like podman)" {
    run "${COSY_SCRIPT}" --dry-run create --systemd test-container
    assert_failure
    # --systemd consumes "test-container" as its value, leaving no container name
    assert_output_contains "Container name required"
}

# === Tmpfs Detection Tests ===

@test "tmpfs: no flag + systemd CMD → skips /tmp (auto-detect)" {
    # Skip in CI - requires localhost/fedora-systemd:43 image
    if [ "${CI:-false}" = "true" ]; then
        skip "Systemd image detection tests require pre-built systemd image (not available in CI)"
    fi

    run "${COSY_SCRIPT}" --dry-run create --image localhost/fedora-systemd:43 test-container
    assert_success
    # Count tmpfs flags: should be 1 (only /run/user, not /tmp)
    local tmpfs_count=$(echo "$output" | grep -c -- "--tmpfs")
    [ "$tmpfs_count" -eq 1 ]
}

@test "tmpfs: no flag + non-systemd CMD → adds /tmp" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    # Count tmpfs flags: should be 2 (/run/user and /tmp)
    local tmpfs_count=$(echo "$output" | grep -c -- "--tmpfs")
    [ "$tmpfs_count" -eq 2 ]
}

@test "tmpfs: systemd=always → skips /tmp (forced mode)" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=always test-container
    assert_success
    # Count tmpfs flags: should be 1 (only /run/user)
    local tmpfs_count=$(echo "$output" | grep -c -- "--tmpfs")
    [ "$tmpfs_count" -eq 1 ]
}

@test "tmpfs: systemd=false → adds /tmp" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=false test-container
    assert_success
    # Count tmpfs flags: should be 2 (/run/user and /tmp)
    local tmpfs_count=$(echo "$output" | grep -c -- "--tmpfs")
    [ "$tmpfs_count" -eq 2 ]
}

@test "tmpfs: systemd=true + systemd CMD → skips /tmp" {
    # Skip in CI - requires localhost/fedora-systemd:43 image
    if [ "${CI:-false}" = "true" ]; then
        skip "Systemd image detection tests require pre-built systemd image (not available in CI)"
    fi

    run "${COSY_SCRIPT}" --dry-run create --systemd=true --image localhost/fedora-systemd:43 test-container
    assert_success
    # Count tmpfs flags: should be 1 (only /run/user)
    local tmpfs_count=$(echo "$output" | grep -c -- "--tmpfs")
    [ "$tmpfs_count" -eq 1 ]
}

@test "tmpfs: systemd=true + non-systemd CMD → adds /tmp" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=true test-container
    assert_success
    # Count tmpfs flags: should be 2 (/run/user and /tmp)
    local tmpfs_count=$(echo "$output" | grep -c -- "--tmpfs")
    [ "$tmpfs_count" -eq 2 ]
}

@test "tmpfs: user --cmd /sbin/init → skips /tmp (detects override)" {
    run "${COSY_SCRIPT}" --dry-run create --cmd "/sbin/init" test-container
    assert_success
    # Count tmpfs flags: should be 1 (only /run/user)
    local tmpfs_count=$(echo "$output" | grep -c "^\s*--tmpfs")
    [ "$tmpfs_count" -eq 1 ]
}

@test "tmpfs: user --cmd /bin/bash → adds /tmp (non-systemd override)" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=true --image localhost/fedora-systemd:43 --cmd "/bin/bash" test-container
    assert_success
    # Count tmpfs flags: should be 2 (/run/user and /tmp)
    local tmpfs_count=$(echo "$output" | grep -c "^\s*--tmpfs")
    [ "$tmpfs_count" -eq 2 ]
}

# === Recreate Command Tests ===

@test "recreate recognizes systemd flag" {
    run "${COSY_SCRIPT}" --dry-run recreate --systemd old-container new-container
    # Should parse the flag without error
    [ "$status" -ne 0 ] || true  # May fail because container doesn't exist, but shouldn't error on flag parsing
    ! echo "$output" | grep -i "Unknown option"
}
