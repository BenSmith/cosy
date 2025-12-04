#!/usr/bin/env bats

# Systemd integration tests
# Tests systemd functionality with real containers

load '../helpers/common'

SYSTEMD_IMAGE="localhost/fedora-systemd-test:43"
CONTAINERFILE="${BATS_TEST_DIRNAME}/../fixtures/images/fedora-systemd.containerfile"

# Build systemd image once for all tests
setup_file() {
    # Build image if it doesn't exist
    if ! podman image exists "$SYSTEMD_IMAGE"; then
        podman build -t "$SYSTEMD_IMAGE" -f "$CONTAINERFILE" "${BATS_TEST_DIRNAME}/../fixtures/images/"
    fi
}

# Clean up image after all tests
teardown_file() {
    podman rmi -f "$SYSTEMD_IMAGE" 2>/dev/null || true
}

# === Inspect Command Tests ===

@test "inspect shows systemd mode true" {
    local test_container="test-systemd-true-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --systemd=true "$test_container"

    run "${COSY_SCRIPT}" inspect "$test_container"
    assert_success
    assert_output_contains "Systemd: true"

    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "inspect shows systemd mode false" {
    local test_container="test-systemd-false-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --systemd=false "$test_container"

    run "${COSY_SCRIPT}" inspect "$test_container"
    assert_success
    assert_output_contains "Systemd: false"

    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "inspect shows systemd mode always" {
    local test_container="test-systemd-always-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --systemd=always "$test_container"

    run "${COSY_SCRIPT}" inspect "$test_container"
    assert_success
    assert_output_contains "Systemd: always"

    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "inspect CLI format omits --systemd for default values" {
    local test_container="test-systemd-cli-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --systemd=true "$test_container"

    run "${COSY_SCRIPT}" inspect --format=cli "$test_container"
    assert_success
    # --systemd is omitted when it's true (the default)
    assert_output_not_contains "--systemd"

    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "inspect CLI format includes --systemd for non-default values" {
    local test_container="test-systemd-cli-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --systemd=false "$test_container"

    run "${COSY_SCRIPT}" inspect --format=cli "$test_container"
    assert_success
    assert_output_contains "--systemd false"

    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "inspect CLI format includes --systemd=always" {
    local test_container="test-systemd-always-cli-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --systemd=always "$test_container"

    run "${COSY_SCRIPT}" inspect --format=cli "$test_container"
    assert_success
    assert_output_contains "--systemd always"

    "${COSY_SCRIPT}" rm --home "$test_container"
}

# === Functional Systemd Tests ===

@test "systemd runs as PID 1 in container" {
    local test_container="test-systemd-pid1-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --image "$SYSTEMD_IMAGE" --systemd=always "$test_container"

    # Wait for systemd to fully start
    sleep 2

    # Check that PID 1 is systemd (or init which links to systemd)
    run timeout 5 podman exec "$test_container" sh -c 'readlink /proc/1/exe || ls -l /proc/1/exe'
    assert_success
    assert_output_contains "systemd"

    "${COSY_SCRIPT}" stop "$test_container"
    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "systemctl commands work inside systemd container" {
    local test_container="test-systemd-ctl-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --image "$SYSTEMD_IMAGE" --systemd=always "$test_container"

    # Wait for systemd to fully start
    sleep 2

    # Test systemctl status
    run timeout 5 podman exec "$test_container" systemctl status
    assert_success

    # Test systemctl list-units
    run timeout 5 podman exec "$test_container" systemctl list-units --type=service
    assert_success

    "${COSY_SCRIPT}" stop "$test_container"
    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "can enable and manage services in systemd container" {
    local test_container="test-systemd-service-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --image "$SYSTEMD_IMAGE" --systemd=always "$test_container"

    # Wait for systemd to fully start
    sleep 2

    # Create a simple test service
    run timeout 10 podman exec "$test_container" bash -c 'cat > /etc/systemd/system/test.service <<EOF
[Unit]
Description=Test Service

[Service]
Type=oneshot
ExecStart=/bin/true

[Install]
WantedBy=multi-user.target
EOF'
    assert_success

    # Enable the service
    run timeout 5 podman exec "$test_container" systemctl enable test.service
    assert_success

    # Check if service is enabled
    run timeout 5 podman exec "$test_container" systemctl is-enabled test.service
    assert_success
    assert_output_contains "enabled"

    "${COSY_SCRIPT}" stop "$test_container"
    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "systemd tmpfs mounts are present" {
    local test_container="test-systemd-tmpfs-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --image "$SYSTEMD_IMAGE" --systemd=always "$test_container"

    # Wait for systemd to fully start
    sleep 2

    # Check for systemd-managed tmpfs mounts
    run timeout 5 podman exec "$test_container" mount
    assert_success
    assert_output_contains "tmpfs on /run"
    assert_output_contains "tmpfs on /tmp"

    "${COSY_SCRIPT}" stop "$test_container"
    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "can recreate systemd containers" {
    local test_container="test-systemd-recreate-${BATS_TEST_NUMBER}-$$"

    # Create with systemd
    "${COSY_SCRIPT}" create --image "$SYSTEMD_IMAGE" --systemd=always "$test_container"

    # Stop it first
    "${COSY_SCRIPT}" stop "$test_container"

    # Recreate with audio added (recreate requires stopped container)
    run "${COSY_SCRIPT}" recreate --audio --systemd=always --yes "$test_container"
    assert_success

    # Verify audio was added
    run "${COSY_SCRIPT}" inspect "$test_container"
    assert_success
    assert_output_contains "Audio: enabled"

    "${COSY_SCRIPT}" rm --home "$test_container"
}

@test "systemd container starts and stops cleanly" {
    local test_container="test-systemd-lifecycle-${BATS_TEST_NUMBER}-$$"
    "${COSY_SCRIPT}" create --image "$SYSTEMD_IMAGE" --systemd=always "$test_container"

    # Wait for systemd to fully start
    sleep 2

    # Verify container is running
    run podman ps --filter "name=$test_container" --format "{{.Status}}"
    assert_success
    assert_output_contains "Up"

    # Stop the container
    run "${COSY_SCRIPT}" stop "$test_container"
    assert_success

    # Verify it stopped
    run podman ps -a --filter "name=$test_container" --format "{{.Status}}"
    assert_success
    assert_output_contains "Exited"

    "${COSY_SCRIPT}" rm --home "$test_container"
}
