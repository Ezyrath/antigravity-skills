---
name: bevy
description: >-
  Universal development workflows, ECS architecture guidelines, procedural 3D/voxel meshing,
  WebAssembly (Wasmtime) modding pipelines, self-hosted client/server networking, and headless
  testing runbooks for Rust & Bevy engine projects.
---

# Bevy & Modern Rust Game Engine Workflows

This skill provides operational procedures, architectural patterns, and verification runbooks for developing 3D games and multi-scale simulations with **Rust** and **Bevy**.

---

## 1. Modular Cargo Workspace & Feature Separation

To support both graphical 3D clients and lightweight headless dedicated servers (`MinimalPlugins`) within the same Cargo workspace without compiling GPU/windowing dependencies on the server:

### Root `Cargo.toml` Pattern
```toml
[workspace]
resolver = "3"
members = ["crates/*", "mods/*"]

[workspace.dependencies]
# Core app features only by default (ECS, Tasks, Asset, Log, State)
bevy = { version = "0.19", default-features = false, features = ["default_app"] }

# Fast dev iteration: optimize engine dependencies while keeping project crates fast to compile
[profile.dev]
opt-level = 1

[profile.dev.package."*"]
opt-level = 3
```

- **Shared / Simulation / Server Crates** (`voidlore_voxel`, `voidlore_universe`, `voidlore_server`): Use `bevy.workspace = true` (no windowing, no WGPU/Vulkan dependency required at runtime).
- **3D Client Crate** (`voidlore_client`): Explicitly opt into rendering and UI:
  ```toml
  bevy = { workspace = true, features = ["3d", "ui"] }
  ```

---

## 2. Procedural 3D & Voxel Meshing (`bevy::mesh::Mesh`)

When constructing dynamic 3D meshes (such as face-culled or greedy-meshed voxel chunks) in Bevy 0.19+:

### Required Imports & Attribute Layout
```rust
use bevy::asset::RenderAssetUsages;
use bevy::mesh::{Indices, PrimitiveTopology};
use bevy::prelude::*;

pub fn build_bevy_mesh(
    positions: Vec<[f32; 3]>,
    normals: Vec<[f32; 3]>,
    colors: Vec<[f32; 4]>,
    indices: Vec<u32>,
) -> Mesh {
    let mut mesh = Mesh::new(
        PrimitiveTopology::TriangleList,
        RenderAssetUsages::default(),
    );
    mesh.insert_attribute(Mesh::ATTRIBUTE_POSITION, positions);
    mesh.insert_attribute(Mesh::ATTRIBUTE_NORMAL, normals);
    mesh.insert_attribute(Mesh::ATTRIBUTE_COLOR, colors);
    mesh.insert_indices(Indices::U32(indices));
    mesh
}
```

### Performance & Multithreading Rules
- Never generate heavy procedural noise or mesh thousands of chunks synchronously on the main thread during frame updates.
- Offload chunk generation and greedy meshing to `AsyncComputeTaskPool`, spawning a task per dirty chunk and polling finished `Mesh` data in a lightweight system.
- Always cull interior faces between adjacent opaque voxels (`is_solid && !is_transparent`).

---

## 3. WebAssembly Modding Architecture ("Base Game as a Mod")

For deeply moddable simulations where the core game content itself is a WebAssembly module:

1. **Guest SDK Crate (`*_sdk`)**:
   - Compiled for `wasm32-unknown-unknown`.
   - Declares `#[link(wasm_import_module = "<host_namespace>")] unsafe extern "C"` imports for logging, asset/block registration, and simulation events.
   - Provides `#[cfg(not(target_arch = "wasm32"))]` fallbacks so mods can also run native Rust unit tests (`cargo test`).
2. **Core & Community Mods (`mods/*`)**:
   - Configured with `crate-type = ["cdylib", "rlib"]`.
   - Exports deterministic C ABI entrypoints (`#[unsafe(no_mangle)] pub extern "C" fn on_mod_init()`, `on_universe_tick(tick: u64)`).
   - Compiled via:
     ```bash
     cargo build -p <mod_crate> --target wasm32-unknown-unknown --release
     cp target/wasm32-unknown-unknown/release/<mod_crate>.wasm assets/mods/
     ```
3. **Host Runtime Plugin (`*_wasm_host` with `wasmtime`)**:
   - Wraps `wasmtime::Engine` and a `Mutex<Vec<LoadedModInstance>>` inside a Bevy `Resource`.
   - Uses `wasmtime::Result` and `wasmtime::error::Context` for error handling.
   - Orders mod initialization in `Startup` **before** world/chunk mesh generation (`setup_world.after(startup_load_wasm_mods)`).

---

## 4. Multi-Scale Spatial Precision (64-bit Hierarchical Reference Frames)

For planetary, stellar, or galactic simulations:
- Never store galactic or planetary world positions directly in single-precision `Transform` (`f32`).
- Use hierarchical 64-bit coordinates (`GalaxyId` $\rightarrow$ `SectorCoord` $\rightarrow$ `StarSystemId` $\rightarrow$ `PlanetId` $\rightarrow$ `glam::DVec3`).
- Compute camera-relative `glam::Vec3` offsets (`(entity_dvec3 - observer_dvec3).as_vec3()`) when updating Bevy `Transform` components for rendering.

---

## 5. Unified Self-Hosted Networking & Headless Smoke Testing

### Unified Topologies
Support four seamless operating modes via a shared `NetworkMode` resource:
- `SoloEmbedded`: Client runs an internal local server loop automatically (zero external setup).
- `ListenServer { bind_addr }`: Client hosts and accepts remote peers.
- `DedicatedServer { bind_addr }`: Headless binary using `MinimalPlugins` + `ScheduleRunnerPlugin::run_loop(Duration::from_millis(50))` + `LogPlugin`.
- `RemoteClient { server_addr }`: Client connects to a self-hosted server and synchronizes required `.wasm` mods.

### Headless Server Smoke Test
Always provide a `--smoke-test` flag on the dedicated server binary that switches `ScheduleRunnerPlugin` to `ScheduleRunnerPlugin::run_once()`. This enables instant CI and CLI verification of ECS startup systems, universe initialization, and WebAssembly mod loading without opening a window:
```bash
cargo run --bin <server_bin> -- --smoke-test
```

### Visual Headless Client Verification (Sway + `wl-inject`)
When visually inspecting the 3D Bevy client on Linux without disrupting the user's desktop:
- Use Headless Sway (`WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1`) so Bevy's WGPU/Vulkan backend renders on the real GPU (`/dev/dri/renderD128`).
- Capture screenshots with `grim` and inspect them via `view_file`.

---

## 6. Bundled Validation Script

- Workspace & WASM validator: [scripts/validate_bevy_workspace.sh](./scripts/validate_bevy_workspace.sh)
