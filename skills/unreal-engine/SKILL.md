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

## 4. Nanite Procedural Mesh Building Checklist

When generating procedural geometry with Nanite enabled:
1. **Modules Required** (`Build.cs`) : `"MeshDescription"`, `"StaticMeshDescription"`.
2. **Channel Setup** : Always call `MeshDescription.SetNumUVChannels(1)` before `Attributes.Register()`.
3. **Triangle Tangents Assertion** : Always invoke `FStaticMeshOperations::ComputeTriangleTangentsAndNormals(MeshDescription, 0.0f)` before calling `UStaticMesh::Build`.
4. **Editor vs Runtime** : Cluster building requires Derived Data Cache (DDC) and is wrapped under `#if WITH_EDITOR`. At runtime non-editor, use fast build or prebaked assets.

---

## 5. Bundled Scripts & References

- Build script: [scripts/build.sh](./scripts/build.sh)
- Headless test runner: [scripts/run_headless_tests.sh](./scripts/run_headless_tests.sh)
- Nanite procedural reference: [references/nanite_architecture.md](./references/nanite_architecture.md)
- Unreal MCP reference: [references/unreal_mcp_guide.md](./references/unreal_mcp_guide.md)
