# Test Fixtures

This directory contains minimal fixtures required for testing cosy functionality.

## Contents

- `seccomp/` - Seccomp profiles for testing `--seccomp` flag functionality
- `images/` - Container images for testing specific features (e.g., systemd)

## Purpose

These fixtures allow integration tests to verify that:
- Seccomp profiles can be loaded and applied
- Container features work correctly
- Flags are passed correctly to podman
