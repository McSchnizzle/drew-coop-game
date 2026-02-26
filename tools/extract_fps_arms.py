"""
Blender Python Script: Extract FPS Arms from Mixamo Character
=============================================================
Opens a Mixamo-rigged FBX (Pete or Striker), deletes all geometry
except the arms/hands/fingers, keeps the full skeleton intact so
animations still work, and exports as a new FBX.

HOW TO USE:
1. Open Blender (any version 3.x or 4.x)
2. Go to the Scripting workspace tab (top bar)
3. Click "New" to create a new text block
4. Paste this entire script
5. Change INPUT_FBX and OUTPUT_FBX paths below if needed
6. Click "Run Script" (or press Alt+P)
7. The arms-only FBX will be saved to OUTPUT_FBX
8. Repeat with the other character model (change paths)

The script runs TWICE — once for Pete, once for Striker.
"""

import bpy
import os

# ── CONFIGURATION ────────────────────────────────────────────────────────
# Change these paths to match your system:
PROJECT_DIR = "/Users/drewdavid/coding-projects/multiplayer-game/game/assets/models"

MODELS = [
    {
        "input": os.path.join(PROJECT_DIR, "pete", "pete.fbx"),
        "output": os.path.join(PROJECT_DIR, "pete", "pete_arms.fbx"),
    },
    {
        "input": os.path.join(PROJECT_DIR, "striker", "striker.fbx"),
        "output": os.path.join(PROJECT_DIR, "striker", "striker_arms.fbx"),
    },
]

# Vertex groups (bone names) to KEEP. Everything else gets deleted.
# These are the Mixamo bone names (with common prefixes stripped).
# The script handles mixamorig: / mixamorig1_ prefixes automatically.
WEIGHT_THRESHOLD = 0.25  # Only keep vertices strongly weighted to arm bones

KEEP_BONES = {
    "leftarm", "leftforearm", "lefthand",
    "rightarm", "rightforearm", "righthand",
    # All finger bones
    "lefthandthumb1", "lefthandthumb2", "lefthandthumb3", "lefthandthumb4",
    "lefthandindex1", "lefthandindex2", "lefthandindex3", "lefthandindex4",
    "lefthandmiddle1", "lefthandmiddle2", "lefthandmiddle3", "lefthandmiddle4",
    "lefthandring1", "lefthandring2", "lefthandring3", "lefthandring4",
    "lefthandpinky1", "lefthandpinky2", "lefthandpinky3", "lefthandpinky4",
    "righthandthumb1", "righthandthumb2", "righthandthumb3", "righthandthumb4",
    "righthandindex1", "righthandindex2", "righthandindex3", "righthandindex4",
    "righthandmiddle1", "righthandmiddle2", "righthandmiddle3", "righthandmiddle4",
    "righthandring1", "righthandring2", "righthandring3", "righthandring4",
    "righthandpinky1", "righthandpinky2", "righthandpinky3", "righthandpinky4",
}

# ── HELPER FUNCTIONS ─────────────────────────────────────────────────────

def strip_mixamo_prefix(name):
    """Strip mixamorig: or mixamorig1_ prefix from bone name."""
    lower = name.lower()
    for prefix in ["mixamorig:", "mixamorig1_", "mixamorig_", "mixamorig1:"]:
        if lower.startswith(prefix):
            return name[len(prefix):]
    return name


def is_arm_bone(bone_name):
    """Check if a bone name (after prefix stripping) is in our keep list."""
    base = strip_mixamo_prefix(bone_name).lower()
    return base in KEEP_BONES


def clear_scene():
    """Delete everything in the scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # Also purge orphan data
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.armatures:
        if block.users == 0:
            bpy.data.armatures.remove(block)


def process_model(input_fbx, output_fbx):
    """Import FBX, delete non-arm vertices, export arms-only FBX."""
    print(f"\n{'='*60}")
    print(f"Processing: {input_fbx}")
    print(f"Output:     {output_fbx}")
    print(f"{'='*60}")

    # Clear scene
    clear_scene()

    # Import FBX
    bpy.ops.import_scene.fbx(filepath=input_fbx)
    print(f"Imported {input_fbx}")

    # Find the armature and mesh objects
    armature = None
    mesh_objects = []
    for obj in bpy.context.scene.objects:
        if obj.type == 'ARMATURE':
            armature = obj
        elif obj.type == 'MESH':
            mesh_objects.append(obj)

    if not armature:
        print("ERROR: No armature found in FBX!")
        return False

    print(f"Found armature: {armature.name}")
    print(f"Found {len(mesh_objects)} mesh object(s)")
    print(f"Total bones: {len(armature.data.bones)}")

    # List all bones and which ones we're keeping
    arm_bones = []
    other_bones = []
    for bone in armature.data.bones:
        if is_arm_bone(bone.name):
            arm_bones.append(bone.name)
        else:
            other_bones.append(bone.name)

    print(f"Keeping {len(arm_bones)} arm bones: {arm_bones[:6]}...")
    print(f"Hiding {len(other_bones)} other bones: {other_bones[:6]}...")

    # For each mesh, delete vertices that are NOT weighted to arm bones
    for mesh_obj in mesh_objects:
        print(f"\nProcessing mesh: {mesh_obj.name}")
        print(f"  Vertices before: {len(mesh_obj.data.vertices)}")

        # Build set of vertex group indices that correspond to arm bones
        arm_vgroup_indices = set()
        for vg in mesh_obj.vertex_groups:
            if is_arm_bone(vg.name):
                arm_vgroup_indices.add(vg.index)

        print(f"  Arm vertex groups: {len(arm_vgroup_indices)}")

        if not arm_vgroup_indices:
            print(f"  No arm vertex groups — deleting entire mesh: {mesh_obj.name}")
            bpy.data.objects.remove(mesh_obj, do_unlink=True)
            continue

        # Find vertices to delete (not strongly weighted to any arm bone)
        verts_to_delete = []
        for vert in mesh_obj.data.vertices:
            dominated_by_arm = False
            for g in vert.groups:
                if g.group in arm_vgroup_indices and g.weight > WEIGHT_THRESHOLD:
                    dominated_by_arm = True
                    break
            if not dominated_by_arm:
                verts_to_delete.append(vert.index)

        print(f"  Vertices to delete: {len(verts_to_delete)}")
        print(f"  Vertices to keep: {len(mesh_obj.data.vertices) - len(verts_to_delete)}")

        if len(verts_to_delete) == 0:
            print("  Nothing to delete, skipping.")
            continue

        # Select and delete non-arm vertices
        bpy.context.view_layer.objects.active = mesh_obj
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='DESELECT')
        bpy.ops.object.mode_set(mode='OBJECT')

        for idx in verts_to_delete:
            mesh_obj.data.vertices[idx].select = True

        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.delete(type='VERT')

        # Cap open holes left by the cut (select boundary edges and fill)
        bpy.ops.mesh.select_all(action='DESELECT')
        bpy.ops.mesh.select_non_manifold(extend=False)
        bpy.ops.mesh.fill()
        print("  Capped open holes")

        bpy.ops.object.mode_set(mode='OBJECT')

        print(f"  Vertices after: {len(mesh_obj.data.vertices)}")

    # Export as FBX (keep full skeleton so animations still work)
    # Select all objects for export
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = armature

    # Make sure output directory exists
    os.makedirs(os.path.dirname(output_fbx), exist_ok=True)

    bpy.ops.export_scene.fbx(
        filepath=output_fbx,
        use_selection=True,
        object_types={'ARMATURE', 'MESH'},
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,  # Don't bake animations (we load them separately)
        path_mode='COPY',
        embed_textures=True,
    )

    print(f"\nExported arms-only model to: {output_fbx}")
    return True


# ── MAIN ─────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n" + "="*60)
    print("FPS Arms Extractor — Blender Script")
    print("="*60)

    for model in MODELS:
        if os.path.exists(model["input"]):
            success = process_model(model["input"], model["output"])
            if success:
                print(f"SUCCESS: {model['output']}")
            else:
                print(f"FAILED: {model['input']}")
        else:
            print(f"SKIPPED (file not found): {model['input']}")

    print("\n" + "="*60)
    print("DONE! Arms-only models exported.")
    print("Update player.gd ROLE_MODELS to use the new _arms.fbx files.")
    print("="*60)
