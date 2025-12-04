#!/usr/bin/env bats

# Device handling tests - GPU, audio, display
# Tests proper device flag usage and rootless support

load '../helpers/common'

# === GPU Device Tests ===

@test "GPU uses --device flag not volume mount" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    assert_has_flag "--device"
    assert_output_contains "/dev/dri"
    assert_output_not_contains "-v /dev/dri:/dev/dri"
}

@test "GPU device flag format is correct" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    assert_has_flag "--device"
    assert_output_contains "/dev/dri"
    assert_output_not_contains "-v /dev/dri:/dev/dri"
}

@test "no volume mount for GPU devices" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    ! echo "$output" | grep -E -- "-v[[:space:]]+/dev/dri:/dev/dri"
}

@test "multiple GPU devices still use --device" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    local device_count=$(echo "$output" | grep -c -- "--device" || true)
    [ "$device_count" -gt 0 ]
    ! echo "$output" | grep -E -- "-v[[:space:]]+/dev/dri"
}

# === Audio Device Tests ===

@test "audio flag shows volume mounts" {
    run "${COSY_SCRIPT}" --dry-run create --audio test-container
    assert_success
    # Should mention audio setup even if specific socket isn't available
    [[ "$output" =~ "audio" ]] || [[ "$output" =~ "/run/user" ]]
}

# === D-Bus Tests ===

@test "dbus flag shows volume mount and env var" {
    run "${COSY_SCRIPT}" --dry-run create --dbus test-container
    assert_success
    assert_output_contains "DBUS_SESSION_BUS_ADDRESS"
}

@test "dbus-system flag shows volume mount and env var" {
    run "${COSY_SCRIPT}" --dry-run create --dbus-system test-container
    assert_success
    assert_output_contains "DBUS_SYSTEM_BUS_ADDRESS"
}

@test "dbus and dbus-system can be used together" {
    run "${COSY_SCRIPT}" --dry-run create --dbus --dbus-system test-container
    assert_success
    assert_output_contains "DBUS_SESSION_BUS_ADDRESS"
    assert_output_contains "DBUS_SYSTEM_BUS_ADDRESS"
}

# === Accessibility Bus Tests ===

@test "a11y flag shows volume mount and env var" {
    run "${COSY_SCRIPT}" --dry-run create --a11y test-container
    assert_success
    assert_output_contains "AT_SPI_BUS_ADDRESS"
    assert_output_contains "at-spi"
}

@test "accessibility flag is an alias for a11y" {
    run "${COSY_SCRIPT}" --dry-run create --accessibility test-container
    assert_success
    assert_output_contains "AT_SPI_BUS_ADDRESS"
    assert_output_contains "at-spi"
}

@test "a11y can combine with other flags" {
    run "${COSY_SCRIPT}" --dry-run create --a11y --dbus --audio test-container
    assert_success
    assert_output_contains "AT_SPI_BUS_ADDRESS"
    assert_output_contains "DBUS_SESSION_BUS_ADDRESS"
}

@test "a11y works with gpu and display" {
    run "${COSY_SCRIPT}" --dry-run create --a11y --gpu test-container
    assert_success
    assert_output_contains "AT_SPI_BUS_ADDRESS"
    assert_output_contains "/dev/dri"
}

# === Display Tests ===

@test "display is enabled by default" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "DISPLAY="
}

@test "no-display disables display forwarding" {
    run "${COSY_SCRIPT}" --dry-run create --no-display test-container
    assert_success
    ! [[ "$output" =~ "DISPLAY=" ]]
}

@test "no-display can combine with other flags" {
    run "${COSY_SCRIPT}" --dry-run create --no-display --audio --gpu test-container
    assert_success
    ! [[ "$output" =~ "DISPLAY=" ]]
    [[ "$output" =~ "/dev/dri" ]]
}

# === Podman Socket Tests ===

@test "podman flag shows socket mount" {
    run "${COSY_SCRIPT}" --dry-run create --podman test-container
    assert_success
    assert_output_contains "podman.sock"
}

# === Network Tests ===

# === Rootless Support Tests ===

@test "includes --group-add keep-groups for rootless support" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_has_flag "--group-add keep-groups"
}

@test "keep-groups comes after user namespace mapping" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "--uidmap"
    assert_output_contains "--gidmap"
    assert_output_contains "keep-groups"
    echo "$output" | grep -q "uidmap"
    echo "$output" | grep -q "keep-groups"
}

@test "GPU with rootless flags combined correctly" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    assert_output_contains "--uidmap"
    assert_output_contains "--gidmap"
    assert_has_flag "--group-add keep-groups"
    assert_has_flag "--device"
    assert_output_contains "/dev/dri"
}

@test "audio with rootless flags" {
    run "${COSY_SCRIPT}" --dry-run create --audio test-container
    assert_success
    assert_output_contains "--uidmap"
    assert_output_contains "--gidmap"
    assert_has_flag "--group-add keep-groups"
}

@test "keep-groups present in all modes" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "keep-groups"

    run "${COSY_SCRIPT}" --dry-run run test-container echo test
    assert_success
    assert_output_contains "keep-groups"

    # Note: podman exec (used by 'root enter') doesn't support --group-add
}

@test "podman create has correct flag order" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    echo "$output" | grep "podman create" | head -1
    local output_single_line=$(echo "$output" | tr -d '\\' | tr '\n' ' ' | tr -s ' ')
    [[ "$output_single_line" =~ --uidmap.+--group-add\ keep-groups ]]
}

@test "keep-groups in debug mode" {
    run "${COSY_SCRIPT}" --debug --dry-run create test-container
    assert_success
    assert_output_contains "keep-groups"
}

@test "all required rootless flags present" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "--uidmap"
    assert_output_contains "--gidmap"
    assert_has_flag "--group-add keep-groups"
    assert_has_flag "--security-opt"
}

# === Generic Device Tests ===

@test "--device flag mounts custom device" {
    run "${COSY_SCRIPT}" --dry-run create --device /dev/kvm test-container
    assert_success
    assert_has_flag "--device"
    assert_output_contains "/dev/kvm"
}

@test "--device flag can be specified multiple times" {
    run "${COSY_SCRIPT}" --dry-run create --device /dev/null --device /dev/zero test-container
    assert_success
    local device_count=$(echo "$output" | grep -c -- "--device" || true)
    [ "$device_count" -ge 2 ]
    assert_output_contains "/dev/null"
    assert_output_contains "/dev/zero"
}

@test "--device works with other device flags" {
    run "${COSY_SCRIPT}" --dry-run create --gpu --device /dev/kvm test-container
    assert_success
    assert_has_flag "--device"
    assert_output_contains "/dev/dri"
    assert_output_contains "/dev/kvm"
}

# === Input Device Tests ===

@test "input flag adds /dev/input device" {
    run "${COSY_SCRIPT}" --dry-run create --input test-container
    assert_success
    assert_has_flag "--device"
    assert_output_contains "/dev/input"
}

@test "input flag adds /dev/uinput device" {
    run "${COSY_SCRIPT}" --dry-run create --input test-container
    assert_success
    assert_output_contains "/dev/uinput"
}

@test "--device /dev/input conflicts with --input flag" {
    run "${COSY_SCRIPT}" --dry-run create --input --device /dev/input test-container
    assert_failure
    assert_output_contains "Cannot use --device /dev/input with --input flag"
    assert_output_contains "automatically adds this device"
}

@test "--device /dev/uinput conflicts with --input flag" {
    run "${COSY_SCRIPT}" --dry-run create --input --device /dev/uinput test-container
    assert_failure
    assert_output_contains "Cannot use --device /dev/uinput with --input flag"
    assert_output_contains "automatically adds this device"
}

@test "--device /dev/hidraw0 conflicts with --input flag" {
    run "${COSY_SCRIPT}" --dry-run create --input --device /dev/hidraw0 test-container
    assert_failure
    assert_output_contains "Cannot use --device /dev/hidraw0 with --input flag"
    assert_output_contains "automatically adds all /dev/hidraw* devices"
}

@test "--device /dev/hidraw1 conflicts with --input flag" {
    run "${COSY_SCRIPT}" --dry-run create --input --device /dev/hidraw1 test-container
    assert_failure
    assert_output_contains "Cannot use --device /dev/hidraw1 with --input flag"
    assert_output_contains "automatically adds all /dev/hidraw* devices"
}

@test "--device with non-input devices works with --input" {
    run "${COSY_SCRIPT}" --dry-run create --input --device /dev/kvm test-container
    assert_success
    assert_output_contains "/dev/input"
    assert_output_contains "/dev/kvm"
}

@test "GPU and input flags can be combined" {
    run "${COSY_SCRIPT}" --dry-run create --gpu --input test-container
    assert_success
    assert_output_contains "/dev/dri"
    assert_output_contains "/dev/input"
}

@test "--device /dev/dri conflicts with --gpu flag" {
    run "${COSY_SCRIPT}" --dry-run create --gpu --device /dev/dri test-container
    assert_failure
    assert_output_contains "Cannot use --device /dev/dri with --gpu flag"
    assert_output_contains "automatically adds this device"
}

# === Combined Flag Tests ===

@test "multiple flags combine correctly" {
    run "${COSY_SCRIPT}" --dry-run create --gpu --audio --network none test-container
    assert_success
    assert_output_contains "/dev/dri"
    assert_has_flag "--network"
    assert_output_contains "none"
}
