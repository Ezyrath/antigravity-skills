---
name: unreal-engine
description: >-
  Universal development workflows, procedures, and runbooks for Unreal Engine 5 projects.
  Use this skill when developing, compiling, running headless automated tests, interacting with
  Unreal Engine MCP, or building Nanite procedural geometry.
---

# Unreal Engine 5 Development Workflows & Runbooks

This skill provides generic, battle-tested operational procedures and helper scripts for developing Unreal Engine 5 C++ projects on Linux and Windows.

---

## 1. Project Compilation Runbook

Unreal Engine projects using C++ are compiled via UnrealBuildTool (UBT) or `make` (Linux).

### Linux Standard Build
```bash
# If a Makefile exists in the project root:
make <ProjectName>Editor-Linux-Development

# Direct invocation via RunUBT:
"$UNREAL_INSTALL_DIR/Engine/Build/BatchFiles/RunUBT.sh" <ProjectName>Editor Linux Development -Project="$PWD/<ProjectName>.uproject"
```

> [!WARNING]
> Do not pass UBT flags like `-NoHotReload` directly to `make` as `make` interprets `-N` as an option. Run the standard target directly with `make`.

---

## 2. Headless Automated Testing Runbook

To execute unit and integration automation tests without opening the editor GUI (in CI/CD or non-interactive shells):

### Standard Headless Command
```bash
"$UNREAL_INSTALL_DIR/Engine/Binaries/Linux/UnrealEditor" "$PWD/<ProjectName>.uproject" \
  -ExecCmds="Automation RunTests <TestFilter>; Quit" \
  -unattended -nopause -testexit="Automation Test Queue Empty" \
  -log -log=Automation.log -nullrhi -nosplash
```

- `-nullrhi` : Disables GPU rendering window (pure headless).
- `-unattended -nopause` : Prevents dialog prompts from blocking execution.
- `-testexit="Automation Test Queue Empty"` : Exits automatically as soon as the test queue empties.
- Exit code `0` indicates all tests passed successfully.

---

## 3. Unreal Engine MCP Interaction (Zero Token Cold-Start)

The official Unreal Engine MCP server listens on `http://127.0.0.1:8000/mcp`.

- **Strict Protocol Rule** : Never call `list_toolsets` or `describe_toolset`. Directly invoke `call_tool`.
- **Target Toolsets** :
  - `AutomationTestToolset.AutomationTestToolset` (`DiscoverTests`, `RunTestsByFilter`, `GetTestStatus`, `GetTestResults`)
  - `EditorToolset.EditorAppToolset` (`GetCameraTransform`, `SetCameraTransform`, `StartPIE`, `StopPIE`)
  - `editor_toolset.toolsets.scene.SceneTools` (`get_current_level`, `load_level`, `find_actors`)
  - `editor_toolset.toolsets.actor.ActorTools` (`get_actor_transform`, `set_actor_transform`)

---

## 4. Visual Verification & Viewport Photography Runbook (Live MCP)

When the Unreal Engine Editor is active with `unreal-mcp`, AI assistants can actively navigate in-game and inspect rendering quality visually (terrain relief, lighting, Nanite clusters, atmosphere, shadows):

### Direct Visual Verification Protocol
1. **Launch & Simulation** :
   - Launch editor if closed: `run_command` with `IsDaemon: true`.
   - Start PIE: `EditorToolset.EditorAppToolset.StartPIE` with `{ "options": { "bSimulate": false, "WarmupSeconds": 2.0 } }`.
2. **Navigate Pawn or Camera** :
   - Center on actor: `EditorToolset.EditorAppToolset.FocusOnActors` with `{ "actors": [{ "refPath": "<Path>" }] }`.
   - Set editor camera: `EditorToolset.EditorAppToolset.SetCameraTransform` with `{ "transform": { "location": {x,y,z}, "rotation": {pitch,yaw,roll}, "scale": {1,1,1} } }`.
   - Move live player pawn: `editor_toolset.toolsets.actor.ActorTools.set_actor_transform` with `actor: { "refPath": "<PawnPath>" }`, `worldspace: true`, and `xform: { "location": {x,y,z}, "rotation": {pitch,yaw,roll}, "scale": {1,1,1} }`.
3. **Instant Viewport Capture** :
   - Call `EditorToolset.EditorAppToolset.CaptureEditorImage` with `{}` (returns base64-encoded PNG directly in the response).
   - Alternatively run `HighResShot 1920x1080` to write to `Saved/Screenshots/LinuxEditor/`.
4. **Multimodal Visual Inspection** :
   - Decode base64 PNG and call `view_file` on the resulting `.png` file.
   - Antigravity natively parses and views the image to verify Lumen GI, Virtual Shadow Maps, procedural terrain continuity, and biomes.

---

## 5. Visual Headless Execution with Sway & wl-inject (Zero-Intrusion Hardware Rendering)

Running Unreal Engine Editor with full graphics (Vulkan RHI, Nanite, Lumen, VSM) normally opens desktop windows that disrupt the user's active workspace. Conversely, `-nullrhi` disables the GPU pipeline completely, preventing visual validation.

Standard headless X11 / Wayland servers fail for modern Vulkan:
- **`Xvfb`** lacks DRI3, causing `vkCreateSwapchainKHR` crashes.
- **`weston-headless`** lacks a real DRM/GBM swapchain, yielding `VK_ERROR_SURFACE_LOST_KHR`.

### The Solution: Headless Sway (`wlroots`) + `wl-inject`
Sway running with `WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1` utilizes the hardware DRM render node (`/dev/dri/renderD128`) via GBM/wlroots. Unreal Engine renders at native GPU speed onto a virtual display (`HEADLESS-1`, e.g. 1920x1080) with zero visual disruption on the host desktop.

Furthermore, Sway exposes wlroots virtual input protocols (`zwlr_virtual_pointer_manager_v1` and `zwp_virtual_keyboard_manager_v1`), which `wl-inject` leverages to drive the editor and in-game pawns.

### Script Helper: `scripts/run_sway_headless.sh`
Launch any graphical application (Unreal Editor, tests, tools) inside an isolated headless Sway session:
```bash
./scripts/run_sway_headless.sh "$UNREAL_INSTALL_DIR/Engine/Binaries/Linux/UnrealEditor" "$PWD/<ProjectName>.uproject" -log
```

The script automatically:
1. Spawns headless Sway on an isolated display socket (`wayland-1` by default).
2. Sets up a persistent FIFO at `/tmp/wl-inject-wayland-1.fifo` backed by `wl-inject`.
3. Exports a helper environment at `/tmp/sway-headless-wayland-1/env.sh` with `inject()` and `screenshot()` functions.

### Interacting with the Headless Session
From any terminal or background task:
```bash
source /tmp/sway-headless-wayland-1/env.sh

# Inject keyboard shortcuts and text:
inject "tap f8 100"                 # Eject / Possess in PIE
inject "tap tilde 50"              # Open developer console
inject "type stat fps"             # Type console command
inject "tap enter 50"              # Submit command

# Navigate 3D camera / Pawn:
inject "press w"                   # Start flying forward
sleep 1
inject "release w"                 # Stop flying
inject "drag 300 0 right 15 10"    # Smooth mouse drag with right-click held (rotate camera)

# Capture virtual screen:
screenshot /tmp/view.png
```

---

## 6. Nanite Procedural Mesh Building Checklist

When generating procedural geometry with Nanite enabled:
1. **Modules Required** (`Build.cs`) : `"MeshDescription"`, `"StaticMeshDescription"`.
2. **Channel Setup** : Always call `MeshDescription.SetNumUVChannels(1)` before `Attributes.Register()`.
3. **Triangle Tangents Assertion** : Always invoke `FStaticMeshOperations::ComputeTriangleTangentsAndNormals(MeshDescription, 0.0f)` before calling `UStaticMesh::Build`.
4. **Editor vs Runtime** : Cluster building requires Derived Data Cache (DDC) and is wrapped under `#if WITH_EDITOR`. At runtime non-editor, use fast build or prebaked assets.

---

## 7. Bundled Scripts & References

- Build script: [scripts/build.sh](./scripts/build.sh)
- Headless test runner: [scripts/run_headless_tests.sh](./scripts/run_headless_tests.sh)
- Sway Headless runner: [scripts/run_sway_headless.sh](./scripts/run_sway_headless.sh)
- Nanite procedural reference: [references/nanite_architecture.md](./references/nanite_architecture.md)
- Unreal MCP reference: [references/unreal_mcp_guide.md](./references/unreal_mcp_guide.md)

