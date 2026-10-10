#!/usr/bin/env python3
"""
Blender Python script for exporting 3D assets to Unreal Engine 5.
Configured with:
- Z-up, Y-forward to UE5 coordinate conversion
- Automatic selection of associated UCX collision hulls
- Clean smoothing and triangulation settings
"""

import sys
import os

try:
    import bpy
except ImportError:
    print("This script is intended to run inside Blender or via execute_blender_code.")
    sys.exit(1)

def export_asset_for_unreal(object_name: str, output_fbx_path: str):
    bpy.ops.object.select_all(action='DESELECT')
    
    target = bpy.data.objects.get(object_name)
    if not target:
        raise ValueError(f"Object '{object_name}' not found in active blend file.")
        
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    
    # Also select any collision meshes following UE naming conventions
    collision_prefixes = (f"UCX_{object_name}", f"UBX_{object_name}", f"USP_{object_name}")
    collision_count = 0
    for obj in bpy.data.objects:
        if obj.name.startswith(collision_prefixes):
            obj.select_set(True)
            collision_count += 1
            
    os.makedirs(os.path.dirname(os.path.abspath(output_fbx_path)), exist_ok=True)
    
    bpy.ops.export_scene.fbx(
        filepath=output_fbx_path,
        use_selection=True,
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        axis_forward='-Z',
        axis_up='Y',
        bake_space_transform=False,
        mesh_smooth_type='FACE',
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        primary_bone_axis='Y',
        secondary_bone_axis='X',
        use_armature_deform_only=True,
    )
    
    return {
        "status": "ok",
        "exported_asset": object_name,
        "collision_hulls": collision_count,
        "output_path": output_fbx_path
    }

if __name__ == "__main__":
    if len(sys.argv) > 1:
        name = sys.argv[1]
        out = sys.argv[2] if len(sys.argv) > 2 else f"/tmp/{name}.fbx"
        result = export_asset_for_unreal(name, out)
        print(f"Exported: {result}")
