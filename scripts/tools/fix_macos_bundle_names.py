#!/usr/bin/env python3
from __future__ import annotations

import plistlib
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: fix_macos_bundle_names.py <app_bundle> <base_name>", file=sys.stderr)
        return 2

    app_bundle = Path(sys.argv[1])
    base_name = sys.argv[2]

    contents = app_bundle / "Contents"
    macos_dir = contents / "MacOS"
    resources_dir = contents / "Resources"
    info_plist = contents / "Info.plist"

    if not contents.is_dir() or not macos_dir.is_dir() or not resources_dir.is_dir() or not info_plist.is_file():
        print(f"invalid app bundle: {app_bundle}", file=sys.stderr)
        return 1

    executables = [p for p in macos_dir.iterdir() if p.is_file() and p.name != ".DS_Store"]
    if len(executables) != 1:
        print(f"expected exactly one executable in {macos_dir}, found {len(executables)}", file=sys.stderr)
        return 1

    executable = executables[0]
    pcks = [p for p in resources_dir.iterdir() if p.suffix == ".pck"]
    if len(pcks) != 1:
        print(f"expected exactly one .pck in {resources_dir}, found {len(pcks)}", file=sys.stderr)
        return 1

    pck = pcks[0]
    target_executable = macos_dir / base_name
    target_pck = resources_dir / f"{base_name}.pck"

    if executable != target_executable:
        if target_executable.exists():
            target_executable.unlink()
        executable.rename(target_executable)
    if pck != target_pck:
        if target_pck.exists():
            target_pck.unlink()
        pck.rename(target_pck)

    with info_plist.open("rb") as fh:
        data = plistlib.load(fh)
    data["CFBundleExecutable"] = base_name
    data["CFBundleName"] = base_name
    data["CFBundleDisplayName"] = base_name
    with info_plist.open("wb") as fh:
        plistlib.dump(data, fh, sort_keys=False)

    print(f"normalized macOS bundle names for {app_bundle} -> {base_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
