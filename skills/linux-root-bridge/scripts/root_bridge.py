#!/usr/bin/env python3
"""Antigravity Host Root Bridge for NixOS FHS (buildFHSEnv / bwrap) sandboxes.

Because buildFHSEnv runs inside an unprivileged user namespace (bwrap) with
PR_SET_NO_NEW_PRIVS, setuid binaries like `sudo` or `pkexec` cannot elevate
privileges from inside the agent's terminal.

Usage:
  1. In a host terminal (outside FHS or any user terminal), launch the daemon:
       sudo python3 ~/.gemini/config/plugins/antigravity-skills/skills/linux-root-bridge/scripts/root_bridge.py

  2. From inside Antigravity, execute commands on the real host as root:
       python3 ~/.gemini/config/plugins/antigravity-skills/skills/linux-root-bridge/scripts/root_bridge.py --exec "dmesg | tail -n 20"
       python3 ~/.gemini/config/plugins/antigravity-skills/skills/linux-root-bridge/scripts/root_bridge.py --timeout 120 --exec "smartctl -a /dev/sda"
"""

import argparse
from datetime import datetime
import json
import os
import socket
import subprocess
import sys
import threading


def get_default_sock_path() -> str:
    uid = int(os.environ.get("SUDO_UID", os.getuid()))
    run_user_dir = f"/run/user/{uid}"
    if os.path.isdir(run_user_dir):
        return os.path.join(run_user_dir, "agy-root-bridge.sock")
    home_dir = os.path.expanduser(f"~{os.environ.get('SUDO_USER', '')}")
    return os.path.join(home_dir, ".cache", "agy-root-bridge.sock")


def handle_client(conn: socket.socket) -> None:
    try:
        with conn:
            data = b""
            while True:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                data += chunk
            if not data:
                return

            req = json.loads(data.decode("utf-8"))
            cmd = req.get("cmd", "")
            cwd = req.get("cwd") or None
            timeout = req.get("timeout", 60)

            ts = datetime.now().strftime("%H:%M:%S")
            print(f"\n[{ts}] [EXEC] {cmd}", flush=True)

            try:
                proc = subprocess.run(
                    cmd,
                    shell=True,
                    cwd=cwd,
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                )
                resp = {
                    "returncode": proc.returncode,
                    "stdout": proc.stdout,
                    "stderr": proc.stderr,
                }
                print(f"[{ts}] [DONE] exit={proc.returncode}", flush=True)
            except subprocess.TimeoutExpired as exc:
                resp = {
                    "returncode": 124,
                    "stdout": exc.stdout.decode("utf-8", errors="replace")
                    if isinstance(exc.stdout, bytes)
                    else (exc.stdout or ""),
                    "stderr": f"Command timed out after {timeout}s\n",
                }
                print(f"[{ts}] [TIMEOUT] after {timeout}s", flush=True)
            except Exception as exc:
                resp = {
                    "returncode": -1,
                    "stdout": "",
                    "stderr": f"Bridge execution error: {exc}\n",
                }
                print(f"[{ts}] [ERROR] {exc}", flush=True)

            conn.sendall(json.dumps(resp).encode("utf-8"))
    except Exception as exc:
        print(f"[!] Client handler error: {exc}", file=sys.stderr, flush=True)


def run_server(sock_path: str) -> None:
    if os.geteuid() != 0:
        print("Error: The root bridge server must be started with sudo.", file=sys.stderr)
        sys.exit(1)

    target_uid = int(os.environ.get("SUDO_UID", 1000))
    target_gid = int(os.environ.get("SUDO_GID", 100))

    os.makedirs(os.path.dirname(sock_path), exist_ok=True)
    if os.path.exists(sock_path):
        os.unlink(sock_path)

    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(sock_path)
    os.chown(sock_path, target_uid, target_gid)
    os.chmod(sock_path, 0o600)
    srv.listen(16)

    print(f"[+] Antigravity Root Bridge listening on {sock_path} (uid={target_uid}, mode=0600)")
    print("[+] Waiting for commands from Antigravity (Ctrl+C to stop)...")

    try:
        while True:
            conn, _ = srv.accept()
            t = threading.Thread(target=handle_client, args=(conn,), daemon=True)
            t.start()
    except KeyboardInterrupt:
        print("\n[+] Stopping Antigravity Root Bridge.")
    finally:
        srv.close()
        if os.path.exists(sock_path):
            os.unlink(sock_path)


def run_client(sock_path: str, cmd: str, timeout: int, cwd: str) -> None:
    if not os.path.exists(sock_path):
        print(
            f"Error: Root bridge socket not found at {sock_path}.\n"
            f"Ask the user to start it in a host terminal:\n"
            f"  sudo python3 {os.path.abspath(__file__)}",
            file=sys.stderr,
        )
        sys.exit(127)

    cli = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    cli.connect(sock_path)
    payload = {"cmd": cmd, "timeout": timeout, "cwd": cwd}
    cli.sendall(json.dumps(payload).encode("utf-8"))
    cli.shutdown(socket.SHUT_WR)

    data = b""
    while True:
        chunk = cli.recv(65536)
        if not chunk:
            break
        data += chunk
    cli.close()

    resp = json.loads(data.decode("utf-8"))
    if resp.get("stdout"):
        sys.stdout.write(resp["stdout"])
    if resp.get("stderr"):
        sys.stderr.write(resp["stderr"])
    sys.exit(resp.get("returncode", 1))


def main() -> None:
    parser = argparse.ArgumentParser(description="Antigravity Host Root Bridge")
    parser.add_argument(
        "--socket",
        default=get_default_sock_path(),
        help="Path to the Unix domain socket",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=60,
        help="Command timeout in seconds (default: 60)",
    )
    parser.add_argument(
        "--cwd",
        default=os.getcwd(),
        help="Working directory for the command",
    )
    parser.add_argument(
        "--exec",
        dest="exec_cmd",
        nargs=argparse.REMAINDER,
        help="Execute command string via the running root bridge",
    )

    args = parser.parse_args()
    if args.exec_cmd is not None:
        cmd_str = " ".join(args.exec_cmd).strip()
        if not cmd_str:
            print("Error: --exec requires a command string.", file=sys.stderr)
            sys.exit(2)
        run_client(args.socket, cmd_str, args.timeout, args.cwd)
    else:
        run_server(args.socket)


if __name__ == "__main__":
    main()
