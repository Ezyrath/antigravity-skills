# Programmatic Nanite & Hybrid Voxel Architecture Guide

## 1. The Challenge of Real-Time Nanite Terraforming
Nanite achieves incredible geometric density by pre-partitioning static meshes into GPU-friendly clusters of 128 triangles, organized into a hierarchical Directed Acyclic Graph (DAG).
Because generating this cluster hierarchy is computationally intensive, Nanite meshes cannot easily be regenerated every frame on the CPU.

## 2. Decoupled Hybrid Pattern
To combine Nanite's visual fidelity (Virtual Shadow Maps, Lumen, zero draw calls at distance) with dynamic real-time terraforming (< 5 ms):

1. **Macroscopic Visual Mesh (`UStaticMeshComponent`)** :
   - Closed 2-manifold surface (e.g. Cube-Sphere or LOD0 surface).
   - Nanite enabled (`NaniteSettings.bEnabled = true`).
   - Profile `NoCollision`, `bNeverNeedsCookedCollisionData = true` to eliminate Chaos physics overhead.
2. **Local Physical & Excavation Chunks (`UProceduralMeshComponent`)** :
   - Dynamic local voxel chunks extracted near the player.
   - Hidden by default in Nanite mode (`bHideProceduralRendering = true`).
   - Active Chaos physics trimesh collision (`bEnableChunkCollision = true`).
   - Dynamically shown when carved/modified to display real-time excavations.

## 3. FMeshDescription Construction Guide
```cpp
// 1. Module dependencies in Build.cs:
// "MeshDescription", "StaticMeshDescription"

// 2. Setup MeshDescription:
FMeshDescription MeshDescription;
MeshDescription.SetNumUVChannels(1);

FStaticMeshAttributes Attributes(MeshDescription);
Attributes.Register();

// 3. Populate positions, vertex instances, normals, tangents, UVs, colors:
TVertexAttributesRef<FVector3f> Positions = Attributes.GetVertexPositions();
TVertexInstanceAttributesRef<FVector3f> Normals = Attributes.GetVertexInstanceNormals();
TVertexInstanceAttributesRef<FVector3f> Tangents = Attributes.GetVertexInstanceTangents();
TVertexInstanceAttributesRef<float> BinormalSigns = Attributes.GetVertexInstanceBinormalSigns();
TVertexInstanceAttributesRef<FVector2f> UVs = Attributes.GetVertexInstanceUVs();
TVertexInstanceAttributesRef<FVector4f> Colors = Attributes.GetVertexInstanceColors();

// 4. Critical: Compute triangle tangents and normals before build:
FStaticMeshOperations::ComputeTriangleTangentsAndNormals(MeshDescription, 0.0f);

// 5. Build StaticMesh (under WITH_EDITOR):
StaticMesh->GetNaniteSettings().bEnabled = true;
StaticMesh->CreateMeshDescription(0, MeshDescription);
StaticMesh->CommitMeshDescription(0, CommitParams);
StaticMesh->Build(BuildParams);
```
