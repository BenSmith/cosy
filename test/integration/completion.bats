#!/usr/bin/env bats

# Shell completion integration tests
# Tests bash and zsh completion generation

load '../helpers/common'

# === Bash Completion ===

@test "completion bash generates bash completion" {
    run "${COSY_SCRIPT}" completion bash
    assert_success
    assert_output_contains "_cosy()"
    assert_output_contains "complete -F _cosy cosy"
}

# === Zsh Completion ===

@test "completion zsh generates zsh completion" {
    run "${COSY_SCRIPT}" completion zsh
    assert_success
    assert_output_contains "#compdef cosy"
}

# === Completion Validation ===

@test "completion without shell argument shows usage" {
    run "${COSY_SCRIPT}" completion
    assert_failure
    assert_output_contains "Usage:"
}

@test "completion with invalid shell shows error" {
    run "${COSY_SCRIPT}" completion fish
    assert_failure
    assert_output_contains "Unknown shell type"
}

# === Feature Flag Completion ===

@test "bash completion includes --groups flag" {
    run "${COSY_SCRIPT}" completion bash
    assert_success
    assert_output_contains "--groups"
}

@test "zsh completion includes --groups flag" {
    run "${COSY_SCRIPT}" completion zsh
    assert_success
    assert_output_contains "--groups"
}
