"""
Blend-to-GLB converter — run from terminal:
    python tools/blend_to_glb.py path/to/model.blend

Outputs a .glb file in game/assets/models/ ready for Godot import.
Uses Blender in headless mode (no GUI opens).
"""
import subprocess
import sys
import os

BLENDER_PATH = "/Applications/Blender.app/Contents/MacOS/Blender"
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "game", "assets", "models")

EXPORT_SCRIPT = '''
import bpy
import sys

output_path = sys.argv[sys.argv.index("--") + 1]

bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format='GLB',
    export_apply_modifiers=True,
    export_materials='EXPORT',
    export_texcoords=True,
    export_normals=True,
    export_colors=True,
)
print(f"Exported to: {output_path}")
'''

def main():
    if len(sys.argv) < 2:
        print("Usage: python tools/blend_to_glb.py <file.blend> [output_name]")
        sys.exit(1)

    blend_file = os.path.abspath(sys.argv[1])
    if not os.path.exists(blend_file):
        print(f"File not found: {blend_file}")
        sys.exit(1)

    # Output name: use provided name or derive from input filename
    if len(sys.argv) >= 3:
        name = sys.argv[2]
    else:
        name = os.path.splitext(os.path.basename(blend_file))[0]

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, f"{name}.glb")

    # Write temp export script
    script_path = os.path.join(OUTPUT_DIR, "_export_temp.py")
    with open(script_path, "w") as f:
        f.write(EXPORT_SCRIPT)

    # Run Blender headless
    cmd = [
        BLENDER_PATH,
        "--background",
        blend_file,
        "--python", script_path,
        "--", output_path,
    ]

    print(f"Converting {os.path.basename(blend_file)} → {name}.glb ...")
    result = subprocess.run(cmd, capture_output=True, text=True)

    # Cleanup temp script
    os.remove(script_path)

    if result.returncode != 0:
        print("Blender error:")
        print(result.stderr[-500:] if len(result.stderr) > 500 else result.stderr)
        sys.exit(1)

    print(f"Done! Saved to: {output_path}")

if __name__ == "__main__":
    main()
