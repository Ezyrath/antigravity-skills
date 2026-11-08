---
name: linux-root-bridge
description: >-
  Host root command bridge for executing privileged (sudo/root) Linux & NixOS operations,
  hardware diagnostics, block device / USB / SCSI pass-through, and system administration
  when Antigravity runs inside a sandboxed FHS user namespace (buildFHSEnv / bwrap).
---

# Linux & NixOS Host Root Bridge (`root_bridge.py`)

When Antigravity runs inside a NixOS `buildFHSEnv` (`bwrap`) or unprivileged user namespace, the kernel sets `PR_SET_NO_NEW_PRIVS` and maps unprivileged device nodes to `nobody:nogroup`. Consequently, running `sudo`, `pkexec`, or `su` directly inside Antigravity's subshell fails, and raw device nodes (`/dev/sdX`, `/dev/nvme*`, `/dev/bsg/*`, `/dev/bus/usb/*`) or `dmesg` buffers are inaccessible.

This skill provides a transparent, audit-logged Unix Domain Socket bridge (`scripts/root_bridge.py`) so the user can grant temporary root execution on the real host while seeing every executed command in real time in their terminal.

---

## 1. Quick Start Workflow

### Step 1: Ask the User to Start the Bridge Server on the Host
Instruct the user to run the following command in any standard host terminal:

```bash
sudo python3 ~/.gemini/config/plugins/antigravity-skills/skills/linux-root-bridge/scripts/root_bridge.py
```

What the server does:
- Binds a Unix domain socket at `/run/user/<uid>/agy-root-bridge.sock` (fallback: `~/.cache/agy-root-bridge.sock`).
- Restricts socket ownership and permissions to `0600` (`<user>:users`) so only the local user's processes can connect.
- Spawns a daemon thread per request so slow or blocking commands never lock up the socket.
- Logs every command (`[HH:MM:SS] [EXEC] ...`) and its exit code directly in the user's terminal.

### Step 2: Execute Commands from Antigravity
Once the user confirms the bridge is running, invoke commands using `--exec`:

```bash
python3 ~/.gemini/config/plugins/antigravity-skills/skills/linux-root-bridge/scripts/root_bridge.py --exec "dmesg | tail -n 30"
```

### Custom Timeout & Working Directory
For long-running commands (`ddrescue`, `nixos-rebuild`, `smartctl` extended tests), pass `--timeout <seconds>`:

```bash
python3 ~/.gemini/config/plugins/antigravity-skills/skills/linux-root-bridge/scripts/root_bridge.py --timeout 300 --exec "smartctl -a /dev/sda"
```

---

## 2. Safety & Best Practices

1. **Read-Only First for Hardware Diagnostics**:
   - When inspecting damaged disks, USB flash drives (e.g., controllers in ROM mode like `ffff:1201`), or filesystems, always open devices with `O_RDONLY | O_NONBLOCK` and use read-only SCSI (`SG_DXFER_FROM_DEV` / `SG_DXFER_NONE`) or `smartctl` commands.
2. **Avoid Self-Matching `pkill`**:
   - When killing background child processes over the bridge, avoid `pkill -f <pattern>` if `<pattern>` appears in the shell command string itself, or use the `[p]attern` character-class trick (`pkill -f '[m]y_script.py'`).
3. **Teardown**:
   - Remind the user to press `Ctrl+C` in their host terminal once privileged operations are complete; the bridge automatically unlinks `/run/user/<uid>/agy-root-bridge.sock` on exit.
