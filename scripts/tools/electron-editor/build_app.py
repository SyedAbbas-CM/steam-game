#!/usr/bin/env python3
"""
Build the LoY World Editor Electron app.
1. Bakes world data into the HTML template
2. Copies assets into the Electron app/ folder
3. Installs npm deps if needed
4. Packages with electron-builder

Usage: python3 build_app.py [--no-package]
  --no-package  Skip electron-builder, just bake + copy (for quick testing with npm start)
"""

import os
import sys
import shutil
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.dirname(SCRIPT_DIR)
APP_DIR = os.path.join(SCRIPT_DIR, 'app')

# Add tools dir so we can import bake_editor_data
sys.path.insert(0, TOOLS_DIR)


def bake_data():
    """Run the bake pipeline to generate HTML + sprites."""
    print("=== Step 1: Baking world data ===")
    from bake_editor_data import bake_world_data, TEMPLATE_PATH, DIST_DIR, SPRITES_DIR
    import json

    data = bake_world_data()
    json_str = json.dumps(data, separators=(',', ':'))
    print(f"JSON data: {len(json_str) // 1024} KB")

    # Read template
    with open(TEMPLATE_PATH, 'r') as f:
        html = f.read()

    html = html.replace('/*__WORLD_DATA__*/', f'const WORLD_DATA = {json_str};', 1)

    # Write to app/index.html
    os.makedirs(APP_DIR, exist_ok=True)
    out_html = os.path.join(APP_DIR, 'index.html')
    with open(out_html, 'w') as f:
        f.write(html)
    print(f"Wrote {out_html} ({os.path.getsize(out_html) // 1024} KB)")

    # Copy sprites
    for sprite in ['maptiles.png', 'chars.png', 'chars2.png']:
        src = os.path.join(SPRITES_DIR, sprite)
        dst = os.path.join(APP_DIR, sprite)
        if os.path.exists(src):
            shutil.copy2(src, dst)
            print(f"Copied {sprite}")
        else:
            print(f"WARNING: {src} not found")


def install_deps():
    """Install npm dependencies if needed."""
    node_modules = os.path.join(SCRIPT_DIR, 'node_modules')
    if not os.path.exists(node_modules):
        print("\n=== Step 2: Installing npm dependencies ===")
        subprocess.run(['npm', 'install'], cwd=SCRIPT_DIR, check=True)
    else:
        print("\n=== Step 2: npm deps already installed ===")


def package_app():
    """Build distributable with electron-builder."""
    print("\n=== Step 3: Packaging with electron-builder ===")
    subprocess.run(['npx', 'electron-builder', '--mac', '--win'], cwd=SCRIPT_DIR, check=True)
    dist_dir = os.path.join(SCRIPT_DIR, 'dist')
    print(f"\nDone! Distributables in: {dist_dir}")
    # List output
    for root, dirs, files in os.walk(dist_dir):
        for f in files:
            fp = os.path.join(root, f)
            size = os.path.getsize(fp) // (1024 * 1024)
            print(f"  {os.path.relpath(fp, dist_dir)} ({size} MB)")


if __name__ == '__main__':
    skip_package = '--no-package' in sys.argv

    bake_data()
    install_deps()

    if skip_package:
        print("\nSkipped packaging. Run 'npm start' to test locally:")
        print(f"  cd {SCRIPT_DIR} && npm start")
    else:
        package_app()
