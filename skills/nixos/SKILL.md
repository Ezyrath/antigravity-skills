---
name: nixos
description: >-
  Declarative NixOS & Home Manager configuration workflows, post-update regression forensics
  (journalctl + nix store diff-closures), FHS sandbox (bwrap) flake evaluation, Cachix binary
  cache preservation, CI linting (Alejandra, Statix, Deadnix, CSpell/MegaLinter), and AM5
  dual-GPU desktop power-management runbooks.
---

# NixOS Configuration, Diagnostics & Flake Workflows

This skill provides operational procedures, validation pipelines, and hardware troubleshooting runbooks for declarative **NixOS** and **Home Manager** repositories.

---

## 1. Post-Update Regression Forensics (`journalctl` + `nix store diff-closures`)

When diagnosing a system or desktop regression after a `nixos-rebuild` / `flake update`:

1. **Map Recent Boots & Generations**:
   - List boots: `journalctl --list-boots | tail -n 15`
   - Extract the booted kernel and `/nix/store/<hash>-nixos-system-...` path per boot:
     ```bash
     for b in -3 -2 -1 0; do
       echo "=== BOOT $b ==="
       journalctl -b "$b" -k --no-pager | head -n 2
     done
     ```
   - Distinguish power outages / hard resets from clean reboots by checking `journalctl -b "$b" --grep="corrupted|uncleanly"`.
2. **Diff Exact Package Closures**:
   - Compare the last known-good system closure against `/run/current-system` to pinpoint every kernel, firmware, Mesa, compositor, or daemon version bump:
     ```bash
     nix store diff-closures /nix/store/<working-nixos-system> /run/current-system
     ```
3. **Correlate Subsystem Logs**:
   - Inspect kernel DRM/GPU events (`journalctl -b -1 -k`), Wayland compositor (`-t kwin_wayland`), and display power management (`-t org_kde_powerdevil`) around screen lock, DPMS, or suspend timestamps.

---

## 2. Evaluating NixOS Flakes Inside the FHS Sandbox (`bwrap`)

Inside Antigravity's `buildFHSEnv` (`bwrap`), host-only paths such as `/etc/nixos/facter.json`, SOPS secret files (`/etc/nixos/secrets/*.yaml`), or initrd SSH host keys are not visible under `/etc`.

Evaluate full `nixosConfigurations.<host>` closures (and optionally pass `--option abort-on-warn true` to trace evaluation warnings) without touching tracked files by overriding impure paths via `extendModules`:

```bash
nix eval --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    sys = f.nixosConfigurations.<host>.extendModules {
      modules = [ ({ lib, ... }: {
        facter.reportPath = lib.mkForce null;
        sops.defaultSopsFile = lib.mkForce ./flake.nix;
        boot.initrd.network.ssh.hostKeys = lib.mkForce [ ./flake.nix ];
      }) ];
    };
  in sys.config.system.build.toplevel.drvPath'
```

For privileged host operations (`nixos-rebuild switch`, `dmesg`, sysfs writes), pair with the `linux-root-bridge` skill or provide the exact host terminal command.

---

## 3. Pre-Commit & CI Validation Pipeline

Before committing changes to any NixOS repository, run the full linter suite:

1. **Formatting (`alejandra`)**:
   ```bash
   nix run nixpkgs#alejandra -- --check .
   ```
2. **Static Analysis (`statix` & `deadnix`)**:
   ```bash
   nix run nixpkgs#statix -- check .
   nix run nixpkgs#deadnix -- --fail .
   ```
3. **Flake Metadata Check**:
   ```bash
   nix flake metadata --no-write-lock-file
   ```
4. **Spellcheck (`cspell` / MegaLinter)**:
   - When `.cspell.json` is present, validate across all Nix, Markdown, and JSON files (MegaLinter often runs with `VALIDATE_ALL_CODEBASE=true` on pushes to `main`):
     ```bash
     nix run nixpkgs#cspell -- --config .cspell.json "**/*.nix" "*.md" "*.json"
     ```
   - Keep custom technical terms in `.cspell.json` sorted alphabetically.

---

## 4. Binary Cache Preservation & Upstream Flake Warnings

1. **Verify `.outPath` Equality When Refactoring Overlays**:
   - Before replacing how third-party flake packages (e.g. `nix-citizen`, `nix-gaming`) are wired into `nixpkgs.overlays`, compare `.outPath` before and after via `nix eval` to ensure Cachix binary cache hits are preserved bit-for-bit and heavy packages (`wine`, launchers) are not rebuilt from source.
2. **Avoid Local Monkey-Patches for Upstream Flake Warnings**:
   - When a non-blocking evaluation warning (e.g. `pkgsCross` alias deprecations marked `TODO` for a future release) originates inside an external flake input rather than the repository's own Nix expressions, do **not** add local overlay shims just to hide the warning when automated `flake update` CI is active. Point out the upstream origin and let upstream fix it cleanly unless the user explicitly asks for a local workaround.

---

## 5. AM5 Desktop Dual-GPU Quirks (Ryzen iGPU + Discrete Radeon)

On AM5 desktops (Ryzen 7000/9000 series) where the integrated 2-CU RDNA 2 GPU remains enabled alongside a discrete Radeon GPU (`amdgpu`) driving a **DisplayPort** monitor:

- **Root Cause (`BACO` Runtime PM)**: Seeing two GPUs, `amdgpu` (`runpm=-1` `auto`) treats the desktop dGPU like a hybrid PowerXpress laptop GPU (`Using BACO for runtime pm`). When a DisplayPort monitor is powered off and drops its HPD line (`0` connected outputs), KWin/Wayland releases the dGPU (`runtime_usage = 0`) and `amdgpu` powers off the ASIC in **BACO** after 5 seconds. Cold-resuming `PSP` + `SMU` + `DMUB` (~0.5–1 s) when the monitor turns back on frequently misses the DisplayPort HPD / AUX link-training window (`prop_connector: (null)`), leaving the screen permanently black (`disconnected`) even if switching TTYs afterwards.
- **Recommended Desktop Fix**:
  - Permanent NixOS parameter on the desktop host:
    ```nix
    boot.kernelParams = ["amdgpu.runpm=0"];
    ```
    This keeps **both GPUs active** (preserving the Ryzen iGPU's independent `VCN` hardware video encoder/decoder on `/dev/dri/renderD129` for OBS, browsers, or background apps) while keeping normal dGPU idle clock/voltage scaling and `GFXOFF` enabled (0 W difference with screen on; ~5–8 W difference with screen off).
  - Immediate live-session mitigation without rebooting:
    ```bash
    echo on | sudo tee /sys/bus/pci/devices/<dgpu-pci-bdf>/power/control
    ```
