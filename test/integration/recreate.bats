#!/usr/bin/env bats

# Recreate command tests
# Tests for the cosy recreate command with different modes and features

load '../helpers/common'

setup() {
    setup_test_container
    export TEST_CONTAINER="test-recreate-${BATS_TEST_NUMBER}-$$"
    export TEST_CONTAINER_CLONE="test-recreate-clone-${BATS_TEST_NUMBER}-$$"
    export TEST_CONTAINER_COMPLEX="test-recreate-complex-${BATS_TEST_NUMBER}-$$"
}

teardown() {
    "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER" 2>/dev/null || true
    "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER_CLONE" 2>/dev/null || true
    "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER_COMPLEX" 2>/dev/null || true
    "${COSY_SCRIPT}" rm --home "${TEST_CONTAINER}-new" 2>/dev/null || true
}

# === Error Handling Tests ===

@test "recreate with no arguments shows error" {
    run "${COSY_SCRIPT}" recreate
    assert_failure
    assert_output_contains "Usage:"
}

@test "recreate nonexistent container shows error" {
    run "${COSY_SCRIPT}" recreate nonexistent-container-xyz
    assert_failure
    assert_output_contains "does not exist"
}

@test "clone to existing name shows error" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    "${COSY_SCRIPT}" create "$TEST_CONTAINER_CLONE"

    run "${COSY_SCRIPT}" clone "$TEST_CONTAINER" "$TEST_CONTAINER_CLONE"
    assert_failure
    assert_output_contains "already exists"
}

@test "clone with same source and dest shows error" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" clone "$TEST_CONTAINER" "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "must have different names"
}

@test "recreate with too many arguments shows error" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" recreate "$TEST_CONTAINER" extra-arg
    assert_failure
    assert_output_contains "Too many positional arguments"
    assert_output_contains "cosy clone"
}

# === Show Diff Tests ===

@test "recreate --show-diff shows feature changes" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" recreate --show-diff --audio --gpu "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Current configuration"
    assert_output_contains "Requested changes"
}

@test "recreate --show-diff does not recreate container" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    ORIGINAL_ID=$(podman inspect -f '{{.ID}}' "$TEST_CONTAINER")

    "${COSY_SCRIPT}" recreate --show-diff --audio "$TEST_CONTAINER"

    NEW_ID=$(podman inspect -f '{{.ID}}' "$TEST_CONTAINER")
    [ "$ORIGINAL_ID" = "$NEW_ID" ]
}

# === In-Place Recreation Tests ===

@test "recreate in-place with confirmation prompt (--yes skips)" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Recreation successful"
}

@test "recreate in-place changes features" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Audio: enabled"
}

@test "recreate in-place preserves home directory" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    HOME_DIR="$COSY_HOMES_DIR/${TEST_CONTAINER}"
    echo "test data" > "$HOME_DIR/testfile.txt"

    "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"

    [ -f "$HOME_DIR/testfile.txt" ]
    [ "$(cat "$HOME_DIR/testfile.txt")" = "test data" ]
}

@test "recreate in-place uses correct home directory mount (no parent leak)" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    HOME_DIR="$COSY_HOMES_DIR/${TEST_CONTAINER}"
    PARENT_DIR="$COSY_HOMES_DIR"

    echo "marker" > "$HOME_DIR/.recreate-test-marker"

    PARENT_FILES_BEFORE=$(find "$PARENT_DIR" -maxdepth 1 -type f ! -name '.Xauthority' | wc -l)

    "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"

    MOUNT_SOURCE=$(podman inspect "$TEST_CONTAINER" | grep -o "\"Source\": \"[^\"]*$COSY_HOMES_DIR[^\"]*\"" | grep -o "\"[^\"]*\"" | tail -1 | tr -d '"')
    [ "$MOUNT_SOURCE" = "$HOME_DIR" ]

    PARENT_FILES_AFTER=$(find "$PARENT_DIR" -maxdepth 1 -type f ! -name '.Xauthority' | wc -l)
    [ "$PARENT_FILES_BEFORE" -eq "$PARENT_FILES_AFTER" ]

    [ -f "$HOME_DIR/.recreate-test-marker" ]
    [ "$(cat "$HOME_DIR/.recreate-test-marker")" = "marker" ]
}

@test "recreate in-place transfers writable layer" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"

    # /tmp is tmpfs and not preserved across instances, use /var/tmp
    podman exec "$TEST_CONTAINER" bash -c "echo 'test-package' > /var/tmp/test-pkg"
    podman stop "$TEST_CONTAINER"

    "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"

    run podman exec "$TEST_CONTAINER" cat /var/tmp/test-pkg
    assert_success
    assert_output_contains "test-package"

    podman stop "$TEST_CONTAINER"
}

@test "recreate in-place changes network mode" {
    # Skip in CI - nested containers default to host networking
    if [ "${CI:-false}" = "true" ]; then
        skip "Network isolation tests require non-nested containers (CI runs in container)"
    fi

    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Network mode: default"

    "${COSY_SCRIPT}" recreate --yes --network host "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Network mode: host"
}

@test "recreate in-place with multiple feature changes" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" recreate --yes --audio --gpu --dbus --network host "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER" || true

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Audio: enabled"
    assert_output_contains "GPU: enabled"
    assert_output_contains "D-Bus session: enabled"
    assert_output_contains "Network mode: host"
}

# === Clone Mode Tests ===

@test "clone creates new container" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "${TEST_CONTAINER}-new"

    podman container exists "$TEST_CONTAINER"
    podman container exists "${TEST_CONTAINER}-new"
}

@test "clone preserves original container" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    ORIGINAL_ID=$(podman inspect -f '{{.ID}}' "$TEST_CONTAINER")

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "${TEST_CONTAINER}-new"

    NEW_ID=$(podman inspect -f '{{.ID}}' "$TEST_CONTAINER")
    [ "$ORIGINAL_ID" = "$NEW_ID" ]
}

@test "clone copies home directory" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    HOME_DIR="$COSY_HOMES_DIR/${TEST_CONTAINER}"
    echo "original data" > "$HOME_DIR/testfile.txt"

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "${TEST_CONTAINER}-new"

    CLONE_HOME="$COSY_HOMES_DIR/${TEST_CONTAINER}-new"
    [ -f "$CLONE_HOME/testfile.txt" ]
    [ "$(cat "$CLONE_HOME/testfile.txt")" = "original data" ]

    [ -f "$HOME_DIR/testfile.txt" ]
}

@test "clone uses correct home directory mounts (no parent leak)" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    HOME_DIR="$COSY_HOMES_DIR/${TEST_CONTAINER}"
    PARENT_DIR="$COSY_HOMES_DIR"

    echo "original" > "$HOME_DIR/.clone-test-marker"

    PARENT_FILES_BEFORE=$(find "$PARENT_DIR" -maxdepth 1 -type f ! -name '.Xauthority' | wc -l)

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "${TEST_CONTAINER}-new"

    CLONE_HOME="$COSY_HOMES_DIR/${TEST_CONTAINER}-new"

    ORIGINAL_MOUNT=$(podman inspect "$TEST_CONTAINER" | grep -o "\"Source\": \"[^\"]*$COSY_HOMES_DIR[^\"]*\"" | grep -o "\"[^\"]*\"" | tail -1 | tr -d '"')
    CLONE_MOUNT=$(podman inspect "${TEST_CONTAINER}-new" | grep -o "\"Source\": \"[^\"]*$COSY_HOMES_DIR[^\"]*\"" | grep -o "\"[^\"]*\"" | tail -1 | tr -d '"')

    [ "$ORIGINAL_MOUNT" = "$HOME_DIR" ]
    [ "$CLONE_MOUNT" = "$CLONE_HOME" ]

    PARENT_FILES_AFTER=$(find "$PARENT_DIR" -maxdepth 1 -type f ! -name '.Xauthority' | wc -l)
    [ "$PARENT_FILES_BEFORE" -eq "$PARENT_FILES_AFTER" ]

    [ -f "$HOME_DIR/.clone-test-marker" ]
    [ -f "$CLONE_HOME/.clone-test-marker" ]
}

@test "clone transfers writable layer" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"

    podman exec "$TEST_CONTAINER" bash -c "echo 'cloned-data' > /var/tmp/cloned-file"
    podman stop "$TEST_CONTAINER"

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "${TEST_CONTAINER}-new"
    podman start "${TEST_CONTAINER}-new"

    run podman exec "${TEST_CONTAINER}-new" cat /var/tmp/cloned-file
    assert_success
    assert_output_contains "cloned-data"

    podman stop "${TEST_CONTAINER}-new"
}

@test "clone with new features" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" clone --yes --audio --gpu "$TEST_CONTAINER" "${TEST_CONTAINER}-new"
    podman start "${TEST_CONTAINER}-new" || true

    run "${COSY_SCRIPT}" inspect "${TEST_CONTAINER}-new"
    assert_success
    assert_output_contains "Audio: enabled"
    assert_output_contains "GPU: enabled"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_not_contains "Audio: enabled"
    assert_output_not_contains "GPU: enabled"
}

@test "clone modifies home directories independently" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    HOME_DIR="$COSY_HOMES_DIR/${TEST_CONTAINER}"
    echo "original" > "$HOME_DIR/testfile.txt"

    "${COSY_SCRIPT}" clone --yes "$TEST_CONTAINER" "${TEST_CONTAINER}-new"

    CLONE_HOME="$COSY_HOMES_DIR/${TEST_CONTAINER}-new"
    echo "modified" > "$CLONE_HOME/testfile.txt"

    [ "$(cat "$HOME_DIR/testfile.txt")" = "original" ]
    [ "$(cat "$CLONE_HOME/testfile.txt")" = "modified" ]
}

# === Complex Recreation Tests ===

@test "recreate handles container with multiple features" {
    "${COSY_SCRIPT}" create --audio --gpu "$TEST_CONTAINER_COMPLEX"
    podman start "$TEST_CONTAINER_COMPLEX"

    podman exec "$TEST_CONTAINER_COMPLEX" bash -c "echo 'complex' > /var/tmp/test.txt"
    podman stop "$TEST_CONTAINER_COMPLEX"

    "${COSY_SCRIPT}" recreate --yes --audio --gpu --network host "$TEST_CONTAINER_COMPLEX"

    podman start "$TEST_CONTAINER_COMPLEX"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER_COMPLEX"
    assert_success
    assert_output_contains "Audio: enabled"
    assert_output_contains "GPU: enabled"
    assert_output_contains "Network mode: host"

    run podman exec "$TEST_CONTAINER_COMPLEX" cat /var/tmp/test.txt
    assert_success
    assert_output_contains "complex"
    podman stop "$TEST_CONTAINER_COMPLEX"
}

@test "recreate with overlay storage backend verification" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"
    assert_success

    assert_output_not_contains "unsupported storage backend"
}

# === Edge Cases ===

@test "recreate stopped container" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"
    assert_success
}

@test "recreate running container stops it first" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"

    podman ps --filter "name=$TEST_CONTAINER" --format "{{.Names}}" | grep -q "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"
    assert_success

    podman container exists "$TEST_CONTAINER"
}

@test "recreate preserves container state" {
    "${COSY_SCRIPT}" create --audio "$TEST_CONTAINER"

    "${COSY_SCRIPT}" recreate --yes --audio --gpu "$TEST_CONTAINER"

    podman container exists "$TEST_CONTAINER"
}

@test "recreate adds device feature" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" recreate --yes --device /dev/kvm "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Devices: /dev/kvm"
}

@test "recreate with multiple devices" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" recreate --yes --device /dev/null --device /dev/zero "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Devices:"
    assert_output_contains "/dev/null"
    assert_output_contains "/dev/zero"
}

# === Post-Recreate Fixup Tests ===

@test "recreate fixes hostname to correct name" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" recreate --yes "$TEST_CONTAINER"

    podman start "$TEST_CONTAINER"

    run podman exec "$TEST_CONTAINER" cat /etc/hostname
    assert_success
    [ "$(echo "$output" | tr -d '\n')" = "$TEST_CONTAINER" ]

    # Try multiple methods since not all containers have these commands installed
    if podman exec "$TEST_CONTAINER" command -v hostname >/dev/null 2>&1; then
        run podman exec "$TEST_CONTAINER" hostname
        assert_success
        [ "$(echo "$output" | tr -d '\n')" = "$TEST_CONTAINER" ]
    elif podman exec "$TEST_CONTAINER" command -v hostnamectl >/dev/null 2>&1; then
        run podman exec "$TEST_CONTAINER" hostnamectl hostname
        assert_success
        [ "$(echo "$output" | tr -d '\n')" = "$TEST_CONTAINER" ]
    else
        run podman exec "$TEST_CONTAINER" cat /proc/sys/kernel/hostname
        assert_success
        [ "$(echo "$output" | tr -d '\n')" = "$TEST_CONTAINER" ]
    fi

    podman stop "$TEST_CONTAINER"
}

@test "recreate fixes /run/user permissions" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    "${COSY_SCRIPT}" recreate --yes "$TEST_CONTAINER"

    HOST_UID=$(id -u)
    run "${COSY_SCRIPT}" run "$TEST_CONTAINER" -- stat -c "%u:%g" "/run/user/$HOST_UID"
    assert_success
    assert_output_contains "$HOST_UID:$(id -g)"
}

# === Create-If-Missing Tests ===

@test "recreate nonexistent container with no options shows error" {
    run "${COSY_SCRIPT}" recreate nonexistent-container-xyz
    assert_failure
    assert_output_contains "No container found and no options provided"
}

@test "recreate nonexistent container with options offers to create" {
    run "${COSY_SCRIPT}" recreate --yes --gpu "$TEST_CONTAINER"
    assert_success
    assert_output_contains "does not exist"
    assert_output_contains "Creating new container"

    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "GPU: enabled"
}

@test "recreate nonexistent container reuses existing home directory" {
    mkdir -p "$COSY_HOMES_DIR/$TEST_CONTAINER"
    echo "test file" > "$COSY_HOMES_DIR/$TEST_CONTAINER/testfile"

    run "${COSY_SCRIPT}" recreate --yes --audio "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Using existing home directory"

    run "${COSY_SCRIPT}" run "$TEST_CONTAINER" cat testfile
    assert_success
    assert_output_contains "test file"
}
