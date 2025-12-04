#!/usr/bin/env bats

# Security boundary tests
# Ensures cosy maintains proper security and doesn't use dangerous flags

load '../helpers/common'

# === Privilege Restrictions ===

@test "does NOT use --privileged flag" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    # Should NEVER use --privileged (massive security hole)
    assert_output_not_contains "--privileged"
}

@test "uses minimal capability model" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    # Should drop all capabilities and add back only minimal set
    assert_output_contains "--cap-drop=ALL"
    assert_output_contains "--cap-add"
}

@test "does NOT disable security features with no-new-privileges" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_not_contains "no-new-privileges=false"
}

# === Capability Management ===

@test "base container uses minimal capabilities (5 caps)" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=false test-container
    assert_success

    # Should drop all caps first
    assert_output_contains "--cap-drop=ALL"

    # Should add only base capabilities
    assert_output_contains "--cap-add=CHOWN"
    assert_output_contains "--cap-add=DAC_OVERRIDE"
    assert_output_contains "--cap-add=FOWNER"
    assert_output_contains "--cap-add=SETUID"
    assert_output_contains "--cap-add=SETGID"

    # Should NOT have systemd capabilities
    assert_output_not_contains "--cap-add=FSETID"
    assert_output_not_contains "--cap-add=SYS_CHROOT"
}

@test "systemd container adds systemd capabilities (11 caps total)" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=always test-container
    assert_success

    # Should have base capabilities
    assert_output_contains "--cap-add=CHOWN"
    assert_output_contains "--cap-add=DAC_OVERRIDE"
    assert_output_contains "--cap-add=FOWNER"
    assert_output_contains "--cap-add=SETUID"
    assert_output_contains "--cap-add=SETGID"

    # Should have systemd capabilities
    assert_output_contains "--cap-add=FSETID"
    assert_output_contains "--cap-add=KILL"
    assert_output_contains "--cap-add=NET_BIND_SERVICE"
    assert_output_contains "--cap-add=SETFCAP"
    assert_output_contains "--cap-add=SETPCAP"
    assert_output_contains "--cap-add=SYS_CHROOT"
}

@test "systemd does NOT require CAP_SYS_ADMIN" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=always test-container
    assert_success

    # Should NOT have SYS_ADMIN (most dangerous capability)
    assert_output_not_contains "--cap-add=SYS_ADMIN"
    assert_output_not_contains "cap-add SYS_ADMIN"
}

@test "custom network adds network capabilities" {
    run "${COSY_SCRIPT}" --dry-run create --network mynet test-container
    assert_success

    # Should have network administration capabilities
    assert_output_contains "--cap-add=NET_ADMIN"
    assert_output_contains "--cap-add=NET_RAW"
}

@test "user --cap-add overrides automatic capabilities" {
    run "${COSY_SCRIPT}" --dry-run create --cap-add SYS_ADMIN test-container
    assert_success

    # User specified caps, so automatic caps should be disabled
    assert_output_not_contains "--cap-drop=ALL"

    # But user's cap should be present
    assert_output_contains "--cap-add"
    assert_output_contains "SYS_ADMIN"
}

@test "user --cap-drop overrides automatic capabilities" {
    run "${COSY_SCRIPT}" --dry-run create --cap-drop NET_RAW test-container
    assert_success

    # User specified caps, so automatic caps should be disabled
    assert_output_not_contains "--cap-drop=ALL"

    # But user's cap-drop should be present
    assert_output_contains "--cap-drop"
    assert_output_contains "NET_RAW"
}

@test "GUI features do NOT require additional capabilities" {
    run "${COSY_SCRIPT}" --dry-run create --systemd=false --audio --gpu --dbus test-container
    assert_success

    # Audio, GPU, D-Bus should work with just base capabilities
    # Should only have the 5 base capabilities
    assert_output_contains "--cap-add=CHOWN"
    assert_output_contains "--cap-add=DAC_OVERRIDE"
    assert_output_contains "--cap-add=FOWNER"
    assert_output_contains "--cap-add=SETUID"
    assert_output_contains "--cap-add=SETGID"

    # Should NOT have added extra capabilities
    assert_output_not_contains "--cap-add=SYS_ADMIN"
    assert_output_not_contains "--cap-add=NET_ADMIN"
}

# === Security Options ===

@test "--tmpfs flag adds tmpfs mount" {
    run "${COSY_SCRIPT}" --dry-run create --tmpfs /var/tmp test-container
    assert_success
    assert_output_contains "--tmpfs"
    assert_output_contains "/var/tmp"
}

@test "--tmpfs flag can be specified multiple times" {
    run "${COSY_SCRIPT}" --dry-run create --tmpfs /var/tmp --tmpfs /app/data test-container
    assert_success
    assert_output_contains "--tmpfs"
    assert_output_contains "/var/tmp"
    assert_output_contains "/app/data"
}

@test "XDG_RUNTIME_DIR tmpfs created by default" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "--tmpfs"
    # Should contain /run/user/$UID with mode 0700
    [[ "$output" =~ "--tmpfs" ]] && [[ "$output" =~ "/run/user/".*":mode=0700" ]]
}

@test "--cap-drop flag drops a feature" {
    run "${COSY_SCRIPT}" --dry-run create --cap-drop NET_RAW test-container
    assert_success
    assert_output_contains "--cap-drop"
    assert_output_contains "NET_RAW"
}

@test "--cap-drop flag can be specified multiple times" {
    run "${COSY_SCRIPT}" --dry-run create --cap-drop NET_RAW --cap-drop SYS_ADMIN test-container
    assert_success
    assert_output_contains "--cap-drop"
    assert_output_contains "NET_RAW"
    assert_output_contains "SYS_ADMIN"
}

@test "--cap-add flag adds a feature" {
    run "${COSY_SCRIPT}" --dry-run create --cap-add NET_RAW test-container
    assert_success
    assert_output_contains "--cap-add"
    assert_output_contains "NET_RAW"
}

@test "--cap-add flag can be specified multiple times" {
    run "${COSY_SCRIPT}" --dry-run create --cap-add NET_RAW --cap-add SYS_ADMIN test-container
    assert_success
    assert_output_contains "--cap-add"
    assert_output_contains "NET_RAW"
    assert_output_contains "SYS_ADMIN"
}

@test "cap-add and cap-drop work together" {
    run "${COSY_SCRIPT}" --dry-run create --cap-add NET_RAW --cap-drop SYS_ADMIN test-container
    assert_success
    assert_output_contains "--cap-add"
    assert_output_contains "--cap-drop"
    assert_output_contains "NET_RAW"
    assert_output_contains "SYS_ADMIN"
}

# === Namespace Isolation ===

@test "does NOT share host PID namespace" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_not_contains "--pid"
    assert_output_not_contains "pid=host"
}

@test "does NOT disable user namespace" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "--uidmap"
    assert_output_contains "--gidmap"
    assert_output_not_contains "--userns=host"
    assert_output_not_contains "userns=host"
}

@test "uses correct user namespace mode" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "--uidmap"
    assert_output_contains "--gidmap"
    assert_output_not_contains "--userns=container"
    assert_output_not_contains "--userns=private"
}

@test "does NOT share host IPC namespace unnecessarily" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_not_contains "--ipc"
    assert_output_not_contains "ipc=host"
}

# === Security Label Handling ===

@test "default mode: home directory has NO labels" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    # Find home directory mount line
    local home_mount=$(echo "$output" | grep -E "\.local/share/cosy.*:/home/")
    # Should NOT have :Z or :z suffix when disabled
    ! echo "$home_mount" | grep -E ":/home/[^\"]*:[Zz]"
}

@test "default mode: display mounts have NO labels" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    # X11 mounts should never have labels (can't relabel system directories)
    ! echo "$output" | grep -E "X11.*,z"
    ! echo "$output" | grep -E "Xauthority.*,z"
}

@test "default mode: uses label=disable" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "--security-opt label=disable"
}

@test "--security-opt passthrough works" {
    run "${COSY_SCRIPT}" --dry-run create --security-opt label=type:spc_t test-container
    assert_success
    assert_output_contains "--security-opt label=type:spc_t"
}

@test "--security-opt can be specified multiple times" {
    run "${COSY_SCRIPT}" --dry-run create --security-opt label=type:spc_t --security-opt seccomp=unconfined test-container
    assert_success
    assert_output_contains "--security-opt label=type:spc_t"
    assert_output_contains "--security-opt seccomp=unconfined"
}

# === User Execution Separation ===

@test "bootstrap script runs as root" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    echo "$output" | grep "podman exec" | grep -q "root"
}

@test "user commands run as user not root" {
    run "${COSY_SCRIPT}" --dry-run run test-container echo test
    assert_success
    assert_has_flag "--user"
    local user_spec=$(echo "$output" | grep "podman exec" | grep -oE "user [0-9]+:[0-9]+")
    ! echo "$user_spec" | grep -q "0:0"
}

# === Host Exposure Prevention ===

@test "does NOT mount entire /dev directory" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    assert_output_not_contains "-v /dev:/dev"
    assert_has_flag "--device"
}

@test "does NOT expose host /proc" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_not_contains "-v /proc:/proc"
}

@test "does NOT expose host /sys" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_not_contains "-v /sys:/sys"
}

# === Container Lifecycle ===

@test "container command is sleep infinity" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    # Container should run sleep infinity to stay alive
    assert_output_contains "sleep infinity"
}
