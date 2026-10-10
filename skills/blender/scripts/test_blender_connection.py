#!/usr/bin/env python3
"""
Health check script for Blender MCP connection.
Tests direct TCP connection to port 9876 and queries basic scene metrics.
"""

import json
import socket
import sys

HOST = "127.0.0.1"
PORT = 9876

def check_blender():
    print(f"Connecting to Blender at {HOST}:{PORT}...")
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(5.0)
            sock.connect((HOST, PORT))
            
            code = (
                "import bpy\n"
                "result = {\n"
                "    'scene': bpy.context.scene.name,\n"
                "    'workspace': bpy.context.workspace.name if bpy.context.workspace else 'None',\n"
                "    'object_count': len(bpy.data.objects),\n"
                "    'objects': [obj.name for obj in bpy.data.objects],\n"
                "}\n"
            )
            
            payload = json.dumps({"type": "execute", "code": code, "strict_json": True}) + "\0"
            sock.sendall(payload.encode("utf-8"))
            
            buf = bytearray()
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                buf.extend(chunk)
                if b"\0" in buf:
                    break
                    
            line, _, _ = buf.partition(b"\0")
            data = json.loads(line.decode("utf-8"))
            
            if data.get("status") == "ok":
                res = data.get("result", {})
                print("\n[SUCCESS] Blender MCP Bridge is operational!")
                print(f"  Active Scene     : {res.get('scene')}")
                print(f"  Workspace        : {res.get('workspace')}")
                print(f"  Total Objects    : {res.get('object_count')}")
                print(f"  Objects          : {', '.join(res.get('objects', []))}")
                return 0
            else:
                print(f"\n[ERROR] Blender returned an error: {data.get('message')}")
                return 1

    except ConnectionRefusedError:
        print(f"\n[ERROR] Connection refused on {HOST}:{PORT}.")
        print("  -> Ensure Blender is running and the MCP add-on is enabled with the server started.")
        return 1
    except Exception as ex:
        print(f"\n[ERROR] Exception connecting to Blender: {ex}")
        return 1

if __name__ == "__main__":
    sys.exit(check_blender())
