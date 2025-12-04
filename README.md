# cosy

Run GUI applications in isolated Podman containers with persistent homes, display forwarding, and opt-in hardware support.

Like a tea cosy keeps your tea warm and contained, cosy wraps your GUI applications in secure, insulated containers. 🫖

---
Cosy is inspired by distrobox, flatpak, and Steam. I leaned heavily on Claude Code, as hardcore bash scripting is not in my wheelhouse, but this way nobody has to install a whole programming language and environment. 

Cosy is an opinion for using podman expressed as a shell script. It makes the things I wanted to manage more simple. Specifically, I wanted to sandbox MCP development tools and IDEs without sharing my home directory and risking data exfiltration. And I wouldn't clutter up my system with various programming packages and modules. 

---

Cosy is intended to be used with rootless podman.
There's a few things that I find notable beyond basic management of podman features:
 1. Re-creating containers with different privileges, while keeping your changes. By default, cosy preserves the home directory from a container. This allows you to destroy and re-create the container with different mounts or features. Additionally, if re-creating from the same base image, it can transfer the writable layer to the new, differently-privileged container, so you don't have to reinstall your packages. See [EXAMPLES.md](docs/EXAMPLES.md#using-cosy-recreate)
 2. Rootless network traffic inspection and manipulation. `cosy network` will allow you to run tools like `tcpdump` and `iptables` in the container's networking namespace on the host without root. See [NETWORK.md](docs/NETWORK.md#common-workflows)

Cosy is designed primarily for a **Fedora** host and makes assumptions based on Fedora defaults (e.g., PipeWire audio). Some automatic detection features may not work optimally (or at all!) on other distributions.

---

## Features

- 🏠 **Isolated home directories** - Each container gets its own home in a configurable location `~/.local/share/cosy/`
- 👤 **Runs as your user** - User namespaces with matching UID/GID for proper file ownership
- 🖥️ **Full display support** - Automatic X11 and Wayland detection and forwarding
- 🔊 **Optional audio support** - PipeWire and PulseAudio compatibility (use `--audio` flag)
- ⚡ **Optional hardware acceleration** - GPU access via `/dev/dri` (use `--gpu` flag)
- 🎮 **Optional input device access** - Access to /dev/input, /dev/uinput, /dev/hidraw* (use `--input` flag)
- 💾 **Persistent containers** - Your container's home directory is preserved, with your permissions
- 📁 **Flexible mounting** - Pass-through to podman's mounting
- 🔌 **Full access to podman's capabilities** - Cosy passes-through flags it doesn't use to podman, while warning in case of conflicts with cosy functionality
- 🚀 **Desktop integration** - Create and manage application launchers that run seamlessly from your desktop environment
- 🔒 **Security-first design** - Explicit opt-in for audio, GPU, and filesystem access; rootless Podman with isolated network namespace by default
- 🌐 **Network control and debugging** - Choose between isolated (default), none, or host networking; capture and manipulate container networking 
- 🐳 **Sibling container support** - Optional Podman socket access (`--podman`) for dev containers and similar workflows


## Installation

### Basic Installation

```bash
mkdir -p ~/.local/bin
curl -o ~/.local/bin/cosy https://raw.githubusercontent.com/BenSmith/cosy/main/cosy
chmod +x ~/.local/bin/cosy
```

## Quick Start

```bash
# Install cosy as above

# Create and setup a container (Fedora 42 default)
cosy run --root --gpu imagery -- dnf install -y gimp inkscape

# Run the application
cosy run imagery gimp
```

### Shell Completion (Optional)

Enable tab completion for bash or zsh:

**Bash:**
```bash
source $(cosy completion bash)

# Or system-wide (requires sudo)
sudo cosy completion bash > /etc/bash_completion.d/cosy
```

## Security Model

Cosy follows the principle of **least privilege** and **explicit opt-in**:

- **Rootless containers** - Runs entirely without root privileges
- **Minimal capabilities** - Base containers get only 5 capabilities (CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID)
- **Isolated network** - Separate network namespace by default
- **Isolated home** - Each container has its own home directory in `~/.local/share/cosy/`
- **Explicit opt-in** - Features like audio, GPU, and D-Bus require explicit flags
- **No extra capabilities for GUI** - Audio, GPU, and D-Bus require no additional capabilities

Cosy automatically manages Linux capabilities based on features (systemd adds 6 more, custom networks add NET_ADMIN/NET_RAW). You can override with `--cap-add` and `--cap-drop` for full control.

**Additional security:**
- User namespaces for UID/GID isolation
- SELinux support (uses `container_t` by default)
- Custom seccomp profiles via `--security-opt seccomp=<profile>`

For detailed capability breakdown, see [OPTIONS.md](docs/OPTIONS.md#security).

## Basic Usage

### Container Lifecycle

```bash
# Create container (doesn't enter)
cosy create --gpu --audio --input mycontainer

# Open root shell for setup
cosy run --root mycontainer -- dnf install -y firefox 

# Run application as user
cosy run myapp firefox

# Create desktop launcher
cosy desktop create myapp --name "Firefox" --icon firefox -- firefox

# List all containers
cosy ls

# Enter interactive shell as user
cosy enter myapp

# Stop running container
cosy stop myapp

# Remove container (preserves home directory)
cosy rm myapp

# Remove container and home directory
cosy rm --home myapp
```

### Common Patterns


##### **Container with mounted directories:**
Uses Podman/Docker syntax (a passthrough, really)
```bash
cosy run -v ~/Videos:/videos:ro vlc vlc /videos/movie.mp4
```

**Network isolation:**
```bash
# No network access
cosy run --network none untrusted-app app

# Host networking (less isolated)
cosy run --network host dev-tool tool
```

**Using command flags:**
```bash
# Use -- to separate cosy options from command options
cosy run myapp -- grep -r "pattern" /path
cosy run --root myapp -- dnf install -y vim htop
```

## Commands and Options

**Common commands:**
- `create`, `run`, `enter` - Create and use containers
- `ls`, `inspect` - View container info
- `recreate`, `clone` - Modify containers while preserving data
- `desktop` - Manage application launchers
- `network` - Debug and control networking
- `rm`, `stop` - Clean up

**Common options:**
- `--gpu`, `--audio`, `--input` - Hardware access
- `--dbus`, `--dbus-system` - Desktop integration
- `--network <mode>` - Network isolation (default, none, host)
- `-v <src>:<dst>` - Mount directories
- `--systemd` - Run systemd as PID 1

For complete reference, see [OPTIONS.md](docs/OPTIONS.md).

### Systemd Support

Cosy can run systemd as PID 1 for managing services. Build an image with systemd, then use `--systemd=always` or meet the criteria for podman's systemd support:

```bash
cosy create --image localhost/fedora-systemd:43 --systemd=always myapp
```

See [EXAMPLES.md](docs/EXAMPLES.md#running-systemd-services) for creating systemd images and managing services.

## Documentation

- **[OPTIONS.md](docs/OPTIONS.md)** - Complete reference for all options, flags, and environment variables
- **[EXAMPLES.md](docs/EXAMPLES.md)** - Detailed examples for common use cases
- **[NETWORK.md](docs/NETWORK.md)** - Network inspection and control tools
- **[test/README.md](test/README.md)** - Testing documentation

**Configuration:**
- [Environment variables](docs/OPTIONS.md#environment-variables)
- [Network modes](docs/OPTIONS.md#network)

## Examples and Security Profiles

For reference examples of seccomp profiles, SELinux policies, and containerfiles, see the separate [cosy-sampler](https://github.com/BenSmith/cosy-sampler) repository.

## Requirements

- **Podman** (rootless mode)
- **Linux** with X11 or Wayland
- **Bash** 4.3 or later


Install on Fedora:
```bash
sudo dnf install podman
```

## Development Tools
- **bats** shell test runner
- **just** command runner

- Install on Fedora:
```bash
sudo dnf install bats just
```


For troubleshooting tips, see [docs/EXAMPLES.md](docs/EXAMPLES.md#troubleshooting). For file locations, see [docs/OPTIONS.md](docs/OPTIONS.md#default-file-locations).

## License

MIT License - see [LICENSE](LICENSE) file for details.

**Disclaimer**: This software is provided "as is", without warranty of any kind, express or implied. See the LICENSE file for full details.
