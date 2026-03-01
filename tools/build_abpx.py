#!/usr/bin/env python3
"""
build_abpx.py — ArcOS Bundle Package eXchange builder
Packages ArcOS engines, manifests, playbooks, and config into a .abpx file.

Usage:
    python tools/build_abpx.py --playbook gaming --output dist/arc-gaming.abpx
    python tools/build_abpx.py --all --output dist/arc-full.abpx
    python tools/build_abpx.py --playbook balanced  # outputs dist/<playbook>.abpx
"""

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def find_root() -> Path:
    """Walk up from tools/ to find the project root (contains config.json)."""
    here = Path(__file__).resolve().parent
    for candidate in [here, here.parent]:
        if (candidate / "config.json").exists():
            return candidate
    print("ERROR: Could not find ArcOS project root (config.json not found).")
    sys.exit(1)


def color(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m"


def ok(msg):   print(color(f"  ✓  {msg}", "32"))
def info(msg): print(color(f"  →  {msg}", "36"))
def warn(msg): print(color(f"  ⚠  {msg}", "33"))
def fail(msg): print(color(f"  ✗  {msg}", "31")); sys.exit(1)


# ─────────────────────────────────────────────
# Core build logic
# ─────────────────────────────────────────────

ENGINE_NAME_MAP = {
    "ServiceEngine":     "service-engine.ps1",
    "TaskEngine":        "task-engine.ps1",
    "AppxEngine":        "appx-engine.ps1",
    "RegistryEngine":    "registry-engine.ps1",
    "PolicyEngine":      "policy-engine.ps1",
    "PerformanceEngine": "performance-engine.ps1",
    "UIEngine":          "ui-engine.ps1",
    "WallpaperEngine":   "wallpaper-engine.ps1",
    "AvatarEngine":      "avatar-engine.ps1",
    "OneDriveEngine":    "onedrive-engine.ps1",
    "EdgeEngine":        "edge-engine.ps1",
    "NetworkEngine":     "network-engine.ps1",
    "GamingEngine":      "gaming-engine.ps1",
}

ALWAYS_INCLUDE_ENGINES = [
    "logger.ps1",
    "precheck.ps1",
    "postcheck.ps1",
    "rollback.ps1",
]

MANIFESTS = [
    "registry.json",
    "policies.json",
    "tasks.json",
    "services.json",
    "appx.json",
]


def load_playbook(root: Path, name: str) -> dict:
    path = root / "playbooks" / f"{name}.json"
    if not path.exists():
        fail(f"Playbook not found: {path}")
    with open(path) as f:
        data = json.load(f)
    data["_filename"] = name
    return data


def load_all_playbooks(root: Path) -> list[dict]:
    playbooks = []
    for p in (root / "playbooks").glob("*.json"):
        with open(p) as f:
            data = json.load(f)
        data["_filename"] = p.stem
        playbooks.append(data)
    return playbooks


def build(root: Path, playbooks: list[dict], output: Path, author: str):
    print()
    print(color("  ┌─────────────────────────────────────┐", "35"))
    print(color("  │   ArcOS ABPX Builder                │", "35"))
    print(color("  └─────────────────────────────────────┘", "35"))
    print()

    output.parent.mkdir(parents=True, exist_ok=True)

    # Collect all engines needed by the selected playbooks
    engines_needed = set()
    for pb in playbooks:
        for eng in pb.get("engines", []):
            engines_needed.add(eng)

    info(f"Playbooks included: {', '.join(pb['_filename'] for pb in playbooks)}")
    info(f"Engines to pack:    {', '.join(sorted(engines_needed))}")

    # Build file inventory with checksums
    file_index = []

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        zip_path = tmp / "bundle.zip"

        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:

            # ── Core engine helpers (always included) ──
            for fname in ALWAYS_INCLUDE_ENGINES:
                src = root / "engine" / fname
                if src.exists():
                    arcname = f"engines/{fname}"
                    zf.write(src, arcname)
                    file_index.append({"path": arcname, "sha256": sha256(src)})
                    ok(f"engines/{fname}")
                else:
                    warn(f"Missing helper engine: {fname}")

            # ── Playbook engines ──
            for eng_name in sorted(engines_needed):
                fname = ENGINE_NAME_MAP.get(eng_name)
                if not fname:
                    warn(f"No file mapping for engine: {eng_name}")
                    continue
                src = root / "engine" / fname
                if src.exists():
                    arcname = f"engines/{fname}"
                    if arcname not in [f["path"] for f in file_index]:
                        zf.write(src, arcname)
                        file_index.append({"path": arcname, "sha256": sha256(src)})
                        ok(f"engines/{fname}")
                else:
                    warn(f"Engine file missing: {src}")

            # ── Engine manifest ──
            src = root / "engine" / "engine.manifest.json"
            if src.exists():
                zf.write(src, "engines/engine.manifest.json")
                file_index.append({"path": "engines/engine.manifest.json", "sha256": sha256(src)})
                ok("engines/engine.manifest.json")

            # ── Manifests (data) ──
            for mname in MANIFESTS:
                src = root / "manifests" / mname
                if src.exists():
                    arcname = f"manifests/{mname}"
                    zf.write(src, arcname)
                    file_index.append({"path": arcname, "sha256": sha256(src)})
                    ok(f"manifests/{mname}")
                else:
                    warn(f"Manifest missing: {mname}")

            # ── Playbooks ──
            for pb in playbooks:
                src = root / "playbooks" / f"{pb['_filename']}.json"
                arcname = f"playbooks/{pb['_filename']}.json"
                zf.write(src, arcname)
                file_index.append({"path": arcname, "sha256": sha256(src)})
                ok(f"playbooks/{pb['_filename']}.json")

            # ── config.json ──
            src = root / "config.json"
            if src.exists():
                zf.write(src, "config.json")
                file_index.append({"path": "config.json", "sha256": sha256(src)})
                ok("config.json")

            # ── ABPX Manifest header ──
            pb_names  = [pb.get("name", pb["_filename"]) for pb in playbooks]
            pb_files  = [pb["_filename"] for pb in playbooks]
            manifest = {
                "abpx_version": "1.0",
                "name": f"ArcOS — {', '.join(pb_names)}",
                "description": "; ".join(
                    pb.get("description", pb.get("name", pb["_filename"])) for pb in playbooks
                ),
                "author": author,
                "built_at": datetime.now(timezone.utc).isoformat(),
                "playbooks": pb_files,
                "engines": sorted(engines_needed),
                "files": file_index,
                "stats": {
                    "engine_files": len([f for f in file_index if f["path"].startswith("engines/")]),
                    "manifest_files": len([f for f in file_index if f["path"].startswith("manifests/")]),
                    "total_files": len(file_index),
                },
            }
            manifest_bytes = json.dumps(manifest, indent=2).encode()
            zf.writestr("arcos.manifest.json", manifest_bytes)
            ok("arcos.manifest.json")

        # Move ZIP → .abpx
        shutil.copy2(zip_path, output)

    size_kb = output.stat().st_size // 1024
    print()
    print(color(f"  ┌─────────────────────────────────────────────────┐", "32"))
    print(color(f"  │  Bundle built successfully!                     │", "32"))
    print(color(f"  │                                                 │", "32"))
    print(color(f"  │  Output : {str(output):<38} │", "32"))
    print(color(f"  │  Size   : {size_kb} KB{' ' * (37 - len(str(size_kb)))} │", "32"))
    print(color(f"  │  Files  : {manifest['stats']['total_files']}{' ' * (38 - len(str(manifest['stats']['total_files'])))} │", "32"))
    print(color(f"  └─────────────────────────────────────────────────┘", "32"))
    print()


# ─────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Build an ArcOS .abpx bundle",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python tools/build_abpx.py --playbook gaming
  python tools/build_abpx.py --playbook balanced --output dist/arc-balanced.abpx
  python tools/build_abpx.py --all --output dist/arc-full.abpx
  python tools/build_abpx.py --playbook privacy --author "Your Name"
        """
    )
    parser.add_argument("--playbook", "-p", metavar="NAME",
                        help="Playbook to bundle (balanced, gaming, privacy, stable, aggressive)")
    parser.add_argument("--all", "-a", action="store_true",
                        help="Bundle all available playbooks")
    parser.add_argument("--output", "-o", metavar="PATH",
                        help="Output .abpx path (default: dist/<playbook>.abpx)")
    parser.add_argument("--author", metavar="NAME", default="ArcOS",
                        help="Author name embedded in bundle metadata (default: ArcOS)")
    parser.add_argument("--root", metavar="PATH",
                        help="ArcOS project root (auto-detected if omitted)")

    args = parser.parse_args()

    if not args.playbook and not args.all:
        parser.error("Specify --playbook <name> or --all")

    root = Path(args.root).resolve() if args.root else find_root()
    info(f"Project root: {root}")

    # Load playbooks
    if args.all:
        playbooks = load_all_playbooks(root)
        if not playbooks:
            fail("No playbooks found in playbooks/")
        default_out = root / "dist" / "arc-full.abpx"
    else:
        playbooks = [load_playbook(root, args.playbook)]
        default_out = root / "dist" / f"arc-{args.playbook}.abpx"

    output = Path(args.output).resolve() if args.output else default_out

    build(root, playbooks, output, args.author)


if __name__ == "__main__":
    main()
