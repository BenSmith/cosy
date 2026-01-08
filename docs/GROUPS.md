# Group Management in Cosy Containers

## Overview

Cosy automatically manages supplementary group membership to enable device access (GPU, input devices, etc.) in rootless containers. This document explains how group preservation works and why you might see groups displayed as "nobody" even though permissions work correctly.

## The Complete Picture

### 1. Host Side: Your Group Membership

On your host system, you have supplementary groups:
```bash
$ id
uid=1000(ben) gid=1000(ben) groups=1000(ben),10(wheel),39(video),104(input),105(render),...
```

These are the groups you actually belong to on the host.

### 2. Container Launch: `--group-add keep-groups`

When cosy creates a container, it uses:
```bash
podman create \
    --uidmap "+$HOST_UID:@$HOST_UID:1" \
    --gidmap "+$HOST_GID:@$HOST_GID:1" \
    --group-add keep-groups \
    ...
```

**What `keep-groups` does:**
- Prevents the `setgroups()` syscall during container startup
- The container process **inherits** your supplementary groups (10, 39, 104, 105, etc.)
- Those **actual GID values** are preserved in the process credentials

### 3. Inside the Container: What You See

When you run `id` inside the container:
```bash
$ id
uid=1000(user) gid=1000(user) groups=1000(user),65534(nobody)
```

**Why "nobody" (65534)?**
- The supplementary GIDs (10, 39, 104, 105) are NOT mapped in the user namespace
- The `id` command can't resolve GID → name, so it shows "nobody" (the overflow GID)
- But the **kernel still has the real GID values** in your process credentials

### 4. Kernel Permission Checks: The Magic

When you access a device like `/dev/dri/card1` (owned by GID 39/video):
```bash
$ ls -l /dev/dri/card1
crw-rw----+ 1 nobody nobody 226, 1 ...   # Shows as "nobody" due to unmapped GID

$ test -r /dev/dri/card1 && echo "readable"
readable  # ✅ Works!

$ test -w /dev/dri/card1 && echo "writable" || echo "not writable"
writable
```

**How it works:**
- Kernel checks: "Does process have GID 39 in its credentials?"
- Answer: YES (from `keep-groups`)
- Kernel grants access, even though userspace tools show "nobody"

**The key insight:** The kernel performs permission checks using the **real numeric GID values** in the process credentials, not the names that userspace tools display.

### 5. Cosmetic Group Creation (Default Behavior)

To improve user experience, cosy automatically creates groups in the container that match your host GIDs.

**When `--gpu` is used:**
1. Cosy detects host's video/render GIDs:
   ```bash
   HOST_VIDEO_GID=39
   HOST_RENDER_GID=105
   ```

2. Bootstrap script creates groups (if they don't conflict):
   ```bash
   if ! getent group 39 && ! getent group video; then
       groupadd -g 39 video
   fi
   ```

**Result with cosmetic groups:**
```bash
$ id
uid=1000(ben) gid=1000(ben) groups=1000(ben),39(video),104(input),105(render)
#                                            ^^^ Now shows real names!

$ ls -l /dev/dri/card1
crw-rw----+ 1 nobody video 226, 1 ...   # "video" name shows up
```

### 6. Disabling Cosmetic Groups: `--no-create-groups`

You can disable cosmetic group creation:
```bash
$ cosy create mycontainer --gpu --no-create-groups
```

**Result:**
```bash
$ id  # Inside container
groups=1000(ben),65534(nobody),65534(nobody)  # Shows "nobody" again
```

**Important:** Permissions still work! The kernel still has the real GIDs in process credentials.

**When to use `--no-create-groups`:**
- Read-only container filesystems
- You prefer explicit "nobody" display to indicate unmapped groups
- Avoiding modifications to `/etc/group` in the container

---

## Two-Layer Architecture

| Layer | What Happens | Where | Can Disable? |
|-------|-------------|-------|--------------|
| **Kernel (permissions)** | Real GID values (39, 104, 105) preserved via `--group-add keep-groups` | Process credentials | No (required for device access) |
| **Userspace (display)** | Groups created in `/etc/group` for name resolution | Bootstrap script | Yes (`--no-create-groups`) |

- Permissions work at the **kernel level** (`keep-groups`)
- Group names are **cosmetic only** (bootstrap script)
- Disabling cosmetic creation doesn't affect permissions

---

## Conflict Handling

**Scenario:** Host has `video=39`, but container image already has `video=44`

The bootstrap script checks BOTH the GID and group name:
```bash
if ! getent group 39 && ! getent group video; then
    groupadd -g 39 video
fi
```

- GID 39 doesn't exist: ✓
- "video" name doesn't exist: ✗ (exists at GID 44)
- **Result:** Skip creation, keep container's existing `video:x:44`

Your host GID 39 will show as "nobody" in the container, but **permissions still work** because the kernel has GID 39 in your credentials.

**This is safe behavior:** We never overwrite existing groups or create GID conflicts.

---

## Troubleshooting

### "I see 'nobody' but can't access devices"

**Check if you're in the right groups on the host:**
```bash
# On host
$ id
# Should show video, render, input groups
```

If you're not in the groups:
```bash
# Add yourself to the groups
sudo usermod -a -G video,render,input $USER

# Log out and log back in for changes to take effect
```

### "Groups show as nobody even with default settings"

This is expected if:
1. The container image already has those group names at different GIDs (conflict avoidance)
2. The container filesystem is read-only (group creation fails silently)

**Permissions still work!** The "nobody" display is cosmetic.

### "Verifying that groups are actually preserved"

```bash
# Inside container, check process credentials
$ cat /proc/self/status | grep Groups
Groups: 1000 10 39 104 105

# The real GID values are there, even if they show as "nobody" in `id`
```

---

## Technical Details

### Why Not Map GIDs in User Namespace?

In rootless podman, you can only map GIDs that are:
- Your primary GID
- Within your delegated subgid range (typically 524288-589823)

Host supplementary groups (video=39, render=105, input=104) are **outside** this range and can't be mapped without system configuration changes (modifying `/etc/subgid`).

The `--group-add keep-groups` workaround preserves the groups without requiring namespace mapping.

### Why This Approach Works

The Linux kernel checks group membership in two places:
1. **Process credentials** - The actual GID list maintained by the kernel
2. **User namespace mapping** - Translation for userspace tools

Device access uses **process credentials** (layer 1), which `keep-groups` preserves. The namespace mapping (layer 2) only affects what userspace tools display.

---

## Related Flags

- `--gpu` - Automatically sets up video/render groups
- `--input` - Automatically sets up input group
- `--no-create-groups` - Disable cosmetic group creation
- `--sudo` - Enable passwordless sudo (separate from group management)

## See Also

- [OPTIONS.md](OPTIONS.md) - Complete flag reference
- [EXAMPLES.md](EXAMPLES.md) - Usage examples
- [Red Hat Blog: Sharing supplemental groups with Podman containers](https://www.redhat.com/en/blog/supplemental-groups-podman-containers)
