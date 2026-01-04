# Examples

Detailed examples for common cosy use cases.

## Table of Contents

- [Photo Editing (GIMP)](#photo-editing-gimp)
- [Media Player (VLC)](#media-player-vlc)
- [Web Browser (Firefox)](#web-browser-firefox)
- [Development Environment (VSCode with Dev Containers)](#development-environment-vscode-with-dev-containers)
- [Isolated Application (No Network)](#isolated-application-no-network)
- [Desktop Integration](#desktop-integration)
- [Running Systemd Services](#running-systemd-services)
- [Custom Bootstrap Scripts](#custom-bootstrap-scripts)
- [Managing Multiple Containers](#managing-multiple-containers)
- [Changing Container Configuration](#changing-container-configuration)
- [Running Commands as Root](#running-commands-as-root)
- [Network Debugging and Control](#network-debugging-and-control)
- [Troubleshooting](#troubleshooting)

## Digital Art (Blender, GIMP, Inkscape)

Setup a photo editor with GPU acceleration and access to your Pictures folder:

```bash
# Setup with GPU and Pictures folder mounted
cosy run --root --gpu -v ~/Pictures:/home/$USER/Pictures photo-editor -- dnf install -y blender gimp inkscape

# Run
cosy run photo-editor blender
```

## Media Player (VLC)

Setup a media player with audio and GPU support:

```bash
# Setup
cosy run --root --audio --gpu vlcbox -v ~/Videos:/videos:ro -- dnf install -y vlc

# Run with video folder mounted read-only
cosy run vlcbox vlc
```

## Web Browser (Firefox)

Isolate your web browsing in a container:

```bash
cosy run --root firefox-container --dbus --gpu --audio -- dnf install -y firefox

cosy run firefox-container firefox
```

## Development Environment (VSCode with Dev Containers)

Setup VSCode with the ability to launch dev containers on the host:

```bash
# Setup with Podman socket and Projects folder
cosy run --root --podman -v $HOME/Projects:/home/$USER/Projects vscode -- dnf install -y code podman

# Enable Podman socket on host (if not already enabled)
systemctl --user enable --now podman.socket

# Run VSCode
cosy run vscode code

# In VSCode, configure "Dev Containers" extension:
# - Set dockerPath: "podman"
# - Dev containers will launch as siblings on the host (not nested)
```

**How it works:**
- The `--podman` flag mounts the Podman socket into the container
- VSCode's Dev Containers extension uses this socket to launch containers
- These dev containers run alongside your cosy container, not inside it
- They have the same privileges and isolation level as the parent cosy container

**Security note:** The `--podman` flag gives the container access to create siblings on your host. Only use this with trusted applications.

## Isolated Application (No Network)

Run untrusted applications without network access:

```bash
# Setup application with no network access
cosy enter --network none --gpu isolated-app
dnf install suspicious-application
exit

# Run without internet access
cosy run isolated-app suspicious-application
```

**Network modes:**
- `default` - Isolated network namespace with internet access via NAT (default)
- `host` - Uses host's network stack directly (less isolated, can access localhost services)
- `none` - Completely disables network access

## Desktop Integration

Create desktop application launchers for your containerized applications so they appear in your desktop environment's application menu.

### Basic Desktop Entry

```bash
# Setup container with GUI app
cosy run --root photo-editor -- dnf install -y gimp

# Create desktop launcher
cosy desktop create photo-editor --name "Photo Editor" --icon gimp -- gimp

# The application now appears in your application menu
# Clicking it runs: cosy run photo-editor gimp
```

### Advanced Desktop Entry with MIME Types

Create launchers that handle specific file types or URLs:

```bash
# Browser with URL and HTML file associations
cosy desktop create browser \
  --name "Firefox" \
  --icon firefox \
  --comment "Web Browser" \
  --categories "Network;WebBrowser;" \
  --mime-types "text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https" \
  -- firefox

# Image editor with image file associations
cosy desktop create gimp-box \
  --name "GIMP" \
  --icon gimp \
  --mime-types "image/png;image/jpeg;image/gif" \
  -- gimp
```

### Managing Desktop Entries

```bash
# List all desktop entries
cosy desktop list

# Remove a desktop entry (container remains)
cosy desktop rm photo-editor

# Update desktop database if entries don't appear
cosy desktop install
```

### Auto-Cleanup

Desktop entries are automatically removed when you delete a container's home directory:

```bash
# This removes both the container AND its desktop entry
cosy rm --home photo-editor

# This removes only the container (desktop entry remains)
cosy rm photo-editor
```

### Available Options

The `cosy desktop create` command supports these options (all before `--`):

- `--name "Name"` - Application name (default: container name)
- `--icon icon-name` - Icon name or path (e.g., "firefox", "/path/to/icon.png")
- `--comment "Description"` - Application description
- `--categories "Cat1;Cat2;"` - Desktop categories (default: "Utility;")
- `--mime-types "type1;type2"` - MIME types for file associations
- `--terminal` - Run in terminal window
- `--no-startup-notify` - Disable startup notification

Everything after `--` becomes the command and its arguments.

### Desktop Files Location

Desktop entries are stored in:
- Desktop file: `~/.local/share/applications/cosy-<container>.desktop`
- Metadata: `~/.local/share/cosy/<container>/.desktop-metadata`

## Running Systemd Services

Run systemd-managed services inside a container.

### Step 1: Create a systemd-enabled base image

```bash
# Create a Containerfile with systemd
cat > systemd.Containerfile <<'EOF'
FROM fedora:43

RUN dnf install -y systemd httpd postgresql
RUN systemctl enable httpd postgresql

CMD ["/usr/bin/init"]
EOF

# Build the image
podman build -t localhost/fedora-systemd:43 -f systemd.Containerfile .
```

### Step 2: Use with cosy

```bash
# Create and start container
cosy create --image localhost/fedora-systemd:43 --systemd=always systemd-container

# Enter the container
cosy enter systemd-container

# Inside the container, check service status
systemctl status httpd
systemctl status postgresql
```

**Alternative: Install services after creation**

If you prefer to install services after creating the container:

```bash
# Build base image with just systemd
cat > systemd-base.Containerfile <<'EOF'
FROM fedora:43
RUN dnf install -y systemd
CMD ["/usr/bin/init"]
EOF

podman build -t localhost/fedora-systemd:43 -f systemd-base.Containerfile .

# Create container and install services
cosy run --root --image localhost/fedora-systemd:43 --systemd=always systemd-container -- \
  dnf install -y httpd postgresql && systemctl enable httpd postgresql
```

**Systemd modes:**
- `--systemd=always` - Force systemd mode (recommended when using /usr/bin/init)
- `--systemd=true` - Auto-detect (default, enables systemd when CMD is /usr/bin/init)
- `--systemd=false` - Disable systemd mode

**How it works:**
- `--systemd` flag configures Podman to set up the container for systemd
- Container CMD is `/usr/bin/init` which starts systemd as PID 1
- Podman automatically adds tmpfs mounts on `/run`, `/tmp`, etc.
- cgroups are made writable for systemd to manage services

**Use cases:**
- Run traditional Linux services (httpd, postgresql, etc.)
- Test systemd unit files
- Run multiple services in one container
- Develop and test service configurations

See [podman systemd documentation](https://docs.podman.io/en/v5.6.2/markdown/podman-run.1.html#systemd-true-false-always).

## Custom Bootstrap Scripts

Customize container initialization by overriding or appending to the built-in bootstrap script.

### Inline Commands (Quick One-Liners)

```bash
# Replace built-in bootstrap with inline command
cosy create --bootstrap-inline "echo 'Custom setup'; dnf install -y vim" myapp

# Append inline command after user creation
cosy create --bootstrap-append-inline "dnf install -y git htop" myapp
```

### Script Files (Complex Setup)

```bash
# Create a custom bootstrap script (replaces built-in)
cat > /tmp/custom-bootstrap.sh <<'EOF'
#!/bin/sh
set -e

# Your custom initialization here
echo "Running custom bootstrap"
# Note: You must handle user creation yourself
EOF

cosy create --bootstrap-script /tmp/custom-bootstrap.sh myapp

# Create an append script (runs after built-in user creation)
cat > /tmp/extra-setup.sh <<'EOF'
#!/bin/sh
set -e

# Additional setup after user creation
dnf install -y vim git htop
systemctl --user enable some-service
EOF

cosy create --bootstrap-append-script /tmp/extra-setup.sh myapp
```

### Environment Variables (Persistent Config)

```bash
# Set up a common bootstrap script for all containers
cat > ~/.config/cosy-bootstrap.sh <<'EOF'
#!/bin/sh
# Common setup for all my containers
dnf install -y vim git bash-completion
EOF

# Use it for all containers
export COSY_BOOTSTRAP_APPEND_SCRIPT=~/.config/cosy-bootstrap.sh
cosy create myapp1
cosy create myapp2  # Both will use the bootstrap script
```

**Priority order:**
1. CLI inline flags (`--bootstrap-inline`, `--bootstrap-append-inline`)
2. CLI file flags (`--bootstrap-script`, `--bootstrap-append-script`)
3. Environment variables (`COSY_BOOTSTRAP_SCRIPT`, `COSY_BOOTSTRAP_APPEND_SCRIPT`)
4. Built-in bootstrap

**Notes:**
- Bootstrap scripts run as container root during container creation
- `--bootstrap-script` replaces the built-in (you handle user creation)
- `--bootstrap-append-*` runs after the built-in (user already created)
- Inline options override file options

## Managing Multiple Containers

### List Containers with Features

```bash
# View all containers with their features and status
cosy ls

# Example output:
# === Container Homes ===
# 128M     firefox-browser          [display]
# 256M     gimp                     [display,gpu]
# 512M     vlc                      [display,audio,gpu]
# 1.2G     vscode                   [display,podman]
#
# === Running Containers ===
# NAMES              STATUS                   IMAGE
# vlc                Up 2 hours              fedora:43
#
# === Stopped Containers ===
# NAMES              STATUS                   IMAGE
# firefox-browser    Exited (0) 3 days ago   fedora:43
```

### Inspect Container Features

```bash
# View container features in human-readable format (default)
cosy inspect photo-editor

# Example output:
# Container: photo-editor
# Base image: fedora:43
# Network mode: default (pasta)
# Display: enabled
# Audio: enabled
# GPU: enabled
# ...

# Get command-line flags for scripting
cosy inspect --format=cli photo-editor
# Output: --image fedora:43 --network default --audio --gpu ...
```

### Remove Multiple Containers

```bash
# Remove containers (preserves home directories)
cosy rm old-container test-container unused-app

# Remove containers and their home directories
cosy rm --home old-container test-container unused-app
```

## Changing Container Configuration

Containers are created with fixed features (audio, GPU, mounts, network, security options). The `cosy recreate` and `cosy clone` commands allow changing these features while preserving both your data and installed packages.

### Using `cosy recreate` and `cosy clone`

These commands transfer the container's writable layer, preserving all installed packages and system modifications:

```bash
# Create initial container with GPU only
cosy create --gpu photo-editor --bootstrap-append-inline "dnf install -y gimp inkscape krita"

# Later, decide you need audio support
# Preview the changes first
cosy recreate --audio --show-diff photo-editor

# Output shows:
# Current configuration for 'photo-editor':
#   GPU: enabled
#   Audio: disabled
#
# Requested changes:
#   Audio: disabled → enabled

# Apply the changes (packages are preserved!)
cosy recreate --audio photo-editor

# Your installed packages (gimp, inkscape, krita) are still there!
cosy run photo-editor gimp
```

**What's preserved with `recreate`:**
- ✅ Everything in the container's home directory
- ✅ All installed packages (gimp, inkscape, etc.)
- ✅ System configurations and modifications
- ✅ User settings, configs, documents

### `recreate` vs `clone`

**`recreate` - Replaces the existing container in place:**

```bash
# Add audio to existing container
cosy recreate --audio photo-editor

# Change network mode
cosy recreate --network none untrusted-app

# Add multiple features
cosy recreate --audio --gpu --dbus media-center
```

**`clone` - Creates a new container, keeps the original:**

```bash
# Create a variant with different features
cosy clone --audio --network host photo-editor photo-editor-v2

# Test new configuration before committing
cosy clone --gpu --dbus dev-env dev-env-test
cosy enter dev-env-test    # test thoroughly
cosy rm dev-env            # satisfied? remove the old one

# Keep both versions for different use cases
cosy clone --network none secure-browser insecure-browser
# Now you have:
#   - secure-browser: no network access
#   - insecure-browser: with network access
```

### Recreation Examples

**Adding audio support:**
```bash
cosy recreate --audio myapp
```

**Changing network isolation:**
```bash
# Remove network access
cosy recreate --network none untrusted-app

# Enable host networking
cosy recreate --network host dev-tool
```

**Adding volume mounts:**
```bash
# Add new mount while keeping existing features
cosy recreate -v ~/Documents:/docs photo-editor
```

**Non-interactive recreation (for scripts):**
```bash
# Skip confirmation prompt
cosy recreate --audio --yes batch-processor
```

### Manual Method (Alternative)

If you prefer manual control or want to change the base image, you can use the remove-and-recreate method:

```bash
# Remove container (preserves home directory)
cosy rm photo-editor

# Recreate with new features and/or different image
cosy run --root --gpu --audio --image fedora:43 photo-editor -- dnf install gimp inkscape  # Must reinstall applications


# Your home directory data is preserved:
# - Settings and configs
# - Documents and files
# - Application data
#
# But system-installed packages must be reinstalled and system configuration is not preserved
```

**When to use the manual method:**
- Changing the base image (e.g., `fedora:42` → `fedora:43`)
- Major system upgrades
- Complete clean slate is desired

**To completely remove everything:**
```bash
cosy rm --home photo-editor
```

## Running Commands as Root

### Quick One-Off Root Commands

```bash
# Install packages
cosy run --root myapp -- dnf install -y vim htop

# Update the system
cosy run --root myapp -- dnf update -y

# Run commands with flags (use -- to separate from cosy options)
cosy run --root myapp -- systemctl status some-service
```

### Interactive Root Shell

```bash
# Default root shell
cosy enter --root myapp

# Custom root shell with command first
cosy run --root myapp "dnf install -y vim; bash"  # hacky but convenient
```

### Root vs User Commands

```bash
# As root (for system changes)
cosy run --root myapp -- dnf install firefox

# As user (for running applications)
cosy run myapp firefox

# Enter as root (for maintenance)
cosy enter --root myapp

# Enter as user (for interactive use)
cosy enter myapp
```

### Using Sudo Instead of --root

For development environments where you want sudo access:

```bash
# Create container with wheel group access
cosy create --groups wheel devbox

# Inside the container, configure passwordless sudo (one-time setup)
cosy run --root devbox -- sh -c 'echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd'
cosy run --root devbox -- chmod 0440 /etc/sudoers.d/wheel-nopasswd

# Install packages and configure
cosy run --root devbox -- dnf install -y sudo vim git

# Now you can use sudo as the regular user
cosy enter devbox
sudo dnf install htop  # Works without password
```

**When to use sudo vs --root:**
- Use `--root` for quick system administration (installing packages, system updates)
- Use `--groups wheel` + sudo for development environments where you frequently need root (more realistic simulation of normal Linux usage)

## Network Debugging and Control

The `cosy network` subcommand provides tools for inspecting and controlling container networking.

### Check What an Application is Doing

Get a quick overview of network activity:

```bash
# Check network configuration and statistics
cosy network inspect myapp

# Output:
# Container: myapp
# ============================================
#
# Network Mode: pasta
# IP Address: 10.88.0.2
# Gateway: 10.88.0.1
# DNS Servers: 192.168.1.1
#
# Active Connections: 3
# Total Bandwidth: 1.2 MiB received, 512 KiB transmitted
```

### Monitor Active Connections

See what connections your application is making:

```bash
# List all active connections
cosy network connections browser

# Output shows TCP/UDP connections with remote IPs and ports
```

### Check Bandwidth Usage

Monitor bandwidth statistics per interface:

```bash
# Show current bandwidth statistics
cosy network stats streaming-app

# Watch bandwidth change over time
watch -n 5 cosy network stats streaming-app
```

### Test Offline Behavior

Test how your application behaves when network connectivity is lost:

```bash
# Start the application
cosy run myapp firefox &

# Wait for it to fully load
sleep 5

# Disable networking
cosy network disconnect myapp

# Re-enable networking
cosy network reconnect myapp

```

### Debug Connection Issues

Monitor connections continuously to debug issues:

```bash
# Start app in background
cosy run myapp application &

# Check connections every few seconds
while true; do
    clear
    cosy network connections myapp
    sleep 2
done
```

### List Networks

See which networks your cosy containers are using:

```bash
# Show all networks with cosy containers
cosy network list

# Output:
# === Podman Networks ===
#
# Network: podman
#   Subnet: 10.88.0.0/16
#   Cosy Containers: myapp browser photo-editor
```

### Simulate Network Failures

Test application resilience:

```bash
# Start app normally
cosy run resilient-app application &

# Simulate network outage
cosy network disconnect resilient-app

# Wait to observe behavior
sleep 30

# Restore network
cosy network reconnect resilient-app
```

### Test Under Poor Network Conditions

Simulate slow or unreliable connections using traffic shaping:

```bash
# Simulate slow mobile connection (persistent settings)
cosy network throttle streaming-app 512kbit --persist
cosy network delay streaming-app 100ms --persist
cosy network loss streaming-app 2% --persist

# Run the app to observe behavior
cosy run streaming-app vlc ~/Videos/test.mp4

# Reset to normal when done testing
cosy network reset streaming-app
```

**Temporary vs Persistent Settings:**

```bash
# Temporary (reset on container restart)
cosy network throttle myapp 1mbit
cosy run myapp application
# Settings active only for this session

# Persistent (survive container restarts)
cosy network throttle myapp 1mbit --persist
cosy stop myapp
cosy run myapp application
# Settings automatically reapplied on start
```

### Network Debugging Workflow

Debug network issues step by step:

```bash
# 1. Check current network state
cosy network inspect myapp

# 2. Watch new connections in real-time
cosy network watch myapp
# (In another terminal, use the app)

# 3. If you need deep packet analysis
cosy network capture myapp /tmp/myapp.pcap
# (Use app, press Ctrl+C when done)
wireshark /tmp/myapp.pcap

# 4. Test offline behavior
cosy network disconnect myapp
# (Observe app behavior)
cosy network reconnect myapp
```

### Network Requirements

All network commands use host-side tools and do not require installing anything inside containers.

**Required host packages:**
```bash
# Install all network tools on host
sudo dnf install -y util-linux iproute iproute-tc tcpdump
```

For more details, see [docs/NETWORK.md](NETWORK.md).

## Troubleshooting

### Changing container features

- Preview changes: `cosy recreate --show-diff --audio --gpu <name>`
- Recreate in-place: `cosy recreate --yes --audio --gpu <name>` (preserves installed packages and data)
- Clone to new name: `cosy recreate --yes --audio <name> <new-name>`
- Alternative method (if you prefer manual control):
  - `cosy rm <name>` (preserves home directory)
  - `cosy enter --gpu --audio <name>`
  - Applications must be reinstalled, but data is preserved

### Symlinks to host paths

- Symlinks outside the container's home appear broken inside
- Mount the target with `-v` or use relative paths within home

### Command flags

- Use `--` to separate cosy options from command flags
- Example: `cosy run myapp -- grep -r pattern /path`
