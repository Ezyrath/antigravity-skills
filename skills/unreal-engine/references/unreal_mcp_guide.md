# Unreal Engine MCP Quick Reference & Warm Cache

## Direct Tool Invocation Pattern
Never call `list_toolsets` or `describe_toolset`. Invoke tools directly using:
- `ServerName: "unreal-mcp"`
- `ToolName: "call_tool"`
- `Arguments: { "toolset_name": "<Toolset>", "tool_name": "<Tool>", "arguments": { ... } }`

---

## Toolsets Directory

### 1. Automation & Testing — `AutomationTestToolset.AutomationTestToolset`
- `DiscoverTests`: `{}`
- `ListTests`: `{}`
- `RunTestsByFilter`: `{ "filterExpression": "<FilterName>" }`
- `GetTestStatus`: `{}`
- `GetTestResults`: `{}`

### 2. Editor App & Camera — `EditorToolset.EditorAppToolset`
- `GetCameraTransform`: `{}`
- `SetCameraTransform`: `{ "transform": { "location": {x,y,z}, "rotation": {pitch,yaw,roll}, "scale": {x,y,z} } }`
- `SelectActors`: `{ "actors": [{ "refPath": "<Path>" }] }`
- `FocusOnActors`: `{ "actors": [{ "refPath": "<Path>" }] }`
- `StartPIE`: `{ "options": { "bSimulate": false, "WarmupSeconds": 2.0 } }`
- `StopPIE`: `{}`
- `IsPIERunning`: `{}`
- `CaptureEditorImage`: `{}` -> Captures the active editor / PIE viewport directly as base64 PNG data.

### 3. Scene & World — `editor_toolset.toolsets.scene.SceneTools`
- `get_current_level`: `{}`
- `load_level`: `{ "level_path": "<Path>" }`
- `find_actors`: `{ "name": "", "tag": "", "collision_channels": [] }`
- `add_to_scene_from_class`: `{ "actor_type": { "refPath": "<ClassPath>" }, "name": "<Name>", "xform": { ... } }`
- `remove_from_scene`: `{ "actor": { "refPath": "<Path>" } }`

### 4. Actor & Components — `editor_toolset.toolsets.actor.ActorTools`
- `get_actor_transform`: `{ "actor": { "refPath": "<Path>" } }`
- `set_actor_transform`: `{ "actor": { "refPath": "<Path>" }, "worldspace": true, "xform": { "location": {x,y,z}, "rotation": {pitch,yaw,roll}, "scale": {x,y,z} } }`
- `get_components`: `{ "actor": { "refPath": "<Path>" } }`

### 5. In-Game Photography & Live Visual Validation Runbook
1. **Launch Editor / PIE** :
   - If editor is closed, launch as daemon (`run_command` with `IsDaemon: true`).
   - Start simulation: `EditorToolset.EditorAppToolset.StartPIE` with `{ "options": { "bSimulate": false, "WarmupSeconds": 2.0 } }`.
2. **Locate & Move Pawn / Camera** :
   - Find active pawn: `editor_toolset.toolsets.scene.SceneTools.find_actors` (identifies `/Game/Maps/UEDPIE_0_...:PersistentLevel.VoidPlanetPawn_0`).
   - Reposition / Orient pawn or camera:
     `editor_toolset.toolsets.actor.ActorTools.set_actor_transform` with `xform: { location: {x,y,z}, rotation: {pitch,yaw,roll}, scale: {1,1,1} }`.
3. **Capture Viewport Instantly** :
   - Call `EditorToolset.EditorAppToolset.CaptureEditorImage` with `{}`.
   - Decode returned base64 PNG:
     ```python
     import json, base64

     with open("<step_output.txt>", "r") as f:
       data = json.load(f)
     with open("<dest.png>", "wb") as f_out:
       f_out.write(base64.b64decode(data["returnValue"]["data"]))
     ```
4. **Inspect Visually** :
   - Call `view_file` directly on `<dest.png>`. The AI agent inspects the rendered lighting, shadows, LODs, and biomes visually.
