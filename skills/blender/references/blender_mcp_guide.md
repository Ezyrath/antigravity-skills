# Blender MCP Technical Reference & Protocol Guide

This guide details the internal protocol, tool parameters, and automation patterns for the official Blender Lab MCP Server.

---

## 1. Network Protocol Specifications

The Blender MCP communication pipeline is split across two protocols:

### A. Client ⟷ Server (JSON-RPC 2.0 / MCP Stdio)
Antigravity executes the Python CLI process:
```bash
/home/ezyrath/.local/share/blender-mcp-venv/bin/blender-mcp
```
The server reads JSON-RPC 2.0 requests on `stdin` and responds on `stdout` according to the Model Context Protocol specification (`2024-11-05`).

### B. Server ⟷ Blender Add-on (Null-Byte-Delimited TCP Socket)
The MCP Python server forwards requests over a persistent or per-call TCP socket to `127.0.0.1:9876`:
- **Request Format**:
  ```json
  {"type": "execute", "code": "<python_code_str>", "strict_json": true}\0
  ```
- **Response Format**:
  ```json
  {"status": "ok", "result": {...}, "stdout": "...", "stderr": "..."}\0
  ```
- **Error Format**:
  ```json
  {"status": "error", "message": "<traceback_string>", "stdout": "...", "stderr": "..."}\0
  ```

---

## 2. Complete MCP Tools Catalog

| Tool Name | Parameters | Description |
|:---|:---|:---|
| `execute_blender_code` | `code: str` | Executes Python code in Blender. Returns `result: dict`. |
| `get_objects_summary` | *(none)* | Returns collection tree, active workspace, camera, and object states. |
| `get_object_detail_summary` | `name: str` | Returns object data-block info, modifiers, materials, vertex/polygon counts. |
| `render_viewport_to_path` | `output_path: str` | Renders native viewport to PNG file with active viewport shading. |
| `render_thumbnail_to_path` | `output_path: str` | Low-resolution camera render for quick previews. |
| `get_screenshot_of_window_as_image` | *(none)* | Full editor window snapshot encoded as base64 PNG. |
| `get_screenshot_of_area_as_image` | *(none)* | Snapshot of a focused editor area (3D View, Shader Editor, etc.). |
| `get_screenshot_of_window_as_json` | *(none)* | UI layout tree describing areas, space types, and editors. |
| `jump_to_view3d_object_by_name` | `name: str` | Centers and frames 3D viewport on target object. |
| `jump_to_tab_by_name` | `name: str` | Switches active workspace tab (e.g. `'Layout'`, `'Shading'`, `'Geometry Nodes'`). |
| `get_blendfile_summary_datablocks` | *(none)* | Counts of datablocks (meshes, textures, materials, actions). |
| `get_blendfile_summary_missing_files` | *(none)* | Scans for broken external image/asset file paths. |
| `get_blendfile_summary_path_info` | *(none)* | Path to open blend file, unsaved modifications flag, file age. |
| `get_python_api_docs` | `identifier: str` | Look up Python docstrings and API reference for `bpy.types.*` or `bpy.ops.*`. |
| `search_api_docs` | `query: str` | Full-text search across Blender Python API. |
| `search_manual_docs` | `query: str` | Full-text search across Blender User Manual. |

---

## 3. Headless CLI Execution (`blender-mcp`)

Blender can also be started in headless background mode without a desktop window, while serving MCP requests:

```bash
blender --background path/to/project.blend --command blender_mcp --port 9876
```

In background mode:
- Windowing and UI workspace queries return static fallback structures.
- Deferred asynchronous operators are disabled; all tasks must finish synchronously.
- Mesh operations, material nodes, modifiers, simulations, and background rendering (`bpy.ops.render.render()`) remain fully functional.
