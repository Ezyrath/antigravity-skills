# ====================================================================
# UNIVERSAL ENGINEERING, UNREAL ENGINE 5, RUST/BEVY & NIXOS GUIDELINES
# ====================================================================

This ruleset defines universal architectural, coding, documentation, and tooling guidelines across all projects (Unreal Engine 5 / C++, Rust / Bevy, NixOS, and general software repositories).

---

## 1. Unreal Engine C++ Coding Standards

1. **Naming Conventions** :
   - Prefix `U` for `UObject` subclasses.
   - Prefix `A` for `AActor` subclasses.
   - Prefix `F` for plain C++ structs and math types.
   - Prefix `E` for enumerations (`enum class`).
   - Prefix `I` for interface classes.
   - Prefix `T` for templates.
2. **Modern Pointer & Memory Semantics** :
   - Always prefer `TObjectPtr<T>` for `UPROPERTY` members.
   - Use `TSharedPtr<T>` / `TWeakPtr<T>` for non-reflected native C++ types.
   - Follow *Include What You Use* (IWYU) strictly for optimal build times.
3. **Data-Oriented Design & Performance** :
   - Avoid spawning millions of heavyweight `AActor` instances for particle, stellar, or cellular simulations.
   - Prefer lightweight data buffers (`struct`), `MassEntity`, ECS, or Compute Shaders.
   - Heavy procedural math (noise, mesh extraction, physics) must run asynchronously (`AsyncTask`, `ParallelFor`, `FRunnable`, `TaskGraph`) and never block the GameThread.

---

## 2. Large World Coordinates (LWC) & Spatial Precision

- Always use 64-bit precision math: `FVector3d`, `FTransform3d`, and `double` for spatial coordinates.
- For cosmological or planetary scales, implement hierarchical reference frames (*Nested Reference Frames*) rather than storing all coordinates in a single global origin.
- Use floating origin recentering around the active observer/camera to eliminate floating-point jitter.

---

## 3. Unreal Engine MCP Integration (Zero Token Cold-Start)

When connected to an Unreal Engine MCP server (e.g. `unreal-mcp`):
- **Golden Rule** : **NEVER** call `list_toolsets` or `describe_toolset`. Directly invoke `call_tool`.
- Format :
  - `ServerName: "unreal-mcp"`
  - `ToolName: "call_tool"`
  - `Arguments: { "toolset_name": "<Toolset>", "tool_name": "<Function>", "arguments": { ... } }`
- **In-Game Photography & Visual Validation** :
  - Mathematical and unit tests verify logic, but computer graphics, procedural generation, and shaders require visual inspection.
  - Start PIE: `EditorToolset.EditorAppToolset.StartPIE` (`options: { bSimulate: false, WarmupSeconds: 2.0 }`).
  - Reposition camera/pawn: `editor_toolset.toolsets.actor.ActorTools.set_actor_transform` with `xform: { location, rotation, scale }`.
  - Capture instant image: `EditorToolset.EditorAppToolset.CaptureEditorImage` (returns base64 PNG).
  - Inspect visually: decode base64 PNG and call `view_file` to inspect lighting (Lumen), shadows (VSM), terrain continuity, and biomes.

---

## 4. Visual Headless Execution with Sway & wl-inject

- When running the Unreal Engine Editor or graphical tests without disrupting the user's active desktop:
  - **Never use `Xvfb`** (lacks DRI3, causing `vkCreateSwapchainKHR` crashes) or `weston-headless` (lacks real DRM/GBM swapchains, triggering `VK_ERROR_SURFACE_LOST_KHR`).
  - **Use Headless Sway** via `run_sway_headless.sh` (`WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1` on an isolated display socket e.g. `wayland-headless`). This utilizes the real DRM render node (`/dev/dri/renderD128`) via wlroots, granting full hardware-accelerated Vulkan (Lumen, Nanite, VSM) at native GPU speed.
  - **Input Automation with `wl-inject`** : Drive editor viewport navigation and player pawns by piping commands (`press`, `release`, `drag`, `tap`, `type`) into `/tmp/wl-inject-<display>.fifo`.
  - **Visual Capture** : Capture frames via `grim` or MCP `CaptureEditorImage` and inspect visually using `view_file`.

---

## 5. Nanite & Procedural Mesh Building (`FMeshDescription`)

When constructing static meshes dynamically with Nanite enabled:
- **Required Modules** in `Build.cs` : `"MeshDescription"` and `"StaticMeshDescription"`.
- **Attribute Order** : Always call `MeshDescription.SetNumUVChannels(1)` before `Attributes.Register()`.
- **Critical Assertion Rule** : Always call `FStaticMeshOperations::ComputeTriangleTangentsAndNormals(OutMeshDescription, 0.0f);` before submitting to `UStaticMesh::Build`, preventing cluster normalizer crashes (`check(TriangleNormals.Num() > 0)`).
- **Editor vs Runtime** : Full Nanite cluster compilation is an Editor feature (`#if WITH_EDITOR`). In non-editor standalone builds, prefer prebaked assets or `BuildFromMeshDescriptions` with fast build parameters.

---

## 6. Git Commit Signatures & SSH Agent (Proton Pass)

- Commits must always be signed with GPG (`git commit -S`).
- Passphrase caching should be managed via `gpg-agent` / system keyring (e.g. KDE Wallet) for seamless non-interactive signing.
- SSH authentication is managed by the **Proton Pass SSH Agent** (`~/.ssh/proton-pass-ssh-agent.sock`). If `git push`/`fetch` fails with `Permission denied (publickey)`, Proton Pass is not launched or unlocked — ask the user to start/unlock Proton Pass instead of bypassing SSH.

---

## 7. Rust, Bevy ECS & WebAssembly Modding Architecture

1. **Workspace Feature Hygiene**:
   - Keep `bevy` in `[workspace.dependencies]` restricted to `default-features = false, features = ["default_app"]` so simulation crates and headless dedicated servers compile without GPU/windowing overhead.
   - Enable `features = ["3d", "ui"]` exclusively in the graphical client crate.
2. **Everything is a Mod (WebAssembly First)**:
   - When building moddable simulations (e.g. *Project Voidlore*), the engine host must remain content-agnostic. Core gameplay definitions (voxel blocks, biomes, NPC behaviors, colony rules, emergent narrative events) belong in WebAssembly mods (`wasm32-unknown-unknown`) loaded via `wasmtime`.
3. **64-bit Hierarchical Spatial Coordinates**:
   - Use 64-bit math (`glam::DVec3` and hierarchical IDs: `GalaxyId` -> `SectorCoord` -> `StarSystemId` -> `PlanetId`) for simulation coordinates, converting to camera-relative single-precision `Vec3` only for Bevy `Transform` rendering.
4. **Unified Self-Hosted Topologies**:
   - Support `SoloEmbedded` (local server inside client), `ListenServer`, and headless `DedicatedServer` (`MinimalPlugins` + `ScheduleRunnerPlugin`) through a single shared network protocol.

---

## 8. NixOS FHS Sandbox & Host Root Bridge (`root_bridge.py`)

When running inside a NixOS `buildFHSEnv` (`bwrap`) user namespace where `sudo`/`pkexec` cannot elevate privileges (`PR_SET_NO_NEW_PRIVS`) and device nodes appear as `nobody:nogroup`:
- **Never waste steps writing ad-hoc privilege-escalation scripts**. Use the bundled `linux-root-bridge` skill script directly.
- Ask the user to launch the bridge in a host terminal:
  `sudo python3 ~/.gemini/config/plugins/antigravity-skills/skills/linux-root-bridge/scripts/root_bridge.py`
- Execute root commands transparently via the Unix socket (`/run/user/<uid>/agy-root-bridge.sock`):
  `python3 ~/.gemini/config/plugins/antigravity-skills/skills/linux-root-bridge/scripts/root_bridge.py --timeout 60 --exec "<command>"`

---

## 9. Documentation & `README.md` Full-File Coherence Pass

Whenever creating or modifying `README.md` or any user-facing documentation file:
- **Mandatory Full-File Re-Read**: Never rely solely on localized `edit_file` hunks. After applying edits, **always read the entire file from line 1 to the end** before committing or reporting completion.
- **Zero-Contradiction Audit**: Verify that no earlier or later section (intro summary, badges, Quick Start steps, examples, file lists, or footers) contradicts the updated text — especially regarding:
  - Support status & stability guarantees (e.g. *stable/tested* vs *preview/experimental/not validated*).
  - Removed, renamed, or defaulted CLI flags, config keys, paths, and version numbers.
- **Cross-File Metadata Alignment**: When project scope, supported versions, or CLI options change, verify alignment across `README.md`, CLI `--help` / `usage()`, and package metadata (e.g. `flake.nix` `description`, `Cargo.toml`, `package.json`, `plugin.json`).

