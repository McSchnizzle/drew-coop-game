#!/usr/bin/env python3
"""Download animations from Mixamo API for a given character."""
import requests, time, os

API = "https://www.mixamo.com/api/v1"
KEY = "mixamo2"
BEARER = os.environ.get("MIXAMO_BEARER", "PASTE_TOKEN_HERE")  # Get from localStorage.access_token in browser console
HEADERS = {"X-Api-Key": KEY, "Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}

# System character ID (Y Bot - standard Mixamo humanoid)
CHAR_ID = "4f5d21e1-4ccc-41f1-b35b-c6377509eaac"

# Animations to download: local_name -> search query
ANIMS = {
    "pistol_idle": "Pistol Idle",
    "pistol_walk": "Walking With Pistol",
    "pistol_run": "Pistol Run",
    "pistol_shoot": "Firing Rifle",
}

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "models", "ybot")


def search_anim(query):
    r = requests.get(f"{API}/products", params={"page": 1, "limit": 5, "type": "Motion", "query": query}, headers=HEADERS)
    r.raise_for_status()
    results = r.json().get("results", [])
    return results[0] if results else None


def get_product_details(product_id):
    r = requests.get(f"{API}/products/{product_id}", params={"character_id": CHAR_ID}, headers=HEADERS)
    r.raise_for_status()
    return r.json()


def export_anim(product, details):
    gms = details.get("details", {}).get("gms_hash", {})
    # Convert params from [[name, val], ...] to comma-separated strings
    params_list = gms.get("params", [])
    param_names = ",".join(p[0] for p in params_list) if params_list else ""
    param_values = ",".join(str(p[1]) for p in params_list) if params_list else ""
    body = {
        "character_id": CHAR_ID,
        "gms_hash": [{
            "model-id": gms.get("model-id"),
            "mirror": gms.get("mirror", False),
            "trim": [0, 100],
            "overdrive": gms.get("overdrive", 0),
            "params": param_names,
            "param-values": param_values,
            "arm-space": gms.get("arm-space", 0),
            "inplace": gms.get("inplace", False),
        }],
        "preferences": {"format": "fbx7", "skin": "false", "fps": "30", "reducekf": "0"},
        "product_name": product["description"],
        "type": "Motion",
    }
    r = requests.post(f"{API}/animations/export", json=body, headers=HEADERS)
    r.raise_for_status()
    return r.json()


def wait_and_download(name):
    for _ in range(60):
        time.sleep(2)
        r = requests.get(f"{API}/characters/{CHAR_ID}/monitor", headers=HEADERS)
        r.raise_for_status()
        data = r.json()
        if data.get("status") == "completed":
            url = data.get("job_result")
            if url:
                print(f"  Downloading {name}...")
                dl = requests.get(url)
                dl.raise_for_status()
                path = os.path.join(OUT_DIR, f"{name}.fbx")
                with open(path, "wb") as f:
                    f.write(dl.content)
                print(f"  Saved: {path}")
                return True
        elif data.get("status") == "failed":
            print(f"  Export failed for {name}")
            return False
    print(f"  Timeout waiting for {name}")
    return False


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for local_name, query in ANIMS.items():
        print(f"\nSearching: {query}")
        product = search_anim(query)
        if not product:
            print(f"  Not found!")
            continue
        print(f"  Found: {product['description']} ({product['id']})")
        details = get_product_details(product["id"])
        print(f"  Exporting...")
        export_anim(product, details)
        wait_and_download(local_name)


if __name__ == "__main__":
    main()
