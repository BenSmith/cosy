# Run all tests (shellcheck + bats)
default: shellcheck bats-unit bats-integration

# Run shellcheck on the cosy script
shellcheck:
    @echo "Running shellcheck..."
    shellcheck cosy

# Run shellcheck with specific severity level
shellcheck-strict:
    @echo "Running shellcheck (strict mode)..."
    shellcheck --severity=style cosy

# Run all bats tests (unit + integration)
bats: bats-unit bats-integration

# Run unit tests (can run inside containers)
bats-unit:
    @echo "Running unit tests..."
    @if [ ! -d "test/unit" ]; then \
        echo "Error: test/unit directory not found"; \
        exit 1; \
    fi
    time bats test/unit/

# Run integration tests (requires host with podman)
bats-integration:
    @echo "Running integration tests (requires host with podman)..."
    @if [ ! -d "test/integration" ]; then \
        echo "Error: test/integration directory not found"; \
        exit 1; \
    fi
    @echo "Integration tests run concurrently, the output buffering makes output chunky"
    time bats -j 6 test/integration/

# Run a specific bats test file
bats-file FILE:
    @echo "Running bats test: {{FILE}}"
    bats test/{{FILE}}

# Run all tests with verbose output
test-verbose: shellcheck
    @echo "Running bats tests (verbose)..."
    bats --verbose-run test/

# Install testing dependencies (Fedora)
install-deps-fedora:
    @echo "Installing testing dependencies for Fedora..."
    sudo dnf install -y ShellCheck bats

# Clean up test containers and artifacts
clean-tests:
    @echo "Cleaning up test containers..."
    @for container in $$(podman ps -a --filter name=bats-test --format '{{{{.Names}}'); do \
        echo "Removing $$container..."; \
        podman rm -f $$container 2>/dev/null || true; \
    done
    @echo "Cleaning up test home directories..."
    @rm -rf /tmp/cosy-bats-tests 2>/dev/null || true
    @echo "Cleanup complete"

# Run shellcheck and show what it checks
check-info:
    @echo "ShellCheck version:"
    @shellcheck --version
    @echo ""
    @echo "Checking cosy script for common issues..."
    @shellcheck --format=gcc cosy || true

# Dry-run test (show what would be executed)
dry-run:
    @echo "Dry-run test of basic operations..."
    ./cosy --dry-run create test-container
    @echo ""
    ./cosy --dry-run run test-container echo "hello"

# Watch mode - run tests on file changes (requires entr)
watch:
    @echo "Watching for changes (requires 'entr' package)..."
    @echo "cosy" | entr -c just default

# Alias for bats-integration
integration: bats-integration

# Run seccomp profile tests (fast, JSON validation)
seccomp-tests:
    @echo "Running seccomp profile tests..."
    @if ! command -v jq >/dev/null 2>&1; then \
        echo "Warning: jq not installed, some tests will be skipped"; \
        echo "Install with: sudo dnf install jq"; \
    fi
    bats test/integration/seccomp.bats

# Run seccomp syscall verification tests (slow, creates containers)
seccomp-tests-full:
    @echo "Running full seccomp syscall verification tests..."
    @echo "Warning: This creates real containers and tests syscall blocking"
    @echo "This may take several minutes..."
    COSY_TEST_SECCOMP_SYSCALLS=true bats test/integration/seccomp-syscall.bats

# Run all seccomp tests (fast + slow)
seccomp-tests-all: seccomp-tests seccomp-tests-full

# List all available commands
list:
    @just --list
