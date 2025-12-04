# Cosy Test Suite

Comprehensive test suite for cosy, organized by execution context and domain.

## Test Organization

```
test/
├── unit/                          # Fast tests, no podman needed, can run in containers
│   ├── 01-cli.bats                # CLI interface (help, version, commands)
│   ├── 02-validation.bats         # Input validation (names, flags, conflicts)
│   ├── 03-devices.bats            # Device handling (GPU, audio, display)
│   ├── 04-network.bats            # Network configuration
│   ├── 05-security.bats           # Security boundaries
│   ├── 07-network-subcommand.bats # Network subcommand
│   ├── 08-systemd.bats            # Systemd support
│   ├── 09-display-detection.bats  # Display auto-detection
│   └── 11-desktop.bats            # Desktop subcommand
├── integration/                   # Requires podman, must run on host
│   ├── bootstrap.bats             # Bootstrap, hostname, custom prompts
│   ├── clone.bats                 # Clone command
│   ├── command-history-log.bats   # Command history logging
│   ├── completion.bats            # Shell completion
│   ├── debug.bats                 # Debug mode
│   ├── desktop.bats               # Desktop integration
│   ├── inspect.bats               # Inspect command
│   ├── lifecycle.bats             # Container create/list/remove
│   ├── network.bats               # Network operations
│   ├── recreate.bats              # Recreate command
│   ├── seccomp.bats               # Seccomp profiles
│   ├── seccomp-syscall.bats       # Seccomp syscall blocking
│   └── systemd.bats               # Systemd functionality
└── helpers/
    └── common.bash                # Shared test utilities
```

## Running Tests

### Quick Start

```bash
# All tests
bats test/

# Unit tests only (fast, works in containers)
bats test/unit/

# Integration tests only (requires podman on host)
bats test/integration/

# Integration tests in parallel (faster, uses N concurrent jobs)
bats -j 4 test/integration/

# Specific test file
bats test/unit/03-devices.bats

# Specific test by name
bats test/ -f "GPU uses --device"
```

### Using Just (if available)

```bash
just bats                   # All tests (unit + integration)
just bats-unit              # Unit tests only
just bats-integration       # Integration tests only
just bats-file FILE         # Run specific test file
just seccomp-tests          # Fast seccomp JSON validation
just seccomp-tests-all      # All seccomp tests
just clean-tests            # Clean up test artifacts
just test-verbose           # Verbose test output
just watch                  # Watch mode (requires entr)
```

## Test Categories

### Unit Tests

**Can run:** Inside containers, no podman needed
**Speed:** Fast (~1-2 seconds)

Unit test files are numbered for logical organization. Gaps in numbering (06, 10) allow for future test organization without renaming existing files.

#### 01-cli.bats
- Help and version flags
- Basic command construction
- Run, enter commands
- --root flag with run and enter
- Double-dash (--) separator for command flags
- List command (ls alias)
- Environment variables
- Bootstrap script flags
- Entrypoint and CMD configuration
- Image CMD/Entrypoint detection
- Input device flags
- Debug flag

#### 02-validation.bats
- Container name validation
- Flag conflict detection
- Volume mount specifications

#### 03-devices.bats
- GPU device handling (--device vs -v)
- Audio device configuration
- Display forwarding (default enabled, --no-display)
- Podman socket mounting
- Rootless support (--group-add keep-groups)
- Flag ordering and combinations
- Input device handling

#### 04-network.bats
- Network isolation (--network none)
- Host networking (--network host)
- Default network mode
- Proper flag usage (--network not --net)

#### 05-security.bats
- No privileged containers
- No unnecessary capabilities
- Namespace isolation (PID, IPC, user)
- User execution separation
- Host exposure prevention
- Security option verification
- Capability add/drop validation
- Seccomp profile support

#### 07-network-subcommand.bats
- Network subcommand help and validation
- Inspect, stats, connections commands
- Traffic control (throttle, delay, loss)
- Network disconnect/reconnect
- Capture and watch commands
- Flag and argument validation

#### 08-systemd.bats
- --systemd flag support
- Systemd mode values (true, false, always)
- Environment variable configuration
- Protected tmpfs path validation

#### 09-display-detection.bats
- X11 and Wayland detection logic
- Display environment variable handling
- Socket and runtime directory detection
- Display forwarding configuration

#### 11-desktop.bats
- Desktop subcommand help
- Create, list, remove actions
- Desktop entry validation
- Name, icon, MIME type flags
- Argument parsing

### Integration Tests

**Can run:** Host only (not in containers)
**Speed:** Slower (~10-30 seconds)
**Parallel:** Can run concurrently with `bats -j N` for faster execution

#### bootstrap.bats
- Bootstrap script execution
- Hostname configuration
- Custom shell prompts
- Environment variable setup
- Bootstrap customization options

#### clone.bats
- Container cloning with new name
- Home directory copying
- Writable layer transfer
- Feature modification during clone
- Diff preview (--show-diff)
- Confirmation prompts (--yes)

#### command-history-log.bats
- COSY_COMMAND_HISTORY feature
- JSON logging format
- Command tracking and metadata
- Log file management
- Argument preservation

#### completion.bats
- Bash completion generation
- Zsh completion generation
- Completion validation

#### debug.bats
- --debug flag functionality
- Command output visibility
- stderr handling
- Debug mode with different subcommands

#### desktop.bats
- Desktop file creation and removal
- Application launcher integration
- MIME type associations
- Icon and name configuration
- Desktop database updates
- Integration with container homes

#### inspect.bats
- Container feature inspection
- Multiple output formats (human, cli, raw)
- Feature tracking and display
- Image information
- Configuration summary

#### lifecycle.bats
- Real container creation
- Container validation
- Multiple flag combinations
- List command with actual containers
- Remove operations (with/without home)
- Multi-container removal
- --root flag with run and enter commands
- Dry-run verification
- Container status tracking

#### network.bats
- Real network operations
- Connection monitoring
- Traffic shaping (throttle, delay, loss)
- Network disconnect/reconnect
- Packet capture
- Statistics and inspection
- Persistent network settings

#### recreate.bats
- Container recreation in place
- Feature updates while preserving data
- Installed package preservation
- Diff preview (--show-diff)
- Confirmation prompts (--yes)
- Base image changes

#### seccomp.bats
- Seccomp profile validation
- Profile JSON format
- Integration with container creation
- Default and custom profiles
- Profile path handling

#### seccomp-syscall.bats
- Actual syscall blocking verification
- Container-based syscall testing
- Profile effectiveness validation
- Syscall behavior enforcement

#### systemd.bats
- Systemd container support
- Init process configuration
- Service management
- Systemd integration with cosy features

## Key Features Tested

### Critical Bug Prevention

The test suite prevents these critical bugs through specific assertions:

1. **Device Handling** - Ensures GPU uses `--device` not `-v` volume mounts
2. **Rootless Support** - Verifies `--group-add keep-groups` is present
3. **Security Boundaries** - Prevents `--privileged`, namespace leakage, host exposure

### Test Approach

**Unit Tests:** Use `--dry-run` mode to:
- Test command construction without side effects
- Verify flag combinations and validation
- Run inside containers (for CI/CD)
- Execute quickly for rapid feedback

**Integration Tests:** Use real podman to:
- Verify actual container operations
- Test .cosy-features file tracking (in lifecycle, inspect, recreate, clone tests)
- Validate end-to-end workflows
- Ensure podman integration works
- Test bootstrap execution and customization
- Verify desktop integration
- Test network operations and traffic control
- Validate seccomp profile enforcement
- Test systemd integration

## Shared Helpers

Located in `test/helpers/common.bash`:

```bash
assert_failure()                    # Assert command failed
assert_has_flag(flag)               # Assert flag present in output
assert_no_flag(flag)                # Assert flag NOT in output
assert_output_contains(pattern)     # Assert output contains pattern
assert_output_not_contains(pattern) # Assert output does NOT contain pattern
assert_success()                    # Assert command succeeded
cleanup_test_container()            # Clean up after tests
setup_test_container()              # Initialize test environment
```

## Writing New Tests

### Where to Add Tests

- **Unit tests** - For command construction, validation, flag verification
- **Integration tests** - For actual container operations, file creation

### Test Template

```bash
#!/usr/bin/env bats

# Description of test file purpose

load '../helpers/common'

# For integration tests only:
setup() {
    setup_test_container
}

teardown() {
    cleanup_test_container
}

@test "descriptive test name" {
    run "${COSY_SCRIPT}" --dry-run create --gpu test-container
    assert_success
    assert_has_flag "--device"
    assert_no_flag "--privileged"
}
```

### Best Practices

1. **Use descriptive names** - Test names should explain what's being verified
2. **Test positives and negatives** - Assert what SHOULD and SHOULD NOT be present
3. **Use helpers** - Leverage common.bash functions for consistency
4. **Keep tests focused** - One concept per test
5. **Clean up** - Use teardown to remove test containers

## Requirements

- **Bats** - Bash Automated Testing System
- **Podman** - For integration tests only
- **Bash** - Shell environment
- **Standard utilities** - grep, etc.

### Installation

```bash
sudo dnf install bats
```

## Running in Different Environments

### On Host
```bash
# Run all tests
bats test/
```

### Inside Container
```bash
# Run unit tests only (integration tests will fail)
bats test/unit/
```

### CI/CD Pipeline
```bash
# Fast unit tests for quick feedback
bats test/unit/

# Full test suite (requires podman)
bats test/
```

## Test Structure Benefits

1. **Clear separation** - Unit vs integration is obvious from directory
2. **Fast feedback** - Can run unit tests quickly without podman
3. **Domain organization** - Related tests grouped together by domain
4. **Numbered order** - Unit tests have logical progression with room for growth
5. **Comprehensive coverage** - 9 unit test files, 13 integration test files
6. **Shared helpers** - Reduce duplication, improve consistency
7. **Scalable** - Easy to add new domain-specific test files

## Debugging Failed Tests

### Run specific test
```bash
bats test/unit/03-devices.bats -f "GPU"
```

### See actual command output
```bash
./cosy --dry-run create --gpu test-container
```

### Check patterns
```bash
./cosy --dry-run create --gpu test | grep -E "(--device|keep-groups)"
```

### Enable verbose output
```bash
bats --verbose-run test/unit/03-devices.bats
```

## Test Coverage Summary

| Category | Speed | Podman Required | Can Run in Container* |
|----------|-------|-----------------|-----------------------|
| Unit Tests | Fast | No | Yes                   |
| Integration Tests | Slow | Yes | No                    |

* Integration tests may work in nested containers though that is not a test target