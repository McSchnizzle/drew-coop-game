"""
Text-to-3D model generator — free, no account needed.
Uses Hunyuan3D-2 (Tencent) on HuggingFace for text-to-3D generation.

Usage:
    python tools/generate_3d.py "prompt here" output_name

Example:
    python tools/generate_3d.py "Futuristic cyberpunk soldier, sleek blue armor" striker

Outputs a .glb file in game/assets/models/ ready for Godot import.
"""
import sys
import os
import shutil

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "game", "assets", "models")

MESH_SPACE = "tencent/Hunyuan3D-2"

def main():
    if len(sys.argv) < 3:
        print("Usage: python tools/generate_3d.py \"prompt\" output_name")
        print('Example: python tools/generate_3d.py "Futuristic soldier" striker')
        sys.exit(1)

    prompt = sys.argv[1]
    name = sys.argv[2]
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, f"{name}.glb")

    from gradio_client import Client

    # Step 1: Text → 3D mesh via Hunyuan3D-2 (Turbo mode: ~10 steps)
    print(f"[1/2] Generating 3D model from text (this takes 1-3 minutes)...")
    print(f"  Prompt: {prompt[:100]}...")
    mesh_client = Client(MESH_SPACE)

    mesh_file, texture_file, html_output, mesh_stats, seed = mesh_client.predict(
        caption=prompt,
        steps=10,
        guidance_scale=5.0,
        seed=1234,
        octree_resolution=256,
        check_box_rembg=True,
        num_chunks=8000,
        randomize_seed=False,
        api_name="/generation_all"
    )
    print(f"  Mesh generated: {mesh_file}")

    # Step 2: Export as GLB with textures
    print(f"[2/2] Exporting as textured GLB...")
    html_result, glb_path = mesh_client.predict(
        file_out=mesh_file,
        file_out2=texture_file,
        file_type="glb",
        reduce_face=False,
        export_texture=True,
        target_face_num=50000,
        api_name="/on_export_click"
    )
    print(f"  GLB exported: {glb_path}")

    # Copy to project
    shutil.copy2(glb_path, output_path)
    file_size = os.path.getsize(output_path)
    print(f"\nDone! Saved {name}.glb ({file_size / 1024:.0f} KB) to {output_path}")

if __name__ == "__main__":
    main()
