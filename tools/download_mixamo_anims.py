#!/usr/bin/env python3
"""Download Mixamo animations for Y Bot via the Mixamo API."""

import json
import os
import sys
import time
import urllib.request
import urllib.error

TOKEN = sys.argv[1] if len(sys.argv) > 1 else ""
if not TOKEN:
    print("Usage: python3 download_mixamo_anims.py <access_token>")
    sys.exit(1)

CHARACTER_ID = "4f5d21e1-4ccc-41f1-b35b-fb2547bd8493"  # Y Bot

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "X-Api-Key": "mixamo2",
    "Accept": "application/json",
    "Content-Type": "application/json",
}

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "models", "ybot")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# (search_query, preferred_name_match, filename, description)
ANIMATIONS = [
    ("breathing idle", None, "idle.fbx", "Idle"),
    ("walking", "Walking", "walk.fbx", "Walking"),
    ("running", "Running", "run.fbx", "Running"),
    ("dying", None, "death.fbx", "Dying/Death"),
    ("hit reaction", None, "hit_reaction.fbx", "Hit Reaction"),
    ("cross punch", None, "attack.fbx", "Attack/Punch"),
]


def api_get(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def api_post(url, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method="POST")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def get_animation_details(product_id):
    """Get full animation details including the numeric model-id and params."""
    url = f"https://www.mixamo.com/api/v1/products/{product_id}?similar=0&character_id={CHARACTER_ID}"
    return api_get(url)


def search_animation(query, preferred_name=None):
    """Search for an animation and return the best match's product details."""
    url = f"https://www.mixamo.com/api/v1/products?page=1&limit=20&query={urllib.request.quote(query)}&type=Motion,MotionPack"
    data = api_get(url)
    results = data.get("results", [])
    if not results:
        return None

    # Try to find preferred name match first
    if preferred_name:
        for r in results:
            if r.get("name", "").lower() == preferred_name.lower():
                return get_animation_details(r["id"])

    # Fall back to first result
    return get_animation_details(results[0]["id"])


def export_animation(anim_details):
    """Request an FBX export of the animation applied to Y Bot."""
    details = anim_details.get("details", {})
    gms = details.get("gms_hash", {})

    # Build params string from the parameter array
    params_array = gms.get("params", [])
    param_values = ",".join(str(p[1]) for p in params_array) if params_array else "0"

    export_body = {
        "character_id": CHARACTER_ID,
        "gms_hash": [
            {
                "model-id": gms.get("model-id", 0),
                "mirror": gms.get("mirror", False),
                "trim": gms.get("trim", [0, 100]),
                "inplace": gms.get("inplace", False),
                "arm-space": gms.get("arm-space", 0),
                "params": param_values,
                "overdrive": 0,
            }
        ],
        "preferences": {
            "format": "fbx7",
            "skin": "true",
            "fps": "60",
            "reducekf": "0",
        },
        "type": "Motion",
        "product_name": anim_details.get("name", "animation"),
    }

    return api_post("https://www.mixamo.com/api/v1/animations/export", export_body)


def poll_download(max_wait=120):
    """Poll the monitor endpoint until the export is ready."""
    url = f"https://www.mixamo.com/api/v1/characters/{CHARACTER_ID}/monitor"
    start = time.time()
    while time.time() - start < max_wait:
        data = api_get(url)
        status = data.get("status", "")
        if status == "completed":
            return data.get("job_result", "")
        elif status == "failed":
            msg = data.get("job_result", {}).get("message", "Unknown error")
            print(f"  Export failed: {msg}")
            return None
        time.sleep(3)
    print("  Timed out waiting for export")
    return None


def download_file(url, filepath):
    """Download a file from URL."""
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as resp:
        with open(filepath, "wb") as f:
            while True:
                chunk = resp.read(8192)
                if not chunk:
                    break
                f.write(chunk)
    return os.path.getsize(filepath)


def main():
    print(f"Output: {OUTPUT_DIR}")
    print(f"Downloading {len(ANIMATIONS)} animations for Y Bot at 60 FPS\n")

    # Verify token
    print("Verifying API access...")
    try:
        test = api_get("https://www.mixamo.com/api/v1/characters?page=1&limit=1&type=Character")
        if isinstance(test, list):
            print(f"  API OK\n")
        else:
            print(f"  API OK\n")
    except urllib.error.HTTPError as e:
        print(f"  API error: {e.code} {e.reason}")
        if e.code == 401:
            print("  Token expired. Get a new one from mixamo.com console.")
        sys.exit(1)

    for query, preferred, filename, desc in ANIMATIONS:
        filepath = os.path.join(OUTPUT_DIR, filename)
        print(f"[{desc}] Searching '{query}'...")

        anim = search_animation(query, preferred)
        if not anim:
            print(f"  No results, skipping.\n")
            continue

        gms = anim.get("details", {}).get("gms_hash", {})
        print(f"  Found: {anim['name']} (model-id: {gms.get('model-id', '?')})")
        print(f"  Exporting (FBX, 60fps)...")

        try:
            export_animation(anim)
        except urllib.error.HTTPError as e:
            body = e.read().decode() if e.fp else ""
            print(f"  Export failed: {e.code} {body[:200]}\n")
            continue

        download_url = poll_download()
        if not download_url:
            print(f"  No download URL, skipping.\n")
            continue

        print(f"  Downloading {filename}...")
        size = download_file(download_url, filepath)
        print(f"  Saved {filename} ({size / 1024:.0f} KB)\n")

    print("Done!\n\nFiles in ybot/:")
    for f in sorted(os.listdir(OUTPUT_DIR)):
        fpath = os.path.join(OUTPUT_DIR, f)
        print(f"  {f} ({os.path.getsize(fpath) / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
