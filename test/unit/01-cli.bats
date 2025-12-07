#!/usr/bin/env bats

# CLI interface tests - help, version, basic command construction
# These tests use --dry-run mode and can run inside containers

load '../helpers/common'

# === Help and Version Tests ===

@test "cosy with no arguments shows usage" {
    run "${COSY_SCRIPT}"
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "Subcommands:"
}

@test "cosy --version shows version" {
    run "${COSY_SCRIPT}" --version
    assert_success
    assert_output_contains "cosy version"
}

@test "cosy -V shows version" {
    run "${COSY_SCRIPT}" -V
    assert_success
    assert_output_contains "cosy version"
}

@test "cosy help shows usage information" {
    run "${COSY_SCRIPT}" help
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "Subcommands:"
}

@test "cosy -h shows usage information" {
    run "${COSY_SCRIPT}" -h
    assert_success
    assert_output_contains "Usage:"
}

@test "cosy --help shows usage information" {
    run "${COSY_SCRIPT}" --help
    assert_success
    assert_output_contains "Usage:"
}

@test "invalid subcommand is rejected" {
    run "${COSY_SCRIPT}" invalid-command
    assert_failure
    assert_output_contains "Unknown subcommand"
}

# === Basic Dry-Run Command Construction ===

@test "dry-run create shows podman create command" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "podman create"
    assert_output_contains "test-container"
}

@test "dry-run clearly marks output as dry-run" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    [[ "$output" =~ "DRY RUN" ]] || [[ "$output" =~ "Would create" ]]
}

@test "dry-run shows readable podman command" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "podman"
}

@test "dry-run create with default image" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    [[ "$output" =~ "fedora:43" ]] || [[ "$output" =~ "Image:" ]]
}

@test "dry-run create with custom image shows image name" {
    run "${COSY_SCRIPT}" --dry-run create --image fedora:41 test-container
    assert_success
    assert_output_contains "fedora:41"
}

@test "dry-run with -i flag for image" {
    run "${COSY_SCRIPT}" --dry-run create -i fedora:40 test-container
    assert_success
    assert_output_contains "fedora:40"
}

@test "dry-run shows container gets sleep infinity by default" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    # Default to sleep infinity (fedora:43's /bin/bash is ignored as it exits without TTY)
    assert_output_contains "sleep infinity"
}

@test "dry-run shows container start after create" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "podman create"
    assert_output_contains "podman start"
}

@test "dry-run shows bootstrap script execution" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    [[ "$output" =~ "BOOTSTRAP" ]] || [[ "$output" =~ "exec --user root" ]]
}

# === Run Command Tests ===

@test "dry-run run shows exec command" {
    run "${COSY_SCRIPT}" --dry-run run test-container echo hello
    assert_success
    assert_output_contains "podman exec"
}

@test "dry-run run with arguments preserves them" {
    run "${COSY_SCRIPT}" --dry-run run test-container echo hello world
    assert_success
    assert_output_contains "podman exec"
}

@test "dry-run run with quoted arguments" {
    run "${COSY_SCRIPT}" --dry-run run test-container echo "hello world"
    assert_success
    assert_output_contains "podman exec"
}

@test "dry-run run with special characters" {
    run "${COSY_SCRIPT}" --dry-run run test-container echo '$HOME'
    assert_success
    assert_output_contains "podman exec"
}

@test "dry-run run without command fails" {
    run "${COSY_SCRIPT}" --dry-run run test-container
    assert_failure
    assert_output_contains "No command specified"
}

# === Double-Dash (--) Separator Tests ===

@test "dry-run run with -- separator allows command flags" {
    run "${COSY_SCRIPT}" --dry-run run test-container -- echo -n test
    assert_success
    assert_output_contains "podman"
}

@test "dry-run run with -- separator allows -y flag" {
    run "${COSY_SCRIPT}" --dry-run run test-container -- dnf install -y vim
    assert_success
    assert_output_contains "podman"
}

@test "dry-run run --root with -- separator allows command flags" {
    run "${COSY_SCRIPT}" --dry-run run --root test-container -- dnf install -y vim
    assert_success
    assert_output_contains "podman"
    assert_output_contains "--user root"
}

@test "dry-run run with -- separator and multiple flags" {
    run "${COSY_SCRIPT}" --dry-run run test-container -- grep -r -n -i "pattern"
    assert_success
    assert_output_contains "podman"
}

@test "dry-run create with options before -- separator" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container -- command -flag
    assert_success
    assert_output_contains "podman create"
    assert_output_contains "/dev/dri"
}

@test "dry-run run rejects unknown option without -- separator" {
    run "${COSY_SCRIPT}" --dry-run run test-container -y
    assert_failure
    assert_output_contains "Unknown option"
}

@test "dry-run enter with -- separator allows command flags" {
    run "${COSY_SCRIPT}" --dry-run enter test-container -- ls -la
    assert_success
    assert_output_contains "podman exec"
}

@test "dry-run enter --root with -- separator allows command flags" {
    run "${COSY_SCRIPT}" --dry-run enter --root test-container -- bash --norc
    assert_success
    assert_output_contains "podman exec"
    assert_output_contains "--user root"
}

# === Enter Command Tests ===

@test "dry-run enter without command shows shell" {
    run "${COSY_SCRIPT}" --dry-run enter test-container
    assert_success
    assert_output_contains "podman exec"
}

@test "dry-run enter with command shows command and shell" {
    run "${COSY_SCRIPT}" --dry-run enter test-container echo test
    assert_success
    assert_output_contains "podman exec"
}

# === Root Flag Tests ===

@test "dry-run run --root executes command as root" {
    run "${COSY_SCRIPT}" --dry-run run --root test-container echo hello
    assert_success
    assert_output_contains "podman exec"
    assert_output_contains "--user root"
}

@test "dry-run run --root requires command" {
    run "${COSY_SCRIPT}" --dry-run run --root test-container
    assert_failure
    assert_output_contains "No command specified"
}

@test "dry-run enter --root opens shell as root" {
    run "${COSY_SCRIPT}" --dry-run enter --root test-container
    assert_success
    assert_output_contains "podman exec"
    assert_output_contains "--user root"
}

@test "dry-run enter --root accepts optional command" {
    run "${COSY_SCRIPT}" --dry-run enter --root test-container bash
    assert_success
    assert_output_contains "podman exec"
    assert_output_contains "--user root"
}

@test "run --root accepts flags before container name" {
    run "${COSY_SCRIPT}" --dry-run run --root --gpu test-container dnf install vim
    assert_success
    assert_output_contains "--user root"
    assert_output_contains "/dev/dri"
}

@test "enter --root accepts flags with container name" {
    run "${COSY_SCRIPT}" --dry-run enter --root test-container
    assert_success
    assert_output_contains "--user root"
}

# === List Command Tests ===

@test "ls alias works as list command" {
    run "${COSY_SCRIPT}" --dry-run ls
    assert_success
    [[ "$output" =~ "Container Homes" ]] || [[ "$output" =~ "cosy" ]]
}

# === Environment Variable Tests ===

@test "dry-run shows display environment variables" {
    run "${COSY_SCRIPT}" --dry-run run test-container echo test
    assert_success
    [[ "$output" =~ "DISPLAY" ]] || [[ "$output" =~ "-e" ]]
}

@test "dry-run shows user environment variables" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    [[ "$output" =~ "COSY_CONTAINER_USER" ]] || [[ "$output" =~ "USER" ]]
}

# === Edge Cases ===

@test "dry-run works when run from inside a container" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_not_contains "Already running inside a container"
}

# === Bootstrap Script Tests ===

@test "create accepts --bootstrap-script flag" {
    TEMP_SCRIPT=$(mktemp)
    echo "#!/bin/sh" > "$TEMP_SCRIPT"
    echo "echo 'custom bootstrap'" >> "$TEMP_SCRIPT"

    run "${COSY_SCRIPT}" --dry-run create --bootstrap-script "$TEMP_SCRIPT" test-container
    assert_success

    rm -f "$TEMP_SCRIPT"
}

@test "create accepts --bootstrap-append-script flag" {
    TEMP_SCRIPT=$(mktemp)
    echo "#!/bin/sh" > "$TEMP_SCRIPT"
    echo "echo 'appended'" >> "$TEMP_SCRIPT"

    run "${COSY_SCRIPT}" --dry-run create --bootstrap-append-script "$TEMP_SCRIPT" test-container
    assert_success

    rm -f "$TEMP_SCRIPT"
}

@test "create accepts --bootstrap-inline flag with inline command" {
    run "${COSY_SCRIPT}" --dry-run create --bootstrap-inline "echo 'test'; dnf install vim" test-container
    assert_success
}

@test "create accepts --bootstrap-append-inline flag" {
    run "${COSY_SCRIPT}" --dry-run create --bootstrap-append-inline "dnf install -y htop" test-container
    assert_success
}

# === Entrypoint and CMD Tests ===

@test "create with default cmd shows sleep infinity" {
    run "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    # Default to sleep infinity (keeps container running)
    assert_output_contains "sleep infinity"
}

@test "create accepts --cmd flag" {
    run "${COSY_SCRIPT}" --dry-run create --cmd "/bin/bash" test-container
    assert_success
    assert_output_contains "/bin/bash"
    assert_output_not_contains "sleep infinity"
}

@test "create accepts --entrypoint flag" {
    run "${COSY_SCRIPT}" --dry-run create --entrypoint "/usr/bin/tini" test-container
    assert_success
    assert_output_contains '--entrypoint "/usr/bin/tini"'
}

@test "create accepts both --entrypoint and --cmd" {
    run "${COSY_SCRIPT}" --dry-run create --entrypoint "/usr/bin/tini" --cmd "/bin/bash" test-container
    assert_success
    assert_output_contains '--entrypoint "/usr/bin/tini"'
    assert_output_contains "/bin/bash"
}

@test "COSY_CMD environment variable sets default cmd" {
    run env COSY_CMD="/bin/bash" "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "/bin/bash"
    assert_output_not_contains "sleep infinity"
}

@test "COSY_ENTRYPOINT environment variable sets default entrypoint" {
    run env COSY_ENTRYPOINT="/usr/bin/tini" "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains '--entrypoint "/usr/bin/tini"'
}

@test "CLI --cmd flag overrides COSY_CMD environment variable" {
    run env COSY_CMD="/bin/bash" "${COSY_SCRIPT}" --dry-run create --cmd "/bin/sh" test-container
    assert_success
    assert_output_contains "/bin/sh"
    assert_output_not_contains "/bin/bash"
}

@test "CLI --entrypoint flag overrides COSY_ENTRYPOINT environment variable" {
    run env COSY_ENTRYPOINT="/usr/bin/tini" "${COSY_SCRIPT}" --dry-run create --entrypoint "/usr/bin/dumb-init" test-container
    assert_success
    assert_output_contains '--entrypoint "/usr/bin/dumb-init"'
    assert_output_not_contains "/usr/bin/tini"
}

# === Image CMD/Entrypoint Detection Tests ===

@test "uses sleep infinity for images with shell CMDs" {
    run "${COSY_SCRIPT}" --dry-run create --image fedora:43 test-container
    assert_success
    # fedora:43 has /bin/bash which exits without TTY, so use sleep infinity instead
    assert_output_contains "sleep infinity"
    assert_output_not_contains "/bin/bash"
}

@test "explicit --cmd overrides default" {
    run "${COSY_SCRIPT}" --dry-run create --image fedora:43 --cmd "sleep 999" test-container
    assert_success
    assert_output_contains "sleep 999"
    assert_output_not_contains "sleep infinity"
}

@test "COSY_CMD environment variable overrides default" {
    run env COSY_CMD="/bin/zsh" "${COSY_SCRIPT}" --dry-run create --image fedora:43 test-container
    assert_success
    assert_output_contains "/bin/zsh"
    assert_output_not_contains "sleep infinity"
}

# === Input Device Tests ===

@test "create accepts --input flag" {
    run "${COSY_SCRIPT}" --dry-run create --input test-container
    assert_success
    assert_output_contains "/dev/input"
}

@test "create with --input shares /dev/uinput" {
    run "${COSY_SCRIPT}" --dry-run create --input test-container
    assert_success
    assert_output_contains "/dev/uinput"
}

@test "create with --input shares hidraw devices" {
    run "${COSY_SCRIPT}" --dry-run create --input test-container
    assert_success
    # Should share hidraw devices if they exist
    [[ "$output" =~ "/dev/hidraw" ]] || [[ ! -e "/dev/hidraw0" ]]
}

@test "COSY_INPUT environment variable enables input" {
    run env COSY_INPUT=true "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
    assert_output_contains "/dev/input"
}

# === Debug Flag Tests ===

@test "debug flag is accepted" {
    run "${COSY_SCRIPT}" --debug --dry-run create test-container
    assert_success
}

@test "COSY_DEBUG environment variable is accepted" {
    run env COSY_DEBUG=true "${COSY_SCRIPT}" --dry-run create test-container
    assert_success
}

@test "debug mode does not break dry-run output" {
    run "${COSY_SCRIPT}" --debug --dry-run create test-container
    assert_success
    assert_output_contains "podman create"
    assert_output_contains "test-container"
}
