#!/usr/bin/env bats

# Audio feature unit tests
# Tests audio device and socket mounting
# Can run in any environment using --dry-run mode

load '../helpers/common'

setup() {
    setup_test_container
}

teardown() {
    cleanup_test_container
}

# === Audio Device Tests ===

@test "audio flag mounts /dev/snd when it exists" {
    # Skip if /dev/snd doesn't exist
    if [ ! -d "/dev/snd" ]; then
        skip "/dev/snd not available on this system"
    fi

    run "${COSY_SCRIPT}" --dry-run create --audio "$TEST_CONTAINER"
    assert_success
    assert_output_contains "--device"
    assert_output_contains "/dev/snd"
}

@test "audio feature stores label" {
    run "${COSY_SCRIPT}" --dry-run create --audio "$TEST_CONTAINER"
    assert_success
    assert_output_contains "cosy.audio=true"
}

@test "audio can be combined with other features" {
    run "${COSY_SCRIPT}" --dry-run create --audio --gpu --dbus "$TEST_CONTAINER"
    assert_success
    assert_output_contains "cosy.audio=true"
}

@test "audio is disabled by default" {
    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    assert_output_not_contains "cosy.audio=true"
}

# === Environment Variable Tests ===

@test "COSY_AUDIO environment variable enables audio" {
    export COSY_AUDIO=true

    run "${COSY_SCRIPT}" --dry-run create "$TEST_CONTAINER"
    assert_success
    assert_output_contains "cosy.audio=true"

    unset COSY_AUDIO
}

@test "audio flag works with COSY_AUDIO=false" {
    export COSY_AUDIO=false

    run "${COSY_SCRIPT}" --dry-run create --audio "$TEST_CONTAINER"
    assert_success
    assert_output_contains "cosy.audio=true"

    unset COSY_AUDIO
}
