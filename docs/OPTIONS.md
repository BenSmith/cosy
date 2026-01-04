# Options Reference

Complete reference for all cosy options, flags, and environment variables.

## Table of Contents

- [Default File Locations](#default-file-locations)
- [Global Options](#global-options)
- [Subcommands](#subcommands)
- [Container Options](#container-options)
- [Environment Variables](#environment-variables)

## Default File Locations

- **Container homes:** `~/.local/share/cosy/<container-name>/`
- **Log file:** `~/.local/share/cosy/cosy.log` (when `COSY_LOG=true`)
 
## Global Options

Options that apply to the cosy command itself, before the subcommand:

| Option | Description |
|--------|-------------|
| `--debug` | Show podman commands before executing them |
| `--dry-run` | Show podman commands without executing (works inside containers) |
| `--help`, `-h` | Show help message |
| `--version`, `-V` | Show version information |

**Example:**
```bash
cosy --debug run myapp firefox
cosy --dry-run create --gpu photo-editor
```

## Subcommands

### Container Management

| Command | Description |
|---------|-------------|
| `create [options] <name>` | Create container with features (doesn't enter) |
| `enter [options] <name> [command]` | Enter container (auto-creates if needed) |
| `run [options] <name> <command>` | Run command in container (auto-creates if needed) |

### Operations

| Command | Description |
|---------|-------------|
| `inspect [--format=<type>] <name>` | View container features (formats: human, cli) |
| `list`, `ls` | List all containers with features and status |
| `recreate [options] <container> [new-name]` | Recreate container with new features (preserves writable layer) |
| `rm [--home] <name> [<name> ...]` | Remove one or more containers |
| `stop <name>` | Stop a running container |

### Container Inspection

The `inspect` command shows container features by querying the actual container state via `podman inspect`. 

**Formats:**
- `cli` - Shows equivalent CLI flags that would recreate the container
- `human` (default) - Human-readable output showing all features

**Feature Detection:**

Cosy automatically detects features by examining the container configuration:

- **--audio** - Detected by `cosy.audio` label
- **--dbus --dbus-system** - Detected by `cosy.dbus` and `cosy.dbus_system` labels
- **--device** - Detected by `cosy.devices` label (custom devices added with `--device`)
- **--display** - Detected by `cosy.display` label (defaults to enabled)
- **--gpu** - Detected by `cosy.gpu` label
- **--groups** - Detected by `cosy.groups` label (supplementary groups for container user)
- **--input** - Detected by `cosy.input` label (input devices: `/dev/input`, `/dev/uinput`, `/dev/hidraw*`)
- **--network** - Read from `NetworkMode` (normalized: `slirp4netns`/`pasta`/`bridge` → `default`)
- **--podman** - Detected by `cosy.podman` label
- **--read-only** - Read from `ReadonlyRootfs` flag
- **--systemd** - Detected by `cosy.systemd` label
- **--tmpfs** - Read from `Tmpfs` configuration (systemd tmpfs mounts excluded when systemd detected)

**Platform Notes:**

Cosy is designed primarily for Fedora and makes assumptions based on Fedora's defaults:
- Audio support uses PipeWire (Fedora's default) or PulseAudio sockets in standard XDG locations
- Systemd support uses Podman's `--systemd=always` mode with standard tmpfs mounts

**Examples:**
```bash
# View container features
cosy inspect myapp

# Get CLI flags to recreate container
cosy inspect --format=cli myapp
```

### Utilities

| Command | Description |
|---------|-------------|
| `completion <shell>` | Generate shell completion script (bash or zsh) |
| `help` | Show help message |
| `network <action>` | Inspect and control container networking |

### Subcommand-Specific Options

#### inspect

| Option | Description |
|--------|-------------|
| `--format=<type>` | Output format: `human` (default) or `cli` |

**Example:**
```bash
cosy inspect --format=cli myapp
```

#### recreate

| Option | Description |
|--------|-------------|
| `--show-diff` | Preview changes without executing |
| `--yes`, `-y` | Skip confirmation prompt (for scripts) |

**Example:**
```bash
cosy recreate --show-diff --audio myapp
cosy recreate --yes --gpu myapp
```

#### rm

| Option | Description |
|--------|-------------|
| `--home` | Also remove container's home directory |

**Example:**
```bash
cosy rm --home old-container
```

#### network (throttle, delay, loss)

| Option | Description |
|--------|-------------|
| `--persist` | Make network settings survive container restarts |

**Example:**
```bash
cosy network delay myapp 100ms --persist
cosy network loss myapp 2% --persist
cosy network throttle myapp 1mbit --persist
```

### Container Recreation

The `recreate` and `clone` commands allow changing container features while preserving installed packages and system modifications.

#### recreate - In-Place Recreation

```bash
cosy recreate [options] <container-name>
```

Replaces the existing container with new features:
- Stops the container if running
- Creates temporary container with new features
- Transfers writable layer (which preserves installed packages, system settings, logs, etc.)
- Removes original container
- Renames temporary container to original name
- Home directory stays in the same location


**Note:** copying the writable layer onto a different base container image will probably go poorly

**Example:**
```bash
# Add audio support to existing container
cosy recreate --audio photo-editor

# Change network mode and add GPU
cosy recreate --network none --gpu dev-container
```

**Options:**

| Option | Description |
|--------|-------------|
| `--show-diff` | Preview changes without executing |
| `--yes` | Skip confirmation prompt (for scripts) |

#### clone - Clone with Different Features

```bash
cosy clone [options] <source-container> <dest-name>
```

Creates a new container with different features:
- Copies home directory to new location
- Creates new container with specified name and features
- Duplicates writable layer from source to new container
- Original container remains completely unchanged
- Both containers exist independently

**Note:** copying the writable layer onto a different base container image will probably go poorly

**Example:**
```bash
# Create variant with audio and different network mode
cosy clone --audio --network host photo-editor photo-editor-v2

# Test new configuration before removing original
cosy clone --gpu --dbus dev-env dev-env-test
cosy enter dev-env-test    # test it first
cosy rm dev-env            # satisfied? remove old one
```

**Options:**

| Option | Description |
|--------|-------------|
| `--show-diff` | Preview changes without executing |
| `--yes` | Skip confirmation prompt (for scripts) |

#### Shared Information for Both Commands

All standard creation options (`--audio`, `--gpu`, `--network`, `-v`, etc.) can be used with both `recreate` and `clone`.

#### What Gets Preserved

**Writable layer preservation:**
- All installed packages (dnf/apt installed software)
- System configuration changes
- Files added or modified outside the home directory

**Home directory:**
- `recreate` (in-place): Same location, fully preserved
- `clone`: Copied to new location

#### What Can Be Changed

- ✅ Audio (`--audio`)
- ✅ CMD override (`--cmd`)
- ✅ D-Bus (`--dbus`, `--dbus-system`)
- ✅ Devices (`--device`)
- ✅ Display (`--no-display`)
- ✅ ENTRYPOINT override (`--entrypoint`)
- ✅ GPU (`--gpu`)
- ✅ Groups (`--groups`)
- ✅ Input devices (`--input`)
- ✅ Network mode (`--network default|none|host`)
- ✅ Podman socket (`--podman`)
- ✅ Security options (`--read-only`, `--tmpfs`, `--security-opt`)
- ✅ Systemd mode (`--systemd`)
- ✅ Volume mounts (`-v`)
- ❌ Base image (not supported)

#### Example Workflows

**Preview before applying:**
```bash
# See what would change
cosy recreate --audio --show-diff photo-editor

# Apply if satisfied
cosy recreate --audio --yes photo-editor
```

**Non-interactive (for scripts):**
```bash
cosy recreate --audio --yes photo-editor
```

#### Technical Notes

- Uses direct overlay upperdir transfer via `podman unshare`
- No frozen layer accumulation (unlike `podman commit`)
- Storage efficient: base image + one writable layer
- Requires overlay storage backend (most common)
- Containers must be stopped during transfer

## Container Options

Options that can be used with `create`, `enter`, and `run` commands. All options are listed alphabetically below.

| Option | Default          | Description |
|--------|------------------|-------------|
| `--` | -                | Stop parsing options; everything after is treated as the command |
| `--audio` | disabled         | Enable audio support (PipeWire/PulseAudio) |
| `--bootstrap-append-inline <cmd>` | -                | Append inline command to built-in bootstrap (runs as root during creation) |
| `--bootstrap-append-script <path>` | -                | Append script file to built-in bootstrap (runs as root during creation) |
| `--bootstrap-inline <cmd>` | -                | Replace built-in bootstrap with inline command (runs as root during creation) |
| `--bootstrap-script <path>` | -                | Replace built-in bootstrap with script file (runs as root during creation) |
| `--cmd <command>` | `sleep infinity` | Container default command (supports multi-word via word-splitting) |
| `--dbus` | disabled         | Enable D-Bus session bus (for desktop integration). Automatically masks container's D-Bus services via symlinks to prevent conflicts |
| `--dbus-system` | disabled         | Enable D-Bus system bus (for system services). Automatically masks container's D-Bus services via symlinks to prevent conflicts |
| `--device <device>` | none             | Mount device into container (can be specified multiple times; e.g., /dev/kvm, /dev/ttyUSB0) |
| `--entrypoint <path>` | none             | Override container entrypoint |
| `--gpu` | disabled         | Enable GPU access via `/dev/dri` |
| `--groups <groups>` | none             | Comma-separated list of supplementary groups for the container user (e.g., `wheel,docker`) |
| `--image <image>`, `-i <image>` | `fedora:43`      | Base container image to use |
| `--input` | disabled         | Enable input device access (joysticks, gamepads, keyboards, mice via `/dev/input`, `/dev/uinput`, `/dev/hidraw*`) |
| `--network <mode>` | `default`        | Network mode: `default` (isolated), `none` (disabled), or `host` (shared) |
| `--no-display` | display enabled  | Disable display forwarding (X11/Wayland) |
| `--podman` | disabled         | Enable Podman socket access (allows launching sibling containers) |
| `--read-only` | disabled         | Mount container root filesystem as read-only |
| `--root` | disabled         | Execute command as root user (only for `enter` and `run` commands) |
| `--security-opt <option>` | `label=disable`  | Security options passed to podman (e.g., `label=type:spc_t`, `seccomp=unconfined`). Can be specified multiple times |
| `--systemd MODE` | `true`           | Systemd mode: `true` (auto-detect), `false` (disabled), or `always` (forced). Accepts `--systemd=MODE` or `--systemd MODE` syntax. |
| `--tmpfs <path>` | none             | Mount tmpfs at path (can be specified multiple times) |
| `-v <src>:<dst>[:<opts>]`, `--volume` | none             | Add volume mount (can be specified multiple times; uses Docker/Podman syntax) |

### Detailed Examples

**Argument separator:**
```bash
# Use -- to prevent cosy from parsing command flags
cosy run --root myapp -- dnf install -y vim
cosy run myapp -- grep -r "pattern" /path
```

**Audio:**
```bash
cosy create --audio media-player
```
Enables audio support by mounting `/dev/snd` (for ALSA direct access) and appropriate audio sockets from `$XDG_RUNTIME_DIR` (PipeWire and/or PulseAudio when available). All components are optional - if a socket or device doesn't exist, it's skipped without errors.

**Bootstrap scripts:**
```bash
# Replace bootstrap with inline command
cosy create --bootstrap-inline "echo 'Custom setup'" myapp

# Append to built-in bootstrap (user already created)
cosy create --bootstrap-append-inline "dnf install -y vim" myapp

# Use script files
cosy create --bootstrap-script /path/to/bootstrap.sh myapp
cosy create --bootstrap-append-script /path/to/extra.sh myapp
```
Bootstrap scripts run as root during container creation. Priority: CLI inline > CLI file > environment variable > built-in.

**CMD and entrypoint:**
```bash
# Multi-word command (word-splitting occurs)
cosy create --cmd "sleep infinity" myapp

# Override entrypoint
cosy create --entrypoint /usr/bin/python3 --cmd "-m http.server 8000" myapp

# Complex commands with shell
cosy create --cmd "/bin/bash -c 'setup.sh && main-app'" myapp
```
Word-splitting: `"sleep infinity"` becomes two arguments (`sleep` and `infinity`).

**D-Bus:**
```bash
# Session bus (for desktop apps)
cosy create --dbus myapp

# System bus (for system services)
cosy create --dbus-system myapp
```

**Device access:**
```bash
# Mount single device
cosy create --device /dev/kvm vm-tool

# Mount multiple devices
cosy create --device /dev/kvm --device /dev/video0 multimedia-app

# Combine with GPU (which uses --device internally for /dev/dri)
cosy create --gpu --device /dev/kvm graphics-vm
```
Allows direct access to host devices. Common examples: `/dev/kvm` (virtualization), `/dev/video0` (webcams), `/dev/ttyUSB0` (serial devices), `/dev/snd/*` (audio devices).

**Display and GPU:**
```bash
# Disable display forwarding
cosy create --no-display background-service

# Enable GPU access
cosy create --gpu photo-editor
```
By default, display forwarding is enabled (X11 and Wayland auto-detected).

**User groups:**
```bash
# Add user to wheel group for sudo access
cosy create --groups wheel myapp

# Add user to multiple groups
cosy create --groups wheel,docker,libvirt devbox

# Combine with environment variable (for defaults)
export COSY_GROUPS=wheel
cosy create myapp  # user will be in wheel group
```
The container user is automatically added to the specified supplementary groups. Common use cases include `wheel` (for sudo access when combined with appropriate sudoers configuration), `docker` (for Docker socket access), or distribution-specific groups like `audio`, `video`, `input`.

**Input devices:**
```bash
# Enable joystick/gamepad access
cosy create --input gaming-app

# Combine with GPU and audio for gaming
cosy create --input --gpu --audio gaming-setup

# Access to input devices for development
cosy create --input --dbus input-tester
```
Provides access to `/dev/input` (joysticks, gamepads, keyboards, mice), `/dev/uinput` (virtual input device creation), and `/dev/hidraw*` (raw HID device access). Useful for gaming, input device testing, or applications that need direct hardware access. Note: Bluetooth device pairing requires `--dbus-system` and `/dev/rfkill` access (paired devices will appear in `/dev/input`).

**Image:**
```bash
cosy create --image fedora:43 myapp
cosy create --image registry.fedoraproject.org/fedora:41 myapp
cosy create -i ubuntu:22.04 myapp
```

**Network:**
```bash
# Default: isolated namespace with internet
cosy create myapp

# No network access
cosy create --network none untrusted-app

# Host networking (less isolated)
cosy create --network host dev-tool
```
Network configuration is set at creation and requires recreation to change.

**Podman socket:**
```bash
cosy create --podman vscode
```
Mounts `/run/user/$UID/podman/podman.sock`. This allows for dev containers without nesting containers. Nesting containers requires more privileges than I wanted. **Warning:** Allows container to create sibling containers on host.

**Read-only filesystem:**
```bash
# Read-only with writable tmpfs (note: /tmp is managed automatically)
cosy create --read-only --tmpfs /var/tmp secure-app

# Multiple tmpfs mounts
cosy create --read-only --tmpfs /var/tmp --tmpfs /app/cache secure-app
```

**Security options:**
```bash
# Default behavior (labels disabled)
cosy create myapp

# Enable SELinux super privileged container type
cosy create --security-opt label=type:spc_t myapp

# Disable seccomp filtering
cosy create --security-opt seccomp=unconfined myapp

# Prevent privilege escalation
cosy create --security-opt no-new-privileges myapp

# Multiple security options
cosy create --security-opt label=type:spc_t --security-opt no-new-privileges myapp
```

**Security combinations:**
```bash
# Comprehensive hardening
cosy create --read-only --tmpfs /tmp --security-opt no-new-privileges hardened-app
```

**Systemd:**

To use systemd as init, you need a container image with systemd installed. Build a custom image:

```dockerfile
# systemd.Containerfile
FROM fedora:43

RUN dnf install -y systemd
CMD ["/usr/bin/init"]
```

```bash
# Build the image
podman build -t localhost/fedora-systemd:43 -f systemd.Containerfile .

# Use with cosy
cosy create --image localhost/fedora-systemd:43 --systemd=always systemd-container
```

**Systemd modes:**
```bash
# Auto-detect (default) - detects /usr/bin/init as CMD
cosy create --image localhost/fedora-systemd:43 myapp

# Force systemd mode
cosy create --image localhost/fedora-systemd:43 --systemd=always myapp

# Explicitly disable
cosy create --systemd=false myapp
```

**Modes:** `true` (auto-detect), `false` (disabled), `always` (forced).

When enabled, Podman adds tmpfs mounts on `/run`, `/tmp`, etc., and makes cgroups writable. See [docs here](https://docs.podman.io/en/v5.6.2/markdown/podman-run.1.html#systemd-true-false-always)

**Tmpfs:**
```bash
# Single tmpfs mount (note: /tmp is managed automatically)
cosy create --tmpfs /var/tmp myapp

# Multiple tmpfs mounts
cosy create --tmpfs /var/tmp --tmpfs /app/cache myapp
```
Provides writable, temporary storage in RAM that doesn't persist. Note that `/tmp` and `/run/user/$UID` are automatically mounted as tmpfs by cosy, and `/run` and `/run/lock` are managed by systemd when `--systemd` is used.

**Volumes:**
```bash
# Read-write bind mount
cosy run -v ~/Documents:/docs myapp editor /docs/file.txt

# Read-only bind mount
cosy run -v ~/Videos:/videos:ro myapp vlc /videos/movie.mp4

# With SELinux labels (if using label=type:* security option)
cosy run --security-opt label=type:spc_t -v ~/Pictures:/pics:Z myapp  # Private label
cosy run --security-opt label=type:spc_t -v ~/shared:/shared:z myapp  # Shared label

# Named volume
cosy run -v mydata:/data myapp
```
Uses Docker/Podman syntax. Can be specified multiple times.

## Automatic Passthrough

Unknown flags are automatically passed through to podman, enabling forward compatibility with new podman features without requiring cosy updates.

### How It Works

When cosy encounters a flag it doesn't recognize, it automatically passes it to the underlying `podman create` command. This means you can use **any** podman flag, even if cosy doesn't explicitly document it.

**Example:**
```bash
# Use --memory flag (not explicitly handled by cosy)
cosy create --audio --memory 512m myapp

# Use --cpus to limit CPU usage
cosy create --cpus 2 --memory 1g limited-app

# Use --restart policy
cosy create --restart unless-stopped daemon-app

# Combine cosy flags with passthrough flags
cosy create --gpu --audio --memory 2g --cpus 4 --shm-size 4g gaming-app
```

### Verified Passthrough

All flags are passed to podman, but cosy explicitly handles these for feature detection and management:

**Cosy-Managed Flags:**
- `--audio`, `--gpu`, `--dbus`, `--dbus-system`, `--podman`, `--no-display`
- `--network MODE`, `--device DEVICE`, `-v/--volume`, `--systemd`
- `--security-opt`, `--tmpfs`

**Common Passthrough Flags:**
- Resource limits: `--memory`, `--memory-swap`, `--cpus`, `--cpu-shares`
- Restart policies: `--restart`, `--restart-policy`
- Advanced networking: `--ip`, `--mac-address`, `--dns`, `--hostname`
- IPC/PID: `--ipc`, `--pid`, `--uts`
- Shared memory: `--shm-size`
- Labels: `--label` (custom labels, cosy adds `cosy.managed=true` automatically)

### Conflict Detection and Validation

Cosy validates certain podman-native flags to prevent conflicts with its automatic behaviors. These "intercepted flags" are checked before container creation:

**Validated Flags:**
- `--device` - Cannot use `/dev/dri` with `--gpu` (GPU feature manages this device)
- `-v/--volume` - Cannot mount to protected paths that cosy manages automatically:
  - `/home/$USER` (managed as container home)
  - `/tmp/.X11-unix` (managed by display feature)
  - `/run/user/$UID/bus` (managed by `--dbus`)
  - `/run/user/$UID/pipewire-0`, `/run/user/$UID/pulse` (managed by `--audio`)
  - `/run/dbus/system_bus_socket` (managed by `--dbus-system`)
  - `/run/user/$UID/podman/podman.sock` (managed by `--podman`)
- `--tmpfs` - Cannot mount tmpfs on paths cosy manages automatically:
  - `/tmp` (managed automatically, or by systemd when `--systemd` is used)
  - `/run/user/$UID` (managed automatically with mode 0700)
  - `/run`, `/run/lock` (managed by systemd when `--systemd` is used)

**Error Handling:**

If you try to use an intercepted flag in a way that conflicts with cosy's automatic setup, you'll get a clear error message:

```bash
$ cosy create --gpu --device /dev/dri myapp
Error: Cannot use --device /dev/dri with --gpu flag
The --gpu flag already provides access to /dev/dri.
Remove either --gpu or --device /dev/dri.

$ cosy create -v /tmp:/tmp myapp
Error: Cannot mount volume to /tmp
This path is managed automatically by cosy.
Remove the -v /tmp:/tmp flag.

$ cosy create --tmpfs /tmp myapp
Error: Cannot add tmpfs mount for /tmp
This path is managed automatically by cosy.
Remove the --tmpfs /tmp flag.
```

This validation prevents subtle issues and makes cosy's behavior more predictable

### Benefits

1. **Future-proof**: Use new podman features immediately
2. **Flexible**: No waiting for cosy updates
3. **Transparent**: See passthrough flags with `--debug`
4. **Safe**: Cosy-managed flags still work as expected

### Debugging Passthrough

Use `--debug` to see exactly what's passed to podman:

```bash
$ cosy --debug create --audio --memory 512m --cpus 2 myapp
# Shows full podman command with all flags
```

## Environment Variables

Set defaults for container options and cosy behavior. CLI flags override environment variables. All variables are listed alphabetically below.

| Variable | Default                        | Description                                                             |
|----------|--------------------------------|-------------------------------------------------------------------------|
| `COSY_AUDIO` | `false`                        | Enable audio support by default                                         |
| `COSY_BOOTSTRAP_APPEND_SCRIPT` | -                              | Path to script to append to built-in bootstrap (runs as root)           |
| `COSY_BOOTSTRAP_SCRIPT` | -                              | Path to custom bootstrap script that replaces built-in (runs as root)   |
| `COSY_CMD` | `sleep infinity`               | Container default command (supports multi-word via word-splitting)      |
| `COSY_DBUS` | `false`                        | Enable D-Bus session bus by default                                     |
| `COSY_DBUS_SYSTEM` | `false`                        | Enable D-Bus system bus by default                                      |
| `COSY_DEBUG` | `false`                        | Show podman commands before executing (same as `--debug`)               |
| `COSY_DISPLAY` | `true`                         | Enable display forwarding by default                                    |
| `COSY_DRY_RUN` | `false`                        | Show podman commands without executing (same as `--dry-run`)            |
| `COSY_ENTRYPOINT` | none                           | Container entrypoint override                                           |
| `COSY_GPU` | `false`                        | Enable GPU access by default                                            |
| `COSY_GROUPS` | none                           | Comma-separated list of default supplementary groups (e.g., `wheel,docker`) |
| `COSY_HOMES_DIR` | `~/.local/share/cosy`          | Container homes directory                                               |
| `COSY_INPUT` | `false`                        | Enable input device access by default (joysticks, gamepads, etc.)      |
| `COSY_IMAGE` | `fedora:43`                    | Default base image for containers                                       |
| `COSY_LOG` | `false`                        | Enable logging to file                                                  |
| `COSY_LOG_FILE` | `~/.local/share/cosy/cosy.log` | Log file path (when `COSY_LOG=true`)                                    |
| `COSY_NETWORK` | `default`                      | Default network mode: `default`, `none`, `host`, or custom network name |
| `COSY_PODMAN` | `false`                        | Enable Podman socket access by default - run sibling containers on host |
| `COSY_SYSTEMD` | `true`                         | Default systemd mode: `true` (auto-detect), `false`, or `always`        |

#### Command History (Audit Logging)

| Variable | Default | Description                                                             |
|----------|---------|-------------------------------------------------------------------------|
| `COSY_COMMAND_HISTORY` | `false` | Enable command history logging (opt-in)                                  |
| `COSY_COMMAND_HISTORY_FILE` | `~/.local/share/cosy/command-history.jsonl` | Path to command history log file (JSON Lines format) |
| `COSY_COMMAND_HISTORY_LOG_QUERIES` | `false` | Also log query commands like `inspect` and `ps` (creates noise)         |

**What Gets Logged:**

When enabled, cosy logs all podman commands it executes in JSON Lines format, capturing:
- Podman command and full arguments (including all flags, paths, and container names)
- Cosy command that triggered the operation (e.g., `create --audio myapp`)
- Container name, image name, and image ID (SHA256 hash)
- Feature flags (audio, gpu, display, network mode, systemd, etc.)
- Timestamps (UTC), exit codes, and command duration
- Session ID (preserved across `recreate`, new for `clone`)
- Invocation ID (unique per cosy command) and sequence numbers

**Privacy Considerations:**

⚠️ **The log file may contain sensitive information:**
- Container names and image names (may reveal project names or internal tools)
- Mount paths and volume mappings (exposes filesystem structure)
- Command arguments (could include passwords, API keys, or tokens if passed as arguments)
- Device paths and custom labels
- Network configuration details
- Timestamps revealing work patterns

**Recommendations:**
- Keep log files in your home directory (not in shared locations)
- Review logs before sharing them (e.g., in bug reports)
- Add `*.jsonl` to `.gitignore` if storing in version-controlled directories
- Rotate or archive logs periodically to manage size
- Consider the log file content when setting file permissions

**Use Cases:**
- Debugging container configuration issues
- Auditing container operations for compliance
- Understanding command usage patterns and frequency
- Replaying container creation sequences
- Tracking changes over time

**Query Filtering:**

By default, read-only query commands (`podman inspect`, `podman ps`, `container exists`) are not logged to reduce noise. Set `COSY_COMMAND_HISTORY_LOG_QUERIES=true` to log everything.

### Example Configuration

```bash
# ~/.bashrc or ~/.zshrc

# Enable GPU and audio by default
export COSY_GPU=true
export COSY_AUDIO=true

# Set default command for containers (multi-word example)
export COSY_CMD="sleep infinity"

# Enable logging
export COSY_LOG=true

# Common bootstrap script for all containers
export COSY_BOOTSTRAP_APPEND_SCRIPT=~/.config/cosy-bootstrap.sh

# Enable command history logging for auditing
export COSY_COMMAND_HISTORY=true
export COSY_COMMAND_HISTORY_FILE=~/.local/share/cosy/command-history.jsonl
```

### Command History Example Usage

Once enabled, the command history log can be queried with standard JSON tools:

```bash
# Enable command history
export COSY_COMMAND_HISTORY=true

# Use cosy normally
cosy create --audio --gpu myapp
cosy run myapp firefox

# View all logged commands
cat ~/.local/share/cosy/command-history.jsonl | jq '.'

# Count commands by type
jq -r '.podman_command' ~/.local/share/cosy/command-history.jsonl | sort | uniq -c

# Find all containers created with GPU
jq 'select(.features.gpu == true) | .container_name' ~/.local/share/cosy/command-history.jsonl

# Extract commands for replay
jq -r '"podman " + (.podman_args | join(" "))' ~/.local/share/cosy/command-history.jsonl

# View commands from a specific session
SESSION_ID="abc123..."
jq "select(.session_id == \"$SESSION_ID\")" ~/.local/share/cosy/command-history.jsonl
```

