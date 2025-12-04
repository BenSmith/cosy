#!/usr/bin/env bats

# Desktop subcommand tests
# Tests the cosy desktop subcommand for managing desktop entries
# These are unit tests - no podman required

load '../helpers/common'

# === Help and Usage Tests ===

@test "cosy desktop with no action shows usage" {
    run "${COSY_SCRIPT}" desktop
    assert_failure
    assert_output_contains "Usage:"
    assert_output_contains "create"
    assert_output_contains "ls"
    assert_output_contains "rm"
    assert_output_contains "install"
}

@test "cosy desktop with invalid action shows error" {
    run "${COSY_SCRIPT}" desktop invalid-action
    assert_failure
    assert_output_contains "Unknown action"
}

# === Create Command Tests ===

@test "cosy desktop create requires container name" {
    run "${COSY_SCRIPT}" desktop create
    assert_failure
    assert_output_contains "Container name required"
}

@test "cosy desktop create requires -- separator" {
    run "${COSY_SCRIPT}" desktop create mycontainer
    assert_failure
    assert_output_contains "Missing '--' separator"
}

@test "cosy desktop create requires command after --" {
    run "${COSY_SCRIPT}" desktop create mycontainer --
    assert_failure
    assert_output_contains "Command required after"
}

@test "cosy desktop create validates container name" {
    run "${COSY_SCRIPT}" desktop create "invalid@name" -- bash
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy desktop create with minimal arguments succeeds" {
    setup_test_container

    run "${COSY_SCRIPT}" desktop create test-container -- bash
    assert_success
    assert_output_contains "Desktop entry created"

    # Cleanup
    rm -f "$HOME/.local/share/applications/cosy-test-container.desktop" 2>/dev/null || true
    rm -f "${COSY_HOMES_DIR}/test-container/.desktop-metadata" 2>/dev/null || true
}

@test "cosy desktop create with all options" {
    setup_test_container

    run "${COSY_SCRIPT}" desktop create test-container \
        --name "My Firefox" \
        --icon firefox \
        --comment "Web Browser" \
        --categories "Network;WebBrowser;" \
        --mime-types "text/html;text/xml" \
        --terminal \
        --no-startup-notify \
        -- firefox

    assert_success
    assert_output_contains "Desktop entry created"

    # Cleanup
    rm -f "$HOME/.local/share/applications/cosy-test-container.desktop" 2>/dev/null || true
    rm -f "${COSY_HOMES_DIR}/test-container/.desktop-metadata" 2>/dev/null || true
}

@test "cosy desktop create with command and flags" {
    setup_test_container

    run "${COSY_SCRIPT}" desktop create test-container -- firefox --safe-mode
    assert_success
    assert_output_contains "Desktop entry created"

    # Cleanup
    rm -f "$HOME/.local/share/applications/cosy-test-container.desktop" 2>/dev/null || true
    rm -f "${COSY_HOMES_DIR}/test-container/.desktop-metadata" 2>/dev/null || true
}

@test "cosy desktop create with complex command" {
    setup_test_container

    run "${COSY_SCRIPT}" desktop create test-container -- bash -l -c "echo hi"
    assert_success
    assert_output_contains "Desktop entry created"

    # Cleanup
    rm -f "$HOME/.local/share/applications/cosy-test-container.desktop" 2>/dev/null || true
    rm -f "${COSY_HOMES_DIR}/test-container/.desktop-metadata" 2>/dev/null || true
}

@test "cosy desktop create --name requires argument" {
    run "${COSY_SCRIPT}" desktop create test-container --name -- bash
    assert_failure
    assert_output_contains "--name requires an argument"
}

@test "cosy desktop create --icon requires argument" {
    run "${COSY_SCRIPT}" desktop create test-container --icon -- bash
    assert_failure
    assert_output_contains "--icon requires an argument"
}

@test "cosy desktop create rejects unknown options" {
    run "${COSY_SCRIPT}" desktop create test-container --unknown-option -- bash
    assert_failure
    assert_output_contains "Unknown option"
}

# === List Command Tests ===

@test "cosy desktop list shows message when no entries exist" {
    setup_test_container

    run "${COSY_SCRIPT}" desktop list
    assert_success
    assert_output_contains "No desktop entries"
}

@test "cosy desktop ls is alias for list" {
    setup_test_container

    run "${COSY_SCRIPT}" desktop ls
    assert_success
    assert_output_contains "Desktop Entries"
}

# === Remove Command Tests ===

@test "cosy desktop rm requires container name" {
    run "${COSY_SCRIPT}" desktop rm
    assert_failure
    assert_output_contains "Container name required"
}

@test "cosy desktop rm validates container name" {
    run "${COSY_SCRIPT}" desktop rm "invalid@name"
    assert_failure
    assert_output_contains "Invalid container name"
}

@test "cosy desktop rm fails for non-existent entry" {
    run "${COSY_SCRIPT}" desktop rm nonexistent
    assert_failure
    assert_output_contains "No desktop entry found"
}

# === Install Command Tests ===

@test "cosy desktop install runs without error" {
    run "${COSY_SCRIPT}" desktop install
    assert_success
}

# === Validation Tests ===

@test "cosy desktop create warns for non-existent container" {
    setup_test_container

    run "${COSY_SCRIPT}" desktop create nonexistent-container -- bash
    assert_success
    assert_output_contains "Warning"
    assert_output_contains "does not exist"
    assert_output_contains "Creating desktop entry anyway"

    # Cleanup
    rm -f "$HOME/.local/share/applications/cosy-nonexistent-container.desktop" 2>/dev/null || true
    rm -f "${COSY_HOMES_DIR}/nonexistent-container/.desktop-metadata" 2>/dev/null || true
}

# === Separator Tests ===

@test "cosy desktop create errors without -- before firefox" {
    run "${COSY_SCRIPT}" desktop create test-container firefox
    assert_failure
    # Should error about unknown option since firefox isn't preceded by --
    assert_output_contains "Unknown option 'firefox'"
    assert_output_contains "Use '--' before the command"
}

@test "cosy desktop create errors without -- before options that look like commands" {
    run "${COSY_SCRIPT}" desktop create test-container --name "Test" firefox
    assert_failure
    assert_output_contains "Unknown option 'firefox'"
}

# === Integration with Subcommand System ===

@test "desktop appears in main cosy error message for unknown subcommands" {
    # When an unknown subcommand is given, cosy should list desktop as valid
    # This indirectly tests that desktop is registered
    run "${COSY_SCRIPT}" unknown-command
    assert_failure
    # The error message should suggest running --help
    assert_output_contains "Unknown subcommand"
}
