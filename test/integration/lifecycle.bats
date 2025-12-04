#!/usr/bin/env bats

# Container lifecycle integration tests
# Tests real container creation, listing, and removal
# MUST run on host (not inside containers)

load '../helpers/common'

setup() {
    setup_test_container
    EXTRA_CONTAINERS_FILE=$(mktemp)
}

teardown() {
    cleanup_test_container
    # Clean up any additional test containers
    if [ -f "$EXTRA_CONTAINERS_FILE" ]; then
        while IFS= read -r container; do
            "${COSY_SCRIPT}" rm --home "$container" 2>/dev/null || true
        done < "$EXTRA_CONTAINERS_FILE"
        rm -f "$EXTRA_CONTAINERS_FILE"
    fi
}

# === Container Creation Tests ===

@test "create subcommand creates container" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Verify container exists
    run podman container exists "$TEST_CONTAINER"
    assert_success
}

@test "create with --gpu flag" {
    run "${COSY_SCRIPT}" create --gpu "$TEST_CONTAINER"
    assert_success

    run podman container exists "$TEST_CONTAINER"
    assert_success
}

@test "create with --audio flag" {
    run "${COSY_SCRIPT}" create --audio "$TEST_CONTAINER"
    assert_success

    run podman container exists "$TEST_CONTAINER"
    assert_success
}

@test "create with --input flag" {
    run "${COSY_SCRIPT}" create --input "$TEST_CONTAINER"
    assert_success

    run podman container exists "$TEST_CONTAINER"
    assert_success
}

@test "create with --network none flag" {
    run "${COSY_SCRIPT}" create --network none "$TEST_CONTAINER"
    assert_success

    run podman container exists "$TEST_CONTAINER"
    assert_success
}

@test "create with multiple flags" {
    run "${COSY_SCRIPT}" create --gpu --audio --network none "$TEST_CONTAINER"
    assert_success

    run podman container exists "$TEST_CONTAINER"
    assert_success
}

@test "valid container name with hyphens is accepted" {
    local test_name="test-container-name-${BATS_TEST_NUMBER}-$$"
    echo "$test_name" >> "$EXTRA_CONTAINERS_FILE"
    run "${COSY_SCRIPT}" create "$test_name"
    assert_success
}

@test "valid container name with underscores is accepted" {
    local test_name="test_container_name_${BATS_TEST_NUMBER}_$$"
    echo "$test_name" >> "$EXTRA_CONTAINERS_FILE"
    run "${COSY_SCRIPT}" create "$test_name"
    assert_success
}

# === Input Validation Tests ===

@test "invalid container name with spaces is rejected" {
    run "${COSY_SCRIPT}" create "invalid name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "invalid container name with special characters is rejected" {
    run "${COSY_SCRIPT}" create "test@#$"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "invalid container name with slash is rejected" {
    run "${COSY_SCRIPT}" create "test/slash"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "network flag accepts custom bridge networks" {
    # Since we now support custom bridge networks, any network name is valid
    # This test just verifies the flag is accepted (actual network validation happens at runtime)
    run "${COSY_SCRIPT}" --dry-run create --network custom-network "$TEST_CONTAINER"
    assert_success
    assert_output_contains "custom-network"
}

# === List Tests ===

@test "list shows created container" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" list
    assert_success
    assert_output_contains "$TEST_CONTAINER"
}

@test "list works with no containers" {
    run "${COSY_SCRIPT}" list
    assert_success
}

@test "list shows features for container with GPU" {
    "${COSY_SCRIPT}" create --gpu "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" list
    assert_success
    assert_output_contains "$TEST_CONTAINER"
    assert_output_contains "gpu"
}

@test "list shows features for container with audio" {
    "${COSY_SCRIPT}" create --audio "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" list
    assert_success
    assert_output_contains "$TEST_CONTAINER"
    assert_output_contains "audio"
}

@test "list shows features for container with input" {
    "${COSY_SCRIPT}" create --input "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" list
    assert_success
    assert_output_contains "$TEST_CONTAINER"
    assert_output_contains "input"
}

@test "list shows features for container with display disabled" {
    "${COSY_SCRIPT}" create --no-display "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" list
    assert_success
    assert_output_contains "$TEST_CONTAINER"
    # Should NOT show "display" in features when disabled
    ! echo "$output" | grep "$TEST_CONTAINER" | grep -q "display"
}

@test "list shows features for container with network none" {
    "${COSY_SCRIPT}" create --network none "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" list
    assert_success
    assert_output_contains "$TEST_CONTAINER"
    assert_output_contains "no-net"
}

@test "list shows features for container with network host" {
    "${COSY_SCRIPT}" create --network host "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" list
    assert_success
    assert_output_contains "$TEST_CONTAINER"
    assert_output_contains "host-net"
}

@test "list shows multiple features" {
    "${COSY_SCRIPT}" create --gpu --audio "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" list
    assert_success
    assert_output_contains "$TEST_CONTAINER"
    assert_output_contains "gpu"
    assert_output_contains "audio"
    assert_output_contains "display"  # enabled by default
}


# === Remove Tests ===

@test "rm removes container but preserves home" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Create a file in the home directory
    touch "$COSY_HOMES_DIR/$TEST_CONTAINER/testfile"

    run "${COSY_SCRIPT}" rm "$TEST_CONTAINER"
    assert_success

    # Container should be gone
    run podman container exists "$TEST_CONTAINER"
    assert_failure

    # Home should still exist
    [ -d "$COSY_HOMES_DIR/$TEST_CONTAINER" ]
    [ -f "$COSY_HOMES_DIR/$TEST_CONTAINER/testfile" ]

    # Note: cleanup_test_container in teardown() will remove the home directory
}

@test "rm --home removes container and home" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    run "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER"
    assert_success

    # Container should be gone
    run podman container exists "$TEST_CONTAINER"
    assert_failure

    # Home should be gone
    [ ! -d "$COSY_HOMES_DIR/$TEST_CONTAINER" ]
}

@test "rm removes multiple containers" {
    local test1="test-multi-1-${BATS_TEST_NUMBER}-$$"
    local test2="test-multi-2-${BATS_TEST_NUMBER}-$$"
    local test3="test-multi-3-${BATS_TEST_NUMBER}-$$"
    echo "$test1" >> "$EXTRA_CONTAINERS_FILE"
    echo "$test2" >> "$EXTRA_CONTAINERS_FILE"
    echo "$test3" >> "$EXTRA_CONTAINERS_FILE"

    "${COSY_SCRIPT}" create "$test1"
    "${COSY_SCRIPT}" create "$test2"
    "${COSY_SCRIPT}" create "$test3"

    run "${COSY_SCRIPT}" rm "$test1" "$test2" "$test3"
    assert_success

    # All containers should be gone
    run podman container exists "$test1"
    assert_failure
    run podman container exists "$test2"
    assert_failure
    run podman container exists "$test3"
    assert_failure

    # Homes should still exist
    [ -d "$COSY_HOMES_DIR/$test1" ]
    [ -d "$COSY_HOMES_DIR/$test2" ]
    [ -d "$COSY_HOMES_DIR/$test3" ]
}

@test "rm --home removes multiple containers and homes" {
    local test1="test-multi-home-1-${BATS_TEST_NUMBER}-$$"
    local test2="test-multi-home-2-${BATS_TEST_NUMBER}-$$"
    echo "$test1" >> "$EXTRA_CONTAINERS_FILE"
    echo "$test2" >> "$EXTRA_CONTAINERS_FILE"

    "${COSY_SCRIPT}" create "$test1"
    "${COSY_SCRIPT}" create "$test2"

    run "${COSY_SCRIPT}" rm --home "$test1" "$test2"
    assert_success

    # All containers should be gone
    run podman container exists "$test1"
    assert_failure
    run podman container exists "$test2"
    assert_failure

    # Homes should be gone
    [ ! -d "$COSY_HOMES_DIR/$test1" ]
    [ ! -d "$COSY_HOMES_DIR/$test2" ]
}

@test "rm handles mix of existing and non-existing containers" {
    local test1="test-mixed-1-${BATS_TEST_NUMBER}-$$"
    local test2="test-nonexistent-${BATS_TEST_NUMBER}-$$"
    echo "$test1" >> "$EXTRA_CONTAINERS_FILE"

    "${COSY_SCRIPT}" create "$test1"

    run "${COSY_SCRIPT}" rm "$test1" "$test2"
    assert_success
    assert_output_contains "Removing container: $test1"
    assert_output_contains "Container '$test2' does not exist"

    # First container should be gone
    run podman container exists "$test1"
    assert_failure
}

# === Dry-run Tests ===

@test "dry-run flag prevents container creation" {
    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    assert_output_contains "podman"

    # Container should not exist
    run podman container exists "$TEST_CONTAINER"
    assert_failure
}

@test "dry-run shows podman commands" {
    run "${COSY_SCRIPT}" --dry-run create --gpu --audio "$TEST_CONTAINER"
    assert_success
    assert_output_contains "podman"
    assert_output_contains "/dev/dri"
}

# === Root Run/Enter Tests ===

@test "run --root executes command as root in existing container" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Run a command as root
    run "${COSY_SCRIPT}" run --root "$TEST_CONTAINER" whoami
    assert_success
    assert_output_contains "root"
}

@test "run --root auto-creates container" {
    # Should auto-create the container
    run "${COSY_SCRIPT}" run --root "$TEST_CONTAINER" echo "hello from root"
    assert_success
    assert_output_contains "hello from root"

    # Verify container exists
    run podman container exists "$TEST_CONTAINER"
    assert_success
}

@test "enter --root opens shell as root" {
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Test that enter --root without command would open a shell as root
    # We can't test interactive shell, so we verify with --dry-run
    run "${COSY_SCRIPT}" --dry-run enter --root "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--user root"
}

# === Environment Variable Integration Tests ===

@test "COSY_GPU environment variable creates container with GPU" {
    COSY_GPU=true "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify container exists
    run podman container exists "$TEST_CONTAINER"
    assert_success

    # Verify GPU feature via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "GPU: enabled"
}

@test "COSY_AUDIO environment variable creates container with audio" {
    COSY_AUDIO=true "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify audio feature via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Audio: enabled"
}

@test "COSY_INPUT environment variable creates container with input devices" {
    COSY_INPUT=true "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify input feature via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Input devices: enabled"
}

@test "COSY_DISPLAY environment variable disables display" {
    COSY_DISPLAY=false "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify display is disabled via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Display: disabled"
}

@test "COSY_PODMAN environment variable mounts podman socket" {
    # Check if podman socket is available
    if [ ! -S "/run/user/$(id -u)/podman/podman.sock" ]; then
        skip "Podman socket not available - enable with: systemctl --user enable --now podman.socket"
    fi

    COSY_PODMAN=true "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify container has podman socket mount
    run podman inspect "$TEST_CONTAINER" --format '{{.HostConfig.Binds}}'
    assert_success
    assert_output_contains "podman.sock"
}

@test "COSY_DBUS environment variable sets up D-Bus" {
    COSY_DBUS=true "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify D-Bus feature via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "D-Bus session: enabled"

    # Verify DBUS_SESSION_BUS_ADDRESS is set
    run podman inspect "$TEST_CONTAINER" --format '{{.Config.Env}}'
    assert_success
    assert_output_contains "DBUS_SESSION_BUS_ADDRESS"
}

@test "COSY_DBUS_SYSTEM environment variable sets up system D-Bus" {
    COSY_DBUS_SYSTEM=true "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify D-Bus system feature via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "D-Bus system: enabled"

    # Verify DBUS_SYSTEM_BUS_ADDRESS is set
    run podman inspect "$TEST_CONTAINER" --format '{{.Config.Env}}'
    assert_success
    assert_output_contains "DBUS_SYSTEM_BUS_ADDRESS"
}

# === Additional Flag Integration Tests ===

@test "create with --dbus flag" {
    "${COSY_SCRIPT}" create --dbus "$TEST_CONTAINER"

    # Verify D-Bus feature via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "D-Bus session: enabled"

    # Verify container has D-Bus environment variable
    run podman inspect "$TEST_CONTAINER" --format '{{.Config.Env}}'
    assert_success
    assert_output_contains "DBUS_SESSION_BUS_ADDRESS"
}

@test "create with --dbus-system flag" {
    "${COSY_SCRIPT}" create --dbus-system "$TEST_CONTAINER"

    # Verify D-Bus system feature via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "D-Bus system: enabled"

    # Verify container has system D-Bus environment variable
    run podman inspect "$TEST_CONTAINER" --format '{{.Config.Env}}'
    assert_success
    assert_output_contains "DBUS_SYSTEM_BUS_ADDRESS"
}

@test "create with --dbus and --dbus-system together" {
    "${COSY_SCRIPT}" create --dbus --dbus-system "$TEST_CONTAINER"

    # Verify both D-Bus features via inspect
    run "${COSY_SCRIPT}" inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "D-Bus session: enabled"
    assert_output_contains "D-Bus system: enabled"

    # Verify both environment variables
    run podman inspect "$TEST_CONTAINER" --format '{{.Config.Env}}'
    assert_success
    assert_output_contains "DBUS_SESSION_BUS_ADDRESS"
    assert_output_contains "DBUS_SYSTEM_BUS_ADDRESS"
}

@test "create with --dbus masks D-Bus services via symlinks" {
    # Test that --dbus flag creates symlinks to mask D-Bus services
    # This works whether or not systemd is running in the container

    run "${COSY_SCRIPT}" create --dbus "$TEST_CONTAINER"
    assert_success

    # Start container so we can check the filesystem
    podman start "$TEST_CONTAINER"

    # Verify D-Bus services are masked via symlinks to /dev/null
    run podman exec "$TEST_CONTAINER" readlink /etc/systemd/system/dbus-broker.service
    assert_success
    assert_output_contains "/dev/null"

    run podman exec "$TEST_CONTAINER" readlink /etc/systemd/system/dbus.socket
    assert_success
    assert_output_contains "/dev/null"

    run podman exec "$TEST_CONTAINER" readlink /etc/systemd/system/dbus.service
    assert_success
    assert_output_contains "/dev/null"

    # Verify D-Bus socket and environment are configured
    run podman inspect "$TEST_CONTAINER" --format '{{.Config.Env}}'
    assert_success
    assert_output_contains "DBUS_SESSION_BUS_ADDRESS"
}

@test "create with --podman flag" {
    # Check if podman socket is available
    if [ ! -S "/run/user/$(id -u)/podman/podman.sock" ]; then
        skip "Podman socket not available - enable with: systemctl --user enable --now podman.socket"
    fi

    "${COSY_SCRIPT}" create --podman "$TEST_CONTAINER"

    # Verify container has podman socket mount
    run podman inspect "$TEST_CONTAINER" --format '{{.HostConfig.Binds}}'
    assert_success
    assert_output_contains "podman.sock"
}

# === Volume Mount Tests ===

@test "can mount to subdirectory within container home" {
    # Create a temporary directory on host to mount
    local host_dir=$(mktemp -d)
    echo "test data" > "$host_dir/testfile.txt"

    # Create container with mount to subdirectory in home
    "${COSY_SCRIPT}" create -v "$host_dir:/home/$USER/Pictures" "$TEST_CONTAINER"

    # Start container
    podman start "$TEST_CONTAINER"

    # Verify mount exists and is readable
    run podman exec "$TEST_CONTAINER" cat "/home/$USER/Pictures/testfile.txt"
    assert_success
    assert_output_contains "test data"

    # Write from container
    podman exec "$TEST_CONTAINER" sh -c "echo 'from container' > /home/$USER/Pictures/newfile.txt"

    # Verify data appears on host
    [ -f "$host_dir/newfile.txt" ]
    [ "$(cat "$host_dir/newfile.txt")" = "from container" ]

    # Cleanup
    rm -rf "$host_dir"
}

@test "cannot mount to container home root directory" {
    # Create a temporary directory on host
    local host_dir=$(mktemp -d)

    # Attempt to mount to /home/$USER should fail
    run "${COSY_SCRIPT}" create -v "$host_dir:/home/$USER" "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "Cannot mount volume to /home/$USER"
    assert_output_contains "home directory (automatic)"

    # Cleanup
    rm -rf "$host_dir"
}
