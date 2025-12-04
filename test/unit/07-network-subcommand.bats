#!/usr/bin/env bats

# Network subcommand tests
# Tests the cosy network subcommand for inspecting and controlling networking

load '../helpers/common'

# === Help and Usage Tests ===

@test "cosy network with no action shows usage" {
    run "${COSY_SCRIPT}" network
    assert_failure
    assert_output_contains "Usage:"
    assert_output_contains "inspect"
    assert_output_contains "stats"
    assert_output_contains "connections"
    assert_output_contains "list"
    assert_output_contains "disconnect"
    assert_output_contains "reconnect"
}

@test "cosy network with invalid action shows error" {
    run "${COSY_SCRIPT}" network invalid-action
    assert_failure
    assert_output_contains "Unknown action"
}

# === Inspect Command Tests ===

@test "cosy network inspect requires container name" {
    run "${COSY_SCRIPT}" network inspect
    assert_failure
    assert_output_contains "No container specified"
}

@test "cosy network inspect validates container name" {
    run "${COSY_SCRIPT}" network inspect "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network inspect fails for non-existent container" {
    run "${COSY_SCRIPT}" network inspect nonexistent
    assert_failure
    assert_output_contains "does not exist"
}

# === Stats Command Tests ===

@test "cosy network stats requires container name" {
    run "${COSY_SCRIPT}" network stats
    assert_failure
    assert_output_contains "No container specified"
}

@test "cosy network stats validates container name" {
    run "${COSY_SCRIPT}" network stats "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network stats fails for non-existent container" {
    run "${COSY_SCRIPT}" network stats nonexistent
    assert_failure
    assert_output_contains "does not exist"
}

# === Connections Command Tests ===

@test "cosy network connections requires container name" {
    run "${COSY_SCRIPT}" network connections
    assert_failure
    assert_output_contains "No container specified"
}

@test "cosy network connections validates container name" {
    run "${COSY_SCRIPT}" network connections "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network connections fails for non-existent container" {
    run "${COSY_SCRIPT}" network connections nonexistent
    assert_failure
    assert_output_contains "does not exist"
}

# === Disconnect Command Tests ===

@test "cosy network disconnect requires container name" {
    run "${COSY_SCRIPT}" network disconnect
    assert_failure
    assert_output_contains "No container specified"
}

@test "cosy network disconnect validates container name" {
    run "${COSY_SCRIPT}" network disconnect "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network disconnect fails for non-existent container" {
    run "${COSY_SCRIPT}" network disconnect nonexistent
    assert_failure
    assert_output_contains "does not exist"
}

# === Reconnect Command Tests ===

@test "cosy network reconnect requires container name" {
    run "${COSY_SCRIPT}" network reconnect
    assert_failure
    assert_output_contains "No container specified"
}

@test "cosy network reconnect validates container name" {
    run "${COSY_SCRIPT}" network reconnect "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network reconnect fails for non-existent container" {
    run "${COSY_SCRIPT}" network reconnect nonexistent
    assert_failure
    assert_output_contains "does not exist"
}

# === Command Parsing Tests ===

@test "network subcommand appears in help" {
    run "${COSY_SCRIPT}" help
    assert_success
    assert_output_contains "network"
}

@test "network subcommand is recognized" {
    run "${COSY_SCRIPT}" network
    assert_failure
    # Should show network usage, not "Unknown subcommand"
    assert_output_contains "Usage:"
    assert_output_not_contains "Unknown subcommand"
}

# === Traffic Shaping Command Tests ===

@test "cosy network throttle requires container name" {
    run "${COSY_SCRIPT}" network throttle
    assert_failure
    assert_output_contains "Missing required arguments"
}

@test "cosy network throttle requires bandwidth argument" {
    run "${COSY_SCRIPT}" network throttle mycontainer
    assert_failure
    assert_output_contains "Missing required arguments"
}

@test "cosy network throttle validates container name" {
    run "${COSY_SCRIPT}" network throttle "invalid@name" 1mbit
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network throttle fails for non-existent container" {
    run "${COSY_SCRIPT}" network throttle nonexistent 1mbit
    assert_failure
    assert_output_contains "does not exist"
}

@test "cosy network delay requires container name" {
    run "${COSY_SCRIPT}" network delay
    assert_failure
    assert_output_contains "Missing required arguments"
}

@test "cosy network delay requires delay argument" {
    run "${COSY_SCRIPT}" network delay mycontainer
    assert_failure
    assert_output_contains "Missing required arguments"
}

@test "cosy network delay validates container name" {
    run "${COSY_SCRIPT}" network delay "invalid@name" 100ms
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network delay fails for non-existent container" {
    run "${COSY_SCRIPT}" network delay nonexistent 100ms
    assert_failure
    assert_output_contains "does not exist"
}

@test "cosy network loss requires container name" {
    run "${COSY_SCRIPT}" network loss
    assert_failure
    assert_output_contains "Missing required arguments"
}

@test "cosy network loss requires percentage argument" {
    run "${COSY_SCRIPT}" network loss mycontainer
    assert_failure
    assert_output_contains "Missing required arguments"
}

@test "cosy network loss validates container name" {
    run "${COSY_SCRIPT}" network loss "invalid@name" 5%
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network loss fails for non-existent container" {
    run "${COSY_SCRIPT}" network loss nonexistent 5%
    assert_failure
    assert_output_contains "does not exist"
}

@test "cosy network reset requires container name" {
    run "${COSY_SCRIPT}" network reset
    assert_failure
    assert_output_contains "No container specified"
}

@test "cosy network reset validates container name" {
    run "${COSY_SCRIPT}" network reset "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network reset fails for non-existent container" {
    run "${COSY_SCRIPT}" network reset nonexistent
    assert_failure
    assert_output_contains "does not exist"
}

# === Watch Command Tests ===

@test "cosy network watch requires container name" {
    run "${COSY_SCRIPT}" network watch
    assert_failure
    assert_output_contains "No container specified"
}

@test "cosy network watch validates container name" {
    run "${COSY_SCRIPT}" network watch "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network watch fails for non-existent container" {
    run "${COSY_SCRIPT}" network watch nonexistent
    assert_failure
    assert_output_contains "does not exist"
}

# === Capture Command Tests ===

@test "cosy network capture requires container name" {
    run "${COSY_SCRIPT}" network capture
    assert_failure
    assert_output_contains "No container specified"
}

@test "cosy network capture validates container name" {
    run "${COSY_SCRIPT}" network capture "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy network capture fails for non-existent container" {
    run "${COSY_SCRIPT}" network capture nonexistent
    assert_failure
    assert_output_contains "does not exist"
}

# === Usage Text Tests ===

@test "network usage shows traffic shaping commands" {
    run "${COSY_SCRIPT}" network
    assert_failure
    assert_output_contains "throttle"
    assert_output_contains "delay"
    assert_output_contains "loss"
    assert_output_contains "reset"
}

@test "network usage shows monitoring commands" {
    run "${COSY_SCRIPT}" network
    assert_failure
    assert_output_contains "watch"
    assert_output_contains "capture"
}

# === Implementation Tests ===

@test "cosy network help text shows host-side tools usage" {
    run "${COSY_SCRIPT}" network
    assert_failure
    assert_output_contains "nsenter"
}
