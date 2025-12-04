# Network Management

The `cosy network` subcommand provides tools for inspecting and controlling container networking. These are opt-in utilities for when you need to debug, monitor, or control network behavior.

## Philosophy

- **No logging by default** - Containers run normally with no monitoring overhead
- **Opt-in tools** - Users explicitly choose when to use network features
- **Flexibility** - Multiple approaches for different use cases

## Requirements

### Host Requirements

All network monitoring and control commands use host-side tools that enter the container's network namespace using `nsenter`. This provides several benefits:

**Benefits:**
- No need to install tools inside containers
- Container code cannot interfere with monitoring/shaping
- Uses trusted host binaries instead of container binaries
- More secure for untrusted containers

**Required host packages:**
- `util-linux` (provides `nsenter`)
- `iproute` or `iproute-tc` (provides `ip`, `ss`, `tc`)
- `tcpdump` (for packet capture)

**Install on host:**
```bash
# Install all required tools
sudo dnf install -y util-linux iproute iproute-tc tcpdump
```

**How it works:**
Network commands use `podman unshare` with `nsenter` to enter the container's network namespace from the host. This works in rootless mode without requiring sudo, allowing you to run commands in the container's network context without executing code inside the container.

### Command-Specific Requirements

- **All commands:** Podman installed and configured, container must exist
- **Inspection commands** (inspect, stats, connections, watch): Container must be running, host needs `ss` and `nsenter`
- **Control commands** (disconnect/reconnect): Container must be running, host needs `ip` and `nsenter`
- **Traffic shaping** (throttle/delay/loss/reset): Container must be running, host needs `tc` and `nsenter`
- **Capture**: Container must be running, host needs `tcpdump` and `nsenter`
- **Bridge networks**: Network must exist (created with `podman network create`)

## Commands

### Inspection Commands

#### `cosy network inspect <container>`

Show comprehensive network configuration and statistics for a running container.

**Output includes:**
- Network mode (pasta, host, none, bridge)
- IP address and gateway
- DNS servers
- Active connection count
- Total bandwidth (received/transmitted)

**Example:**
```bash
$ cosy network inspect myapp

Container: myapp
============================================

Network Mode: pasta
IP Address: 10.88.0.2
Gateway: 10.88.0.1
DNS Servers: 192.168.1.1

Active Connections: 3
Total Bandwidth: 1.2 MiB received, 512 KiB transmitted
```

#### `cosy network stats <container>`

Display detailed bandwidth statistics per interface.

**Output includes:**
- Interface name
- Bytes received/transmitted (human-readable)
- Packets received/transmitted

**Example:**
```bash
$ cosy network stats myapp

Network Statistics: browser
============================================
Interface         RX Bytes         TX Bytes   RX Packets   TX Packets
--------------------------------------------------------------------
eth0               2.1MiB           512KiB         1543          892
```

#### `cosy network connections <container>`

List all active network connections in a container.

**Shows:**
- Protocol (TCP/UDP)
- Local address and port
- Remote address and port
- Connection state
- Process name/PID

**Example:**
```bash
$ cosy network connections myapp

Active Connections: myapp
============================================

Netid  State   Recv-Q Send-Q Local Address:Port   Peer Address:Port
tcp    ESTAB   0      0      10.88.0.2:54321      93.184.216.34:443
tcp    ESTAB   0      0      10.88.0.2:54322      151.101.1.69:443
```

#### `cosy network list`

List all Podman networks that have cosy containers connected.

**Shows:**
- Network name
- Subnet
- Connected cosy containers

**Example:**
```bash
$ cosy network list

=== Podman Networks ===

Network: podman
  Subnet: 10.88.0.0/16
  Cosy Containers: myapp browser photo-editor

Network: dev-network
  Subnet: 172.30.0.0/24
  Cosy Containers: frontend backend
```

#### `cosy network watch <container>`

Monitor new network connections in real-time. Displays a live feed showing each new connection as it's established.

**Output format:**
```
[HH:MM:SS] PROTO LOCAL_ADDR:PORT -> REMOTE_ADDR:PORT (STATE)
```

**Example:**
```bash
$ cosy network watch myapp

Watching connections for container: myapp
Press Ctrl+C to stop

[14:23:45] tcp 10.88.0.2:54321 -> 93.184.216.34:443 (ESTAB)
[14:23:46] tcp 10.88.0.2:54322 -> 151.101.1.67:80 (ESTAB)
[14:23:47] udp 10.88.0.2:53841 -> 8.8.8.8:53 (UNCONN)
```

**Use cases:**
- Debug application connectivity issues
- Monitor API calls being made
- Identify unexpected network activity
- Watch connection patterns in real-time

**Notes:**
- Container must be running
- Shows only NEW connections (not existing ones)
- Poll interval: 1 second
- Press Ctrl+C to stop

### Control Commands

#### `cosy network disconnect <container>`

Disable all networking for a running container by bringing down all non-loopback interfaces.

**Use cases:**
- Test application offline behavior
- Simulate network failures
- Temporarily isolate an application

**Example:**
```bash
$ cosy network disconnect untrusted-app

Disconnecting network for container: untrusted-app
  Bringing down interface: eth0
Network disconnected successfully
```

**Notes:**
- Container must be running
- Requires `ip` command in container
- Does not persist across container restarts
- Does not affect loopback interface (localhost)

#### `cosy network reconnect <container>`

Re-enable networking for a container by bringing up all non-loopback interfaces.

**Example:**
```bash
$ cosy network reconnect untrusted-app

Reconnecting network for container: untrusted-app
  Bringing up interface: eth0
Network reconnected successfully
```

### Traffic Shaping Commands

Traffic shaping allows you to simulate network conditions for testing.

#### `cosy network throttle <container> <bandwidth> [--persist]`

Limit bandwidth for a container.

**Bandwidth formats:** `1mbit`, `512kbit`, `100kbps`, etc.

**Example:**
```bash
$ cosy network throttle myapp 1mbit

Applying bandwidth limit: 1mbit to container: myapp
  Configuring interface: eth0
Bandwidth limit applied (temporary - will reset on container restart)
```

**With persistence:**
```bash
$ cosy network throttle streaming-app 512kbit --persist

Applying bandwidth limit: 512kbit to container: streaming-app
  Configuring interface: eth0
Bandwidth limit saved and will persist across container restarts
Bandwidth limit configured successfully
```

**Notes:**
- Container must be running
- Requires `tc` command on host (install with `sudo dnf install -y iproute-tc`)
- Without `--persist`: Temporary, removed on container restart
- With `--persist`: Saved to config, reapplied on container start

#### `cosy network delay <container> <milliseconds> [--persist]`

Add latency to simulate network delay.

**Delay formats:** `100ms`, `1s`, etc.

**Example:**
```bash
$ cosy network delay myapp 200ms --persist

Adding network delay: 200ms to container: myapp
  Configuring interface: eth0
Network delay saved and will persist across container restarts
Network delay configured successfully
```

**Use cases:**
- Test application behavior with high latency
- Simulate mobile or satellite connections
- Debug timeout handling

#### `cosy network loss <container> <percentage> [--persist]`

Simulate packet loss.

**Loss formats:** `5%`, `10%`, `2.5%`, etc.

**Example:**
```bash
$ cosy network loss myapp 5% --persist

Simulating packet loss: 5% to container: myapp
  Configuring interface: eth0
Packet loss simulation saved and will persist across container restarts
Packet loss simulation configured successfully
```

**Use cases:**
- Test application resilience
- Simulate unreliable networks
- Debug retry logic

#### `cosy network reset <container>`

Remove all traffic shaping (throttle, delay, loss) from a container.

**Example:**
```bash
$ cosy network reset myapp

Resetting traffic shaping for container: myapp
  Resetting interface: eth0
Cleared persisted traffic shaping settings
Traffic shaping reset successfully
```

**Notes:**
- Removes all `tc` rules from interfaces
- Clears persisted settings from `.cosy-network-config`
- Does not affect other network settings

### Advanced Commands

#### `cosy network capture <container> [output-file]`

Capture all network traffic from a container to a pcap file for analysis with Wireshark or other tools.

**Example:**
```bash
$ cosy network capture browser /tmp/traffic.pcap

Starting packet capture for container: browser
Output file: /tmp/traffic.pcap
Press Ctrl+C to stop capture

^C
Capture stopped
Packets saved to: /tmp/traffic.pcap
```

**Analyze with Wireshark:**
```bash
wireshark /tmp/traffic.pcap
```

**Or use tcpdump to view:**
```bash
tcpdump -r /tmp/traffic.pcap -n
```

**Use cases:**
- Deep packet inspection
- Troubleshoot protocol-level issues
- Analyze application network behavior
- Capture traffic for security analysis

**Notes:**
- Container must be running
- Captures ALL traffic on all interfaces (not just external)
- Output file defaults to `/tmp/<container>-<timestamp>.pcap`
- Press Ctrl+C to stop capture
- pcap files can grow large - monitor disk space
- Standard pcap format compatible with Wireshark, tshark, etc.

**Filtering with tcpdump:**
The `capture` command uses the host's tcpdump, which supports standard BPF filters. See `man tcpdump` for filter syntax.

## Network Modes

Cosy containers can use different network modes, configured at creation time. Understanding these modes helps you choose the right networking approach for your use case.

### Default (Pasta)
```bash
cosy run myapp command
```
**What it provides:**
- User-mode networking (no kernel privileges needed)
- Zero configuration - works out of the box
- Automatic port forwarding
- Isolated network namespace with NAT for outbound connections
- Default DNS resolution from host

**Best for:** Single containers that need internet access but don't need to talk to other containers

**Limitations:** Cannot connect to other containers or use `podman network connect`

### Host Network
```bash
cosy run --network host myapp command
```
- Shares host network stack
- Full network access
- No isolation

### No Network
```bash
cosy run --network none myapp command
```
- No network connectivity
- Only loopback interface
- Maximum isolation

### Bridge Network

**What it provides:**
- Container-to-container communication on the same bridge
- DNS resolution between containers (access by container name)
- Custom subnets and network isolation
- Traditional Linux bridge with veth pairs

**Best for:** Multi-container applications (frontend + backend + database, microservices, etc.)

## Bridge Networking

Bridge networking enables container-to-container communication, which is essential for multi-container applications. In rootless Podman, you must specify the bridge network at container creation time.

### The Pasta Limitation

⚠️ **Bridge networks do NOT work with cosy's default containers in rootless Podman.**

Cosy's default networking uses pasta (user-mode NAT). To use bridge networking, you must:
1. Create a bridge network first with `podman network create`
2. Specify that network when creating containers with `--network <bridge-name>`

You cannot use pasta's default networking and bridge networks together, and you cannot change network modes after creation.

### How to Use Bridge Networks

Specify the bridge network at container creation time:

```bash
# 1. Create a bridge network
podman network create my-bridge

# 2. Create containers on that network
cosy create --network my-bridge frontend
cosy create --network my-bridge backend
```

This uses CNI/netavark to create actual kernel bridge devices and connect containers to them.

### Creating Bridge Networks

```bash
# Create a custom network
podman network create dev-network --subnet 172.30.0.0/24

# Common options:
# --subnet <cidr>    Specify subnet (e.g., 172.30.0.0/24)
# --gateway <ip>     Specify gateway address
# --internal         Restrict external access
# --dns <server>     Custom DNS servers
# --ipv6             Enable IPv6
```

### Verifying Network Connections

```bash
# Check what network a container is using
podman inspect frontend --format '{{.HostConfig.NetworkMode}}'

# See detailed network info
podman inspect frontend | grep -A5 Networks

# List which cosy containers are on which networks
cosy network list
```

**Note:** `podman network connect` and `podman network disconnect` do NOT work in rootless Podman. You must specify the network at container creation time with `cosy create --network <bridge-name>`.

### Removing Networks

```bash
# Remove a network (all containers must be disconnected first)
podman network rm dev-network

# List all networks
podman network ls

# See which cosy containers are on which networks
cosy network list
```

### Complete Multi-Container Example

```bash
# 1. Create a custom network
podman network create dev-network --subnet 172.30.0.0/24

# 2. Create containers on that network
cosy create --network dev-network frontend
cosy create --network dev-network backend
cosy create --network dev-network database

# 3. Containers can now communicate by name
cosy run frontend curl http://backend:8080/api
cosy run backend psql -h database -U postgres

# 4. View network topology
cosy network list
```

## Common Workflows

### Quick Network Check

Check what a container is doing on the network:

```bash
# Get overview
cosy network inspect photo-editor

# Check active connections
cosy network connections photo-editor
```

### Test Offline Behavior

Test how your application behaves when network connectivity is lost:

```bash
# Start app
cosy run myapp firefox &

# Wait for app to fully load
sleep 5

# Kill networking
cosy network disconnect myapp

# Observe app behavior:
# - Does it show offline indicator?
# - Does it crash or hang?
# - Are cached resources still accessible?
# - Does it queue requests?

# Restore networking
cosy network reconnect myapp

# Observe reconnection:
# - Does it reconnect automatically?
# - Does it retry queued requests?
# - Need manual refresh?
```

### Debug Connection Issues

Monitor new connections as they happen:

```bash
# Start watching connections
cosy network watch browser

# In another terminal, use the app
cosy run browser firefox

# You'll see each connection as it's made:
# [14:23:45] tcp 10.88.0.2:54321 -> 93.184.216.34:443 (ESTAB)
# [14:23:46] tcp 10.88.0.2:54322 -> 151.101.1.67:80 (ESTAB)

# Identify:
# - What domains is it connecting to?
# - Are there unexpected connections?
# - Is it making too many connections?
```

### Capture Network Traffic

Deep analysis with packet capture:

```bash
# Start capture
cosy network capture myapp /tmp/myapp-traffic.pcap

# Use the application to reproduce the issue
# Press Ctrl+C when done

# Analyze with Wireshark
wireshark /tmp/myapp-traffic.pcap

# Or examine with tcpdump
tcpdump -r /tmp/myapp-traffic.pcap -n | less

# Filter for specific traffic
tcpdump -r /tmp/myapp-traffic.pcap -n 'port 443' | less
```

Since the network namespace is owned by your user, you do not need root permissions to eavesdrop on the container's traffic.

### Bandwidth Monitoring

Track bandwidth usage over time:

```bash
# Check current bandwidth
cosy network stats streaming-app

# Monitor changes
watch -n 5 cosy network stats streaming-app
```

### Find All Container Networks

See which networks your cosy containers are using:

```bash
cosy network list
```

### Test App Under Poor Network Conditions

Simulate slow or unreliable network for testing:

```bash
# Simulate slow mobile connection
cosy network throttle streaming-app 512kbit --persist
cosy network delay streaming-app 100ms --persist
cosy network loss streaming-app 2% --persist

# Run the app
cosy run streaming-app vlc

# App behavior is tested under constrained network
# Settings persist across restarts

# Reset when done
cosy network reset streaming-app
```

## See Also

- [OPTIONS.md](OPTIONS.md) - Network options for container creation
- [EXAMPLES.md](EXAMPLES.md) - Example workflows
