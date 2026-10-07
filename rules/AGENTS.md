# ====================================================================
# UNREAL ENGINE 5 & MODERN C++ AGENT GUIDELINES
# ====================================================================

This ruleset defines universal architectural, coding, and tooling guidelines for AI assistants working on Unreal Engine 5 projects.

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

## 4. Nanite & Procedural Mesh Building (`FMeshDescription`)

When constructing static meshes dynamically with Nanite enabled:
- **Required Modules** in `Build.cs` : `"MeshDescription"` and `"StaticMeshDescription"`.
- **Attribute Order** : Always call `MeshDescription.SetNumUVChannels(1)` before `Attributes.Register()`.
- **Critical Assertion Rule** : Always call `FStaticMeshOperations::ComputeTriangleTangentsAndNormals(OutMeshDescription, 0.0f);` before submitting to `UStaticMesh::Build`, preventing cluster normalizer crashes (`check(TriangleNormals.Num() > 0)`).
- **Editor vs Runtime** : Full Nanite cluster compilation is an Editor feature (`#if WITH_EDITOR`). In non-editor standalone builds, prefer prebaked assets or `BuildFromMeshDescriptions` with fast build parameters.

---

## 5. Git Commit Signatures

- Commits must always be signed with GPG (`git commit -S`).
- Passphrase caching should be managed via `gpg-agent` / system keyring (e.g. KDE Wallet) for seamless non-interactive signing.
