#!/usr/bin/env bats

# Command history logging tests
# Tests the COSY_COMMAND_HISTORY feature for logging podman operations

load '../helpers/common'

setup() {
    setup_test_container
    # Use temp file for command history in tests
    export COSY_COMMAND_HISTORY=true
    export COSY_COMMAND_HISTORY_FILE="/tmp/cosy-test-history-$$.jsonl"
}

teardown() {
    cleanup_test_container
    rm -f "$COSY_COMMAND_HISTORY_FILE"
}

# === Basic Logging Tests ===

@test "command history is disabled by default" {
    unset COSY_COMMAND_HISTORY
    rm -f "$COSY_COMMAND_HISTORY_FILE"

    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success

    # File should not be created
    [ ! -f "$COSY_COMMAND_HISTORY_FILE" ]
}

@test "command history is enabled with COSY_COMMAND_HISTORY=true" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # File should exist
    [ -f "$COSY_COMMAND_HISTORY_FILE" ]

    # Should contain JSON
    run cat "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "\"version\""
    assert_output_contains "\"podman_command\""
}

@test "command history uses custom file location" {
    export COSY_COMMAND_HISTORY_FILE="/tmp/custom-history-$$.jsonl"

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    [ -f "/tmp/custom-history-$$.jsonl" ]
    rm -f "/tmp/custom-history-$$.jsonl"
}

# === JSON Format Tests ===

@test "command history creates valid JSON-lines format" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Each line should be valid JSON
    while IFS= read -r line; do
        echo "$line" | command jq empty || {
            echo "Invalid JSON: $line"
            return 1
        }
    done < "$COSY_COMMAND_HISTORY_FILE"
}

@test "command history includes required fields" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run cat "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "\"version\":\"1.0\""
    assert_output_contains "\"timestamp\""
    assert_output_contains "\"invocation_id\""
    assert_output_contains "\"sequence\""
    assert_output_contains "\"cosy_version\""
    assert_output_contains "\"podman_command\""
    assert_output_contains "\"podman_args\""
}

@test "command history includes container metadata" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run cat "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "\"container_name\":\"$TEST_CONTAINER\""
    assert_output_contains "\"image\""
    assert_output_contains "\"features\""
}

@test "command history includes exit codes" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run cat "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "\"exit_code\":0"
}

@test "command history includes duration" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run cat "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "\"duration_ms\""
}

# === Session ID Tests ===

@test "command history includes session ID" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run cat "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "\"session_id\""

    # Session ID should be non-empty
    local session_id=$(command jq -r '.session_id' "$COSY_COMMAND_HISTORY_FILE" | head -1)
    [ -n "$session_id" ]
    [ "$session_id" != "null" ]
}

@test "session ID is stored in container label" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Get session ID from log
    local log_session=$(command jq -r '.session_id' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Get session ID from container label
    local label_session=$(podman inspect --format '{{index .Config.Labels "cosy.session_id"}}' "$TEST_CONTAINER")

    [ "$log_session" = "$label_session" ]
}

@test "same session ID used for multiple operations in one invocation" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Get all session IDs
    local session_ids=$(command jq -r '.session_id' "$COSY_COMMAND_HISTORY_FILE" | sort -u)
    local count=$(echo "$session_ids" | wc -l)

    # Should only have one unique session ID
    [ "$count" -eq 1 ]
}

@test "recreate preserves session ID" {
    # Create container
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    local original_session=$(command jq -r '.session_id' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Clear log
    rm -f "$COSY_COMMAND_HISTORY_FILE"

    # Recreate container
    run "${COSY_SCRIPT}" recreate --yes "$TEST_CONTAINER"
    assert_success

    local new_session=$(command jq -r '.session_id' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Session ID should be preserved
    [ "$original_session" = "$new_session" ]
}

# === Invocation ID Tests ===

@test "invocation ID is unique per command" {
    # First invocation
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success
    local invocation1=$(command jq -r '.invocation_id' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Clear log
    rm -f "$COSY_COMMAND_HISTORY_FILE"

    # Second invocation
    run "${COSY_SCRIPT}" enter "$TEST_CONTAINER" echo test
    assert_success
    local invocation2=$(command jq -r '.invocation_id' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Invocation IDs should be different
    [ "$invocation1" != "$invocation2" ]
}

@test "invocation ID format is timestamp-pid" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    local invocation=$(command jq -r '.invocation_id' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Should match pattern: numbers-numbers
    [[ "$invocation" =~ ^[0-9]+-[0-9]+$ ]]
}

@test "same invocation ID for all operations in one command" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Get all invocation IDs
    local invocation_ids=$(command jq -r '.invocation_id' "$COSY_COMMAND_HISTORY_FILE" | sort -u)
    local count=$(echo "$invocation_ids" | wc -l)

    # Should only have one unique invocation ID
    [ "$count" -eq 1 ]
}

# === Sequence Number Tests ===

@test "sequence numbers increment within invocation" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Get all sequence numbers
    local sequences=$(command jq -r '.sequence' "$COSY_COMMAND_HISTORY_FILE")

    # Should start at 1
    local first=$(echo "$sequences" | head -1)
    [ "$first" -eq 1 ]

    # Should increment
    local prev=0
    while IFS= read -r seq; do
        [ "$seq" -gt "$prev" ]
        prev=$seq
    done <<< "$sequences"
}

# === Feature Logging Tests ===

@test "features are logged correctly" {
    run "${COSY_SCRIPT}" create --audio --gpu "$TEST_CONTAINER"
    assert_success

    # Check features in log
    local features=$(command jq -c '.features' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    echo "$features" | command jq -e '.audio == true'
    echo "$features" | command jq -e '.gpu == true'
    echo "$features" | command jq -e '.display == true'
}

@test "network mode is logged correctly" {
    run "${COSY_SCRIPT}" create --network host "$TEST_CONTAINER"
    assert_success

    local network=$(command jq -r '.features.network' "$COSY_COMMAND_HISTORY_FILE" | head -1)
    [ "$network" = "host" ]
}

@test "systemd mode is logged correctly" {
    run "${COSY_SCRIPT}" create --systemd always "$TEST_CONTAINER"
    assert_success

    local systemd=$(command jq -r '.features.systemd' "$COSY_COMMAND_HISTORY_FILE" | head -1)
    [ "$systemd" = "always" ]
}

# === Image Logging Tests ===

@test "image name is logged" {
    run "${COSY_SCRIPT}" create --image fedora:41 "$TEST_CONTAINER"
    assert_success

    run cat "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "\"image\":\"fedora:41\""
}

@test "image ID is logged" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    local image_id=$(command jq -r '.image_id' "$COSY_COMMAND_HISTORY_FILE" | grep -v null | head -1)

    # Should be a sha256 hash
    [[ "$image_id" =~ ^sha256: ]]
}

# === Podman Command Logging Tests ===

@test "create command is logged" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run command jq -r 'select(.podman_command == "create") | .podman_command' "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "create"
}

@test "start command is logged" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run command jq -r 'select(.podman_command == "start") | .podman_command' "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "start"
}

@test "exec command is logged" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run command jq -r 'select(.podman_command == "exec") | .podman_command' "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "exec"
}

@test "rm command is logged" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    rm -f "$COSY_COMMAND_HISTORY_FILE"

    run "${COSY_SCRIPT}" rm "$TEST_CONTAINER"
    assert_success

    run command jq -r 'select(.podman_command == "rm") | .podman_command' "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "rm"
}

@test "stop command is logged" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    rm -f "$COSY_COMMAND_HISTORY_FILE"

    run "${COSY_SCRIPT}" stop "$TEST_CONTAINER"
    assert_success

    run command jq -r 'select(.podman_command == "stop") | .podman_command' "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "stop"
}

# === Podman Args Tests ===

@test "podman args are captured as JSON array" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # podman_args should be a JSON array
    local args=$(command jq -c '.podman_args' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Should start with [ and end with ]
    [[ "$args" =~ ^\[ ]]
    [[ "$args" =~ \]$ ]]
}

@test "podman args include container name" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run command jq -r '.podman_args[]' "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "$TEST_CONTAINER"
}

# === Query Filtering Tests ===

@test "inspect commands are not logged by default" {
    # inspect is called internally but shouldn't be logged
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Count inspect commands in log (should be 0 or very few)
    local inspect_count=$(command jq -r 'select(.podman_command == "inspect") | .podman_command' "$COSY_COMMAND_HISTORY_FILE" | wc -l)

    # Should not log most inspect calls
    [ "$inspect_count" -lt 5 ]
}

@test "ps commands are not logged by default" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # ps is called internally but shouldn't be logged
    local ps_count=$(command jq -r 'select(.podman_command == "ps") | .podman_command' "$COSY_COMMAND_HISTORY_FILE" | wc -l)

    # Should not log ps calls
    [ "$ps_count" -eq 0 ]
}

# === Cosy Command Logging Tests ===

@test "cosy command is logged" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run cat "$COSY_COMMAND_HISTORY_FILE"
    assert_output_contains "\"cosy_command\":\"create\""
}

@test "cosy args are logged as JSON array" {
    run "${COSY_SCRIPT}" create --audio "$TEST_CONTAINER"
    assert_success

    local cosy_args=$(command jq -c '.cosy_args' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Should be JSON array
    [[ "$cosy_args" =~ ^\[ ]]

    # Should contain create and --audio
    echo "$cosy_args" | command jq -e 'contains(["create"])'
    echo "$cosy_args" | command jq -e 'contains(["--audio"])'
}

# === Replay Tests ===

@test "logged commands can be extracted for replay" {
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Extract podman commands
    run command jq -r '"podman " + (.podman_args | join(" "))' "$COSY_COMMAND_HISTORY_FILE"
    assert_success

    # Should start with "podman"
    assert_output_contains "podman"
}

@test "logged create command includes essential args" {
    run "${COSY_SCRIPT}" create --audio "$TEST_CONTAINER"
    assert_success

    # Get create command args
    local create_args=$(command jq -r 'select(.podman_command == "create") | .podman_args | join(" ")' "$COSY_COMMAND_HISTORY_FILE" | head -1)

    # Should contain create and container name
    [[ "$create_args" =~ "create" ]]
    [[ "$create_args" =~ "$TEST_CONTAINER" ]]
}

# === Multiple Command Tests ===

@test "run command logs multiple podman operations" {
    run "${COSY_SCRIPT}" run "$TEST_CONTAINER" echo test
    assert_success

    # Should log create, start, and exec
    local commands=$(command jq -r '.podman_command' "$COSY_COMMAND_HISTORY_FILE" | sort -u)

    echo "$commands" | grep -q "create"
    echo "$commands" | grep -q "start"
    echo "$commands" | grep -q "exec"
}

@test "multiple operations share same invocation ID" {
    run "${COSY_SCRIPT}" run "$TEST_CONTAINER" echo test
    assert_success

    local invocation_ids=$(command jq -r '.invocation_id' "$COSY_COMMAND_HISTORY_FILE" | sort -u | wc -l)

    # All operations should have the same invocation ID
    [ "$invocation_ids" -eq 1 ]
}

# === Error Handling Tests ===

@test "logging failure does not break cosy" {
    # Make log file readonly
    touch "$COSY_COMMAND_HISTORY_FILE"
    chmod 000 "$COSY_COMMAND_HISTORY_FILE"

    # Command should still succeed even if logging fails
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    chmod 644 "$COSY_COMMAND_HISTORY_FILE"
}

@test "missing log directory is created automatically" {
    export COSY_COMMAND_HISTORY_FILE="/tmp/cosy-test-$$/subdir/history.jsonl"

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Directory should be created
    [ -d "/tmp/cosy-test-$$/subdir" ]
    [ -f "/tmp/cosy-test-$$/subdir/history.jsonl" ]

    rm -rf "/tmp/cosy-test-$$"
}

# === Empty/Null Field Tests ===

@test "empty fields are omitted from JSON" {
    # List command has no container name
    run "${COSY_SCRIPT}" list

    if [ -f "$COSY_COMMAND_HISTORY_FILE" ]; then
        # If anything was logged, container_name should be omitted (not present, not null)
        local has_container_name=$(command jq 'has("container_name")' "$COSY_COMMAND_HISTORY_FILE" 2>/dev/null | grep -c "true" || echo "0")
        [ "$has_container_name" -eq 0 ]
    fi
}
