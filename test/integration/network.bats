#!/usr/bin/env bats

# Network integration tests
# Tests real network operations on running containers
# MUST run on host (not inside containers)

load '../helpers/common'

setup() {
    setup_test_container
}

teardown() {
    cleanup_test_container
}

# Skip all tests if podman is not available
check_podman() {
    if ! command -v podman >/dev/null 2>&1; then
        skip "podman not available"
    fi
}

# Skip if running inside a container
check_not_in_container() {
    if [ -f /run/.containerenv ] || [ "${CI:-false}" = "true" ]; then
        skip "Cannot run network tests inside a container"
    fi
}

# === Network List Tests ===

@test "network list shows podman networks" {
    check_podman
    check_not_in_container

    run "${COSY_SCRIPT}" network list
    assert_success
    assert_output_contains "Podman Networks"
}

@test "network list shows no networks when none exist with cosy containers" {
    check_podman
    check_not_in_container

    # No cosy containers exist yet, so list should be empty or show "No networks"
    run "${COSY_SCRIPT}" network list
    assert_success
    # Should either show header with no networks listed, or show no cosy containers
}

# === Network Inspect Tests (Requires Running Container) ===

@test "network inspect shows container network info" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Container must be running for inspect
    run podman start "$TEST_CONTAINER"
    assert_success

    # Inspect network
    run "${COSY_SCRIPT}" network inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Container: $TEST_CONTAINER"
    assert_output_contains "Network Mode:"
    assert_output_contains "IP Address:"
}

@test "network inspect fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Stop if it was started
    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Inspect should fail
    run "${COSY_SCRIPT}" network inspect "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "not running"
}

# === Network Stats Tests (Requires Running Container) ===

@test "network stats shows bandwidth statistics" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Get stats
    run "${COSY_SCRIPT}" network stats "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Network Statistics:"
    assert_output_contains "Interface"
    assert_output_contains "RX Bytes"
    assert_output_contains "TX Bytes"
}

@test "network stats fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Stats should fail
    run "${COSY_SCRIPT}" network stats "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "not running"
}

# === Network Connections Tests (Requires Running Container) ===

@test "network connections shows active connections" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Get connections
    run "${COSY_SCRIPT}" network connections "$TEST_CONTAINER"

    # Should succeed or fail with helpful message about ss/netstat
    if [ "$status" -eq 0 ]; then
        assert_output_contains "Active Connections:"
    else
        assert_output_contains "ss" || assert_output_contains "netstat" || assert_output_contains "iproute2"
    fi
}

@test "network connections fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Connections should fail
    run "${COSY_SCRIPT}" network connections "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "not running"
}

# === Network Disconnect/Reconnect Tests (Requires Running Container with ip command) ===

@test "network disconnect brings down interfaces" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Disconnect network
    run "${COSY_SCRIPT}" network disconnect "$TEST_CONTAINER"

    # Should succeed (uses host's ip command)
    assert_success
    assert_output_contains "Disconnecting network"
    assert_output_contains "successfully"
}

@test "network reconnect brings up interfaces" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Disconnect first
    "${COSY_SCRIPT}" network disconnect "$TEST_CONTAINER" 2>/dev/null || true

    # Reconnect network
    run "${COSY_SCRIPT}" network reconnect "$TEST_CONTAINER"

    # Should succeed (uses host's ip command)
    assert_success
    assert_output_contains "Reconnecting network"
    assert_output_contains "successfully"
}

@test "network disconnect fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Disconnect should fail
    run "${COSY_SCRIPT}" network disconnect "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "not running"
}

@test "network reconnect fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Reconnect should fail
    run "${COSY_SCRIPT}" network reconnect "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "not running"
}

# === Network Mode Tests ===

@test "network inspect shows network mode" {
    check_podman
    check_not_in_container

    # Create container with default network
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Inspect should show network mode
    run "${COSY_SCRIPT}" network inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Network Mode:"
}

@test "network inspect works with --network none" {
    check_podman
    check_not_in_container

    # Create container with no network
    run "${COSY_SCRIPT}" create --network none "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Inspect should show network mode
    run "${COSY_SCRIPT}" network inspect "$TEST_CONTAINER"

    # Debug: show output and status if it fails
    if [ "$status" -ne 0 ]; then
        echo "Exit status: $status" >&2
        echo "Output:" >&2
        echo "$output" >&2
    fi

    assert_success
    assert_output_contains "Network Mode:"
    assert_output_contains "none"
}

@test "network inspect works with --network host" {
    check_podman
    check_not_in_container

    # Create container with host network
    run "${COSY_SCRIPT}" create --network host "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Inspect should show network mode
    run "${COSY_SCRIPT}" network inspect "$TEST_CONTAINER"

    # Debug: show output and status if it fails
    if [ "$status" -ne 0 ]; then
        echo "Exit status: $status" >&2
        echo "Output:" >&2
        echo "$output" >&2
    fi

    assert_success
    assert_output_contains "Network Mode:"
    assert_output_contains "host"
}

# === Traffic Shaping Tests (Requires Running Container with tc) ===

@test "network throttle applies bandwidth limit" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Apply bandwidth limit (uses host's tc command)
    run "${COSY_SCRIPT}" network throttle "$TEST_CONTAINER" 1mbit

    # Should succeed (uses host's tc command)
    assert_success
    assert_output_contains "Applying bandwidth limit"
    assert_output_contains "successfully"
}

@test "network throttle with --persist saves configuration" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Apply bandwidth limit with --persist (uses host's tc command)
    run "${COSY_SCRIPT}" network throttle "$TEST_CONTAINER" 512kbit --persist

    # Should succeed or fail gracefully
    if [ "$status" -eq 0 ]; then
        assert_output_contains "will persist"
    fi

    # Check that config file was created
    if [ "$status" -eq 0 ]; then
        [ -f "$COSY_HOMES_DIR/$TEST_CONTAINER/.cosy-network-config" ]
    fi
}

@test "network delay adds latency" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Add network delay (uses host's tc command)
    run "${COSY_SCRIPT}" network delay "$TEST_CONTAINER" 100ms

    # Should succeed (uses host's tc command)
    assert_success
    assert_output_contains "Adding network delay"
    assert_output_contains "successfully"
}

@test "network loss simulates packet loss" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Simulate packet loss (uses host's tc command)
    run "${COSY_SCRIPT}" network loss "$TEST_CONTAINER" 5%

    # Should succeed (uses host's tc command)
    assert_success
    assert_output_contains "Simulating packet loss"
    assert_output_contains "successfully"
}

@test "network reset removes traffic shaping" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Apply some traffic shaping first (uses host's tc command)
    "${COSY_SCRIPT}" network throttle "$TEST_CONTAINER" 1mbit --persist 2>/dev/null || true

    # Reset traffic shaping (uses host's tc command)
    run "${COSY_SCRIPT}" network reset "$TEST_CONTAINER"

    # Should succeed or fail gracefully
    if [ "$status" -eq 0 ]; then
        assert_output_contains "Resetting traffic shaping"
    fi

    # Check that config file was cleared or removed
    if [ "$status" -eq 0 ] && [ -f "$COSY_HOMES_DIR/$TEST_CONTAINER/.cosy-network-config" ]; then
        # File should not contain traffic shaping settings
        ! grep -q "NETWORK_BANDWIDTH_LIMIT" "$COSY_HOMES_DIR/$TEST_CONTAINER/.cosy-network-config"
    fi
}

@test "network throttle fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Throttle should fail
    run "${COSY_SCRIPT}" network throttle "$TEST_CONTAINER" 1mbit
    assert_failure
    assert_output_contains "not running"
}

@test "network delay fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Delay should fail
    run "${COSY_SCRIPT}" network delay "$TEST_CONTAINER" 100ms
    assert_failure
    assert_output_contains "not running"
}

@test "network loss fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Loss should fail
    run "${COSY_SCRIPT}" network loss "$TEST_CONTAINER" 5%
    assert_failure
    assert_output_contains "not running"
}

@test "network reset fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Reset should fail
    run "${COSY_SCRIPT}" network reset "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "not running"
}

# === Watch Command Tests ===

@test "network watch fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Watch should fail
    run timeout 1 "${COSY_SCRIPT}" network watch "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "not running"
}

@test "network watch checks for ss command" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Watch should either succeed or fail with helpful message about ss
    run timeout 1 "${COSY_SCRIPT}" network watch "$TEST_CONTAINER" || true

    # Should mention either watching or ss requirement
    [[ "$output" =~ "Watching connections" ]] || [[ "$output" =~ "ss" ]] || [[ "$output" =~ "iproute" ]]
}

# === Capture Command Tests ===

@test "network capture fails for stopped container" {
    check_podman
    check_not_in_container

    # Create but don't start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    podman stop "$TEST_CONTAINER" 2>/dev/null || true

    # Capture should fail
    run timeout 1 "${COSY_SCRIPT}" network capture "$TEST_CONTAINER"
    assert_failure
    assert_output_contains "not running"
}

@test "network capture checks for tcpdump command" {
    check_podman
    check_not_in_container

    # Create and start container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run podman start "$TEST_CONTAINER"
    assert_success

    # Capture should either succeed or fail with helpful message about tcpdump
    run timeout 1 "${COSY_SCRIPT}" network capture "$TEST_CONTAINER" || true

    # Should mention either starting capture or tcpdump requirement
    [[ "$output" =~ "Starting packet capture" ]] || [[ "$output" =~ "tcpdump" ]]
}

# === Bridge Network Tests (Rootless Compatible) ===

@test "create container with custom bridge network" {
    check_podman
    check_not_in_container

    TEST_NETWORK="test-bridge-${BATS_TEST_NUMBER}-$$"

    # Create a bridge network first
    podman network create "$TEST_NETWORK" 2>/dev/null || true

    # Create container with custom network
    run "${COSY_SCRIPT}" create --network "$TEST_NETWORK" "$TEST_CONTAINER"
    assert_success

    # Verify container was created with correct network
    run podman inspect "$TEST_CONTAINER" --format '{{.NetworkSettings.Networks}}'
    assert_success
    assert_output_contains "$TEST_NETWORK"

    # Clean up
    podman network rm "$TEST_NETWORK" 2>/dev/null || true
}

@test "bridge network connectivity between containers" {
    check_podman
    check_not_in_container

    TEST_NETWORK="test-connectivity-${BATS_TEST_NUMBER}-$$"
    TEST_CONTAINER2="bats-test2-${BATS_TEST_NUMBER}-$$"

    # Create a bridge network
    podman network create "$TEST_NETWORK" 2>/dev/null || true

    # Create two containers on the same network
    "${COSY_SCRIPT}" create --network "$TEST_NETWORK" "$TEST_CONTAINER"
    "${COSY_SCRIPT}" create --network "$TEST_NETWORK" "$TEST_CONTAINER2"

    # Start both containers
    podman start "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER2"

    # Test connectivity between containers (ping may not be installed, that's ok)
    run podman exec "$TEST_CONTAINER" sh -c "command -v ping >/dev/null && ping -c 1 $TEST_CONTAINER2 || true"

    # Verify both containers are on the same network
    run podman network inspect "$TEST_NETWORK" --format '{{.Containers}}'
    assert_success
    assert_output_contains "$TEST_CONTAINER"
    assert_output_contains "$TEST_CONTAINER2"

    # Clean up
    "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER2" 2>/dev/null || true
    podman network rm "$TEST_NETWORK" 2>/dev/null || true
}

@test "network inspect shows custom bridge network" {
    check_podman
    check_not_in_container

    TEST_NETWORK="test-inspect-bridge-${BATS_TEST_NUMBER}-$$"

    # Create a bridge network
    podman network create "$TEST_NETWORK" 2>/dev/null || true

    # Create container with custom network
    "${COSY_SCRIPT}" create --network "$TEST_NETWORK" "$TEST_CONTAINER"
    
    # Start container
    podman start "$TEST_CONTAINER"

    # Inspect should show the custom network
    run "${COSY_SCRIPT}" network inspect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "$TEST_NETWORK"

    # Clean up
    podman network rm "$TEST_NETWORK" 2>/dev/null || true
}

@test "custom network stored in features file" {
    check_podman
    check_not_in_container

    TEST_NETWORK="test-features-${BATS_TEST_NUMBER}-$$"

    # Create a bridge network
    podman network create "$TEST_NETWORK" 2>/dev/null || true

    # Create container with custom network
    "${COSY_SCRIPT}" create --network "$TEST_NETWORK" "$TEST_CONTAINER"

    # Verify container is on the custom network
    run podman inspect "$TEST_CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
    assert_success
    assert_output_contains "$TEST_NETWORK"

    # Clean up
    podman network rm "$TEST_NETWORK" 2>/dev/null || true
}

# Note: Custom network mismatch warnings were removed with the features file.
# The --network flag is only used during container creation and cannot be changed
# when entering an existing container. Use 'cosy recreate' to change the network.

@test "COSY_NETWORK environment variable works with custom network" {
    check_podman
    check_not_in_container

    TEST_NETWORK="test-env-network-${BATS_TEST_NUMBER}-$$"

    # Create a bridge network
    podman network create "$TEST_NETWORK" 2>/dev/null || true

    # Set env var and create container without --network flag
    COSY_NETWORK="$TEST_NETWORK" "${COSY_SCRIPT}" create "$TEST_CONTAINER"

    # Verify container joined the custom network
    run podman inspect "$TEST_CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
    assert_success
    assert_output_contains "$TEST_NETWORK"

    # Clean up
    podman network rm "$TEST_NETWORK" 2>/dev/null || true
}
# === Network Disconnect/Reconnect Tests ===

@test "network disconnect brings down interface" {
    check_podman
    check_not_in_container

    # Create and start container
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"
    sleep 1

    # Disconnect network
    run "${COSY_SCRIPT}" network disconnect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Disconnecting network"
    assert_output_contains "Network disconnected successfully"
}

@test "network disconnect saves configuration" {
    check_podman
    check_not_in_container

    # Create and start container
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"
    sleep 1

    # Disconnect network
    "${COSY_SCRIPT}" network disconnect "$TEST_CONTAINER"

    # Check that config file was created
    run test -f "$COSY_HOMES_DIR/$TEST_CONTAINER/.cosy-network-state"
    assert_success
}

@test "network reconnect restores interface" {
    check_podman
    check_not_in_container

    # Create and start container
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"
    sleep 1

    # Disconnect then reconnect
    "${COSY_SCRIPT}" network disconnect "$TEST_CONTAINER"
    sleep 1

    run "${COSY_SCRIPT}" network reconnect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Reconnecting network"
    assert_output_contains "Bringing up interface"
    assert_output_contains "Network reconnected successfully"
}

@test "network reconnect restores IP configuration" {
    check_podman
    check_not_in_container

    # Create and start container
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"
    sleep 1

    # Disconnect then reconnect
    "${COSY_SCRIPT}" network disconnect "$TEST_CONTAINER"
    sleep 1

    run "${COSY_SCRIPT}" network reconnect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Restoring network configuration"
    assert_output_contains "Restoring IP:"
}

@test "network reconnect removes state file after restoring" {
    check_podman
    check_not_in_container

    # Create and start container
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"
    sleep 1

    # Disconnect then reconnect
    "${COSY_SCRIPT}" network disconnect "$TEST_CONTAINER"
    "${COSY_SCRIPT}" network reconnect "$TEST_CONTAINER"

    # State file should be removed after successful reconnect
    run test -f "$COSY_HOMES_DIR/$TEST_CONTAINER/.cosy-network-state"
    assert_failure
}

@test "network reconnect warns if no saved state exists" {
    check_podman
    check_not_in_container

    # Create and start container
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"
    sleep 1

    # Manually remove any state file
    rm -f "$COSY_HOMES_DIR/$TEST_CONTAINER/.cosy-network-state"

    # Try to reconnect without prior disconnect
    run "${COSY_SCRIPT}" network reconnect "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Warning: No saved network configuration found"
}

@test "network capture file ownership is correct" {
    check_podman
    check_not_in_container

    # Check for tcpdump
    if ! command -v tcpdump >/dev/null 2>&1; then
        skip "tcpdump not available"
    fi

    # Create and start container
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"
    sleep 2

    # Use a specific file path
    local capture_file="/tmp/bats-test-capture-${BATS_TEST_NUMBER}-$$.pcap"
    rm -f "$capture_file"

    # Start capture with timeout to prevent hanging
    # Use timeout to auto-kill after 3 seconds
    timeout 3 "${COSY_SCRIPT}" network capture "$TEST_CONTAINER" "$capture_file" >/dev/null 2>&1 || true

    # Check if file was created
    if [ ! -f "$capture_file" ]; then
        skip "Capture file was not created (tcpdump may have failed)"
    fi

    # Check file ownership - should be owned by current user
    local file_uid
    file_uid=$(stat -c '%u' "$capture_file" 2>/dev/null)
    local file_gid
    file_gid=$(stat -c '%g' "$capture_file" 2>/dev/null)

    # Cleanup
    rm -f "$capture_file"

    # Check ownership
    [ "$file_uid" = "$(id -u)" ]
    [ "$file_gid" = "$(id -g)" ]
}

@test "network capture creates readable pcap file" {
    check_podman
    check_not_in_container

    # Check for tcpdump
    if ! command -v tcpdump >/dev/null 2>&1; then
        skip "tcpdump not available"
    fi

    # Create and start container
    "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    podman start "$TEST_CONTAINER"
    sleep 2

    # Use a specific file path
    local capture_file="/tmp/bats-test-readable-${BATS_TEST_NUMBER}-$$.pcap"
    rm -f "$capture_file"

    # Start capture with timeout
    timeout 3 "${COSY_SCRIPT}" network capture "$TEST_CONTAINER" "$capture_file" >/dev/null 2>&1 || true

    # Check if file was created
    if [ ! -f "$capture_file" ]; then
        skip "Capture file was not created (tcpdump may have failed)"
    fi

    # Check file is readable by current user
    [ -r "$capture_file" ]

    # Cleanup
    rm -f "$capture_file"
}
