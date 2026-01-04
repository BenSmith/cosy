#!/usr/bin/env bats

# Bootstrap integration tests
# Tests hostname setting, custom prompts, and environment setup
# MUST run on host (not inside containers)

load '../helpers/common'

setup() {
    setup_test_container
}

teardown() {
    cleanup_test_container
}

# === Hostname Tests ===

@test "hostname is set to container name" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Check /etc/hostname
    run podman exec "$TEST_CONTAINER" cat /etc/hostname
    assert_success
    assert_output_contains "$TEST_CONTAINER"

    # Verify hostname via /proc (hostname command may not be installed)
    run podman exec "$TEST_CONTAINER" cat /proc/sys/kernel/hostname
    assert_success
    assert_output_contains "$TEST_CONTAINER"
}

@test "hostname persists after container restart" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Stop and restart container
    podman stop "$TEST_CONTAINER" >/dev/null
    podman start "$TEST_CONTAINER" >/dev/null
    sleep 1

    run podman exec "$TEST_CONTAINER" cat /etc/hostname
    assert_success
    assert_output_contains "$TEST_CONTAINER"
}

# === Custom Prompt Tests ===

@test "root bashrc has custom cosy prompt" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Check root .bashrc has custom prompt
    run podman exec "$TEST_CONTAINER" cat /root/.bashrc
    assert_success
    assert_output_contains "# Cosy custom prompt"
    assert_output_contains 'PS1='
    assert_output_contains '[cosy]'
}

@test "user bashrc has custom cosy prompt" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Check user .bashrc has custom prompt
    local user_home
    user_home=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_HOME)

    run podman exec "$TEST_CONTAINER" cat "$user_home/.bashrc"
    assert_success
    assert_output_contains "# Cosy custom prompt"
    assert_output_contains 'PS1='
    assert_output_contains '[cosy]'
}

@test "root prompt has red color code" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Check for bright red color code (1;91m)
    run podman exec "$TEST_CONTAINER" grep "033\[1;91m" /root/.bashrc
    assert_success
}

@test "user prompt has green color code" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Check for bold green color code (01;32m)
    local user_home
    user_home=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_HOME)

    run podman exec "$TEST_CONTAINER" grep "033\[01;32m" "$user_home/.bashrc"
    assert_success
}

@test "root prompt includes username, hostname, and path" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Check prompt format includes \u (user), \h (host), \w (path)
    run podman exec "$TEST_CONTAINER" grep '\\u@\\h:\\w' /root/.bashrc
    assert_success
}

@test "root bashrc is in /root directory" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify /root/.bashrc exists and has correct content
    run podman exec "$TEST_CONTAINER" test -f /root/.bashrc
    assert_success

    # Verify it has the cosy prompt
    run podman exec "$TEST_CONTAINER" grep -q "Cosy custom prompt" /root/.bashrc
    assert_success
}

@test "root prompt is sourced in interactive shell" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Test that PS1 gets set when .bashrc is sourced with PS1 preset
    run podman exec "$TEST_CONTAINER" bash -c 'export PS1="test"; source /root/.bashrc; echo "$PS1"'
    assert_success
    assert_output_contains '[cosy]'
    assert_output_contains '\u@\h:\w'
}

# === Environment Variable Tests ===

@test "COSY_CONTAINER_NAME environment variable is set" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_NAME
    assert_success
    assert_output_contains "$TEST_CONTAINER"
}

@test "COSY_CONTAINER_USER environment variable is set" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_USER
    assert_success
}

@test "COSY_CONTAINER_HOME environment variable is set" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_HOME
    assert_success
}

# === XDG Directory Tests ===

@test "XDG_RUNTIME_DIR has correct ownership" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    local uid
    uid=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_UID)

    # Check ownership and permissions
    run podman exec "$TEST_CONTAINER" stat -c "%u:%a" "/run/user/$uid"
    assert_success
    assert_output_contains "$uid:700"
}

@test "XDG_STATE_HOME directory is created" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    local user_home
    user_home=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_HOME)

    run podman exec "$TEST_CONTAINER" test -d "$user_home/.local/state"
    assert_success
}

# === User Groups Tests ===

@test "user is added to specified group with --groups" {
    run "${COSY_SCRIPT}" create --groups wheel "$TEST_CONTAINER"
    assert_success

    # Check user is in wheel group
    local username
    username=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_USER)

    run podman exec "$TEST_CONTAINER" id -nG "$username"
    assert_success
    assert_output_contains "wheel"
}

@test "user is added to multiple groups with --groups" {
    run "${COSY_SCRIPT}" create --groups wheel,users,audio "$TEST_CONTAINER"
    assert_success

    local username
    username=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_USER)

    # Check user is in all specified groups
    run podman exec "$TEST_CONTAINER" id -nG "$username"
    assert_success
    assert_output_contains "wheel"
    assert_output_contains "users"
    assert_output_contains "audio"
}

@test "groups are stored in container label" {
    "${COSY_SCRIPT}" create --groups wheel,docker "$TEST_CONTAINER"

    run podman inspect --format '{{index .Config.Labels "cosy.groups"}}' "$TEST_CONTAINER"
    assert_success
    assert_output_contains "wheel,docker"
}

@test "groups are preserved during recreate" {
    "${COSY_SCRIPT}" create --groups wheel "$TEST_CONTAINER"

    # Recreate container
    run "${COSY_SCRIPT}" recreate --yes "$TEST_CONTAINER"
    assert_success

    # Ensure container is running
    podman start "$TEST_CONTAINER" >/dev/null 2>&1 || true
    sleep 1

    # Verify groups are still present
    local username
    username=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_USER)

    run podman exec "$TEST_CONTAINER" id -nG "$username"
    assert_success
    assert_output_contains "wheel"
}

@test "container works without --groups flag" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # User should be created but not in supplementary groups
    local username
    username=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_USER)

    run podman exec "$TEST_CONTAINER" id -u "$username"
    assert_success
}

@test "COSY_GROUPS environment variable sets default groups" {
    export COSY_GROUPS="wheel"
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    local username
    username=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_USER)

    run podman exec "$TEST_CONTAINER" id -nG "$username"
    assert_success
    assert_output_contains "wheel"

    unset COSY_GROUPS
}

@test "--groups flag overrides COSY_GROUPS environment variable" {
    export COSY_GROUPS="audio"
    run "${COSY_SCRIPT}" create --groups wheel "$TEST_CONTAINER"
    assert_success

    local username
    username=$(podman exec "$TEST_CONTAINER" printenv COSY_CONTAINER_USER)

    run podman exec "$TEST_CONTAINER" id -nG "$username"
    assert_success
    assert_output_contains "wheel"
    assert_output_not_contains "audio"

    unset COSY_GROUPS
}
