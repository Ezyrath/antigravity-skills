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
- `StartPIE` / `StopPIE` / `IsPIERunning`

### 3. Scene & World — `editor_toolset.toolsets.scene.SceneTools`
- `get_current_level`: `{}`
- `load_level`: `{ "level_path": "<Path>" }`
- `find_actors`: `{ "name": "", "tag": "", "collision_channels": [] }`
- `add_to_scene_from_class`: `{ "actor_type": { "refPath": "<ClassPath>" }, "name": "<Name>", "xform": { ... } }`
- `remove_from_scene`: `{ "actor": { "refPath": "<Path>" } }`

### 4. Actor & Components — `editor_toolset.toolsets.actor.ActorTools`
- `get_actor_transform`: `{ "actor": { "refPath": "<Path>" } }`
- `set_actor_transform`: `{ "actor": { "refPath": "<Path>" }, "transform": { ... } }`
- `get_components`: `{ "actor": { "refPath": "<Path>" } }`
