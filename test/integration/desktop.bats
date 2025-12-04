#!/usr/bin/env bats

# Desktop integration tests
# Tests real desktop file operations and container integration
# MUST run on host (not inside containers)

load '../helpers/common'

setup() {
    setup_test_container
    export DESKTOP_FILE="$HOME/.local/share/applications/cosy-${TEST_CONTAINER}.desktop"
    export METADATA_FILE="${COSY_HOMES_DIR}/${TEST_CONTAINER}/.desktop-metadata"
}

teardown() {
    # Clean up desktop files
    rm -f "$DESKTOP_FILE" 2>/dev/null || true
    rm -f "$METADATA_FILE" 2>/dev/null || true
    cleanup_test_container
}

check_podman() {
    if ! command -v podman >/dev/null 2>&1; then
        skip "podman not available"
    fi
}

# === Desktop Entry Creation Tests ===

@test "desktop create generates valid desktop file" {
    check_podman

    # Create container first
    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    # Create desktop entry
    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --name "Test Container" \
        --icon utilities-terminal \
        -- bash
    assert_success

    # Verify desktop file exists
    [ -f "$DESKTOP_FILE" ]

    # Verify desktop file format
    grep -q "^\[Desktop Entry\]$" "$DESKTOP_FILE"
    grep -q "^Type=Application$" "$DESKTOP_FILE"
    grep -q "^Name=Test Container$" "$DESKTOP_FILE"
    grep -q "^Exec=cosy run $TEST_CONTAINER bash$" "$DESKTOP_FILE"
    grep -q "^Icon=utilities-terminal$" "$DESKTOP_FILE"
}

@test "desktop create stores metadata as JSON" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --name "Firefox" \
        --comment "Web Browser" \
        -- firefox
    assert_success

    # Verify metadata file exists
    [ -f "$METADATA_FILE" ]

    # Verify JSON structure
    grep -q '"version": "1.0"' "$METADATA_FILE"
    grep -q "\"container\": \"$TEST_CONTAINER\"" "$METADATA_FILE"
    grep -q '"command": "firefox"' "$METADATA_FILE"
    grep -q '"name": "Firefox"' "$METADATA_FILE"
    grep -q '"comment": "Web Browser"' "$METADATA_FILE"
    grep -q '"created_at"' "$METADATA_FILE"
    grep -q '"modified_at"' "$METADATA_FILE"
}

@test "desktop create with MIME types adds file arguments" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --mime-types "image/png;image/jpeg" \
        -- gimp
    assert_success

    # Should have %F for file arguments
    grep -q "^Exec=cosy run $TEST_CONTAINER gimp %F$" "$DESKTOP_FILE"
}

@test "desktop create with URL handler adds URL arguments" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --mime-types "x-scheme-handler/http;x-scheme-handler/https" \
        -- firefox
    assert_success

    # Should have %U for URL arguments
    grep -q "^Exec=cosy run $TEST_CONTAINER firefox %U$" "$DESKTOP_FILE"
}

@test "desktop create with terminal flag" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --terminal \
        -- bash
    assert_success

    grep -q "^Terminal=true$" "$DESKTOP_FILE"
}

@test "desktop create defaults to container name if no --name" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" -- bash
    assert_success

    grep -q "^Name=$TEST_CONTAINER$" "$DESKTOP_FILE"
}

@test "desktop create with command arguments" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" -- firefox --safe-mode
    assert_success

    grep -q "^Exec=cosy run $TEST_CONTAINER firefox --safe-mode$" "$DESKTOP_FILE"
    grep -q '"command": "firefox --safe-mode"' "$METADATA_FILE"
}

# === Desktop Entry Listing Tests ===

@test "desktop list shows all entries" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --name "My App" \
        -- bash
    assert_success

    run "${COSY_SCRIPT}" desktop list
    assert_success
    assert_output_contains "Container: $TEST_CONTAINER"
    assert_output_contains "Name: My App"
    assert_output_contains "Command: bash"
    assert_output_contains "Status: Active"
}

@test "desktop list shows missing desktop file status" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" -- bash
    assert_success

    # Remove desktop file but keep metadata
    rm -f "$DESKTOP_FILE"

    run "${COSY_SCRIPT}" desktop list
    assert_success
    assert_output_contains "Status: Missing"
}

# === Desktop Entry Removal Tests ===

@test "desktop rm removes both desktop file and metadata" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" -- bash
    assert_success

    # Verify files exist
    [ -f "$DESKTOP_FILE" ]
    [ -f "$METADATA_FILE" ]

    # Remove desktop entry
    run "${COSY_SCRIPT}" desktop rm "$TEST_CONTAINER"
    assert_success

    # Verify files are gone
    [ ! -f "$DESKTOP_FILE" ]
    [ ! -f "$METADATA_FILE" ]
}

# === Auto-Cleanup Tests ===

@test "cosy rm --home removes desktop entry automatically" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" -- bash
    assert_success

    # Verify desktop entry exists
    [ -f "$DESKTOP_FILE" ]
    [ -f "$METADATA_FILE" ]

    # Remove container with --home
    run "${COSY_SCRIPT}" rm --home "$TEST_CONTAINER"
    assert_success
    assert_output_contains "Removed desktop entry"

    # Verify desktop entry is gone
    [ ! -f "$DESKTOP_FILE" ]
    [ ! -f "$METADATA_FILE" ]
}

@test "cosy rm without --home preserves desktop entry" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" -- bash
    assert_success

    # Remove container without --home
    run "${COSY_SCRIPT}" rm "$TEST_CONTAINER"
    assert_success

    # Desktop entry should still exist
    [ -f "$DESKTOP_FILE" ]
    [ -f "$METADATA_FILE" ]
}

# === Metadata Persistence Tests ===

@test "desktop metadata persists all fields correctly" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --name "GIMP Editor" \
        --icon gimp \
        --comment "Image Editor" \
        --categories "Graphics;RasterGraphics;" \
        --mime-types "image/png;image/jpeg" \
        -- gimp
    assert_success

    # Verify all metadata fields
    grep -q "\"container\": \"$TEST_CONTAINER\"" "$METADATA_FILE"
    grep -q '"command": "gimp"' "$METADATA_FILE"
    grep -q '"name": "GIMP Editor"' "$METADATA_FILE"
    grep -q '"icon": "gimp"' "$METADATA_FILE"
    grep -q '"comment": "Image Editor"' "$METADATA_FILE"
    grep -q '"categories": "Graphics;RasterGraphics;"' "$METADATA_FILE"
    grep -q '"mime_types": "image/png;image/jpeg"' "$METADATA_FILE"

    # Verify timestamps are reasonable (ISO 8601 format)
    local created_at=$(grep '"created_at"' "$METADATA_FILE" | sed 's/.*: "\(.*\)",*/\1/')
    [[ "$created_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

# === Warning Tests ===

@test "desktop create warns but proceeds for non-existent container" {
    check_podman

    # Don't create container
    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" -- bash
    assert_success
    assert_output_contains "Warning"
    assert_output_contains "does not exist"
    assert_output_contains "Desktop entry created"

    # Desktop files should still be created
    [ -f "$DESKTOP_FILE" ]
    [ -f "$METADATA_FILE" ]
}

# === Desktop Database Update Tests ===

@test "desktop install updates database if tool available" {
    check_podman

    run "${COSY_SCRIPT}" desktop install
    assert_success

    if command -v update-desktop-database >/dev/null 2>&1; then
        assert_output_contains "Desktop database updated"
    else
        assert_output_contains "update-desktop-database not found"
    fi
}

# === Special Characters Tests ===

@test "desktop create handles quotes in name" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --name 'Test "App" (v2)' \
        -- bash
    assert_success

    # Verify escaping in desktop file
    grep -q 'Name=Test \\"App\\" (v2)' "$DESKTOP_FILE"

    # Verify escaping in JSON
    grep -q '"name": "Test \\"App\\" (v2)"' "$METADATA_FILE"
}

@test "desktop create handles semicolons in comment" {
    check_podman

    run "${COSY_SCRIPT}" create "$TEST_CONTAINER"
    assert_success

    run "${COSY_SCRIPT}" desktop create "$TEST_CONTAINER" \
        --comment "One;Two;Three" \
        -- bash
    assert_success

    # Verify escaping in desktop file (semicolons should be escaped)
    grep -q 'Comment=One\\;Two\\;Three' "$DESKTOP_FILE"
}
