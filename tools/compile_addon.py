#!/usr/bin/env python3
"""Build and optionally install a clean local Forever Mana Tick addon."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD_ROOT = ROOT / ".compiled"
ADDON_DIR = BUILD_ROOT / "ForeverManaTick"
ROOT_FILES = (
    "ATTRIBUTION.md",
    "CHANGELOG.md",
    "ForeverManaTick.lua",
    "LICENSE",
    "README.md",
    "RELEASE_NOTES.md",
)
IGNORED_NAMES = {"build_report.json", ".DS_Store", "Thumbs.db", "__pycache__"}


def project_version() -> str:
    """Return a useful local version without requiring a tagged checkout."""
    result = subprocess.run(
        ["git", "describe", "--tags", "--always", "--dirty"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() or "local"


def iter_files() -> list[Path]:
    """Return the files shipped by the release package metadata."""
    files = [ROOT / name for name in ROOT_FILES]
    return sorted(files + [ROOT / "ForeverManaTick.toc"])


def compile_addon(output_dir: Path = ADDON_DIR, *, dry_run: bool = False) -> list[Path]:
    """Replace the local build with a clean installable addon tree."""
    files = iter_files()
    if dry_run:
        return [output_dir / path.relative_to(ROOT) for path in files]

    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)

    for source in files:
        destination = output_dir / source.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    toc = output_dir / "ForeverManaTick.toc"
    toc.write_text(
        toc.read_text(encoding="utf-8").replace("@project-version@", project_version()),
        encoding="utf-8",
    )
    return [output_dir / path.relative_to(ROOT) for path in files]


def default_addons_dir() -> Path:
    """Resolve the default Forever beta AddOns directory on this Mac."""
    configured = os.environ.get("WOW_FOREVER_ADDONS")
    if configured:
        return Path(configured).expanduser()

    candidates = (
        Path("/Applications/World of Warcraft/_classic_beta_/Interface/AddOns"),
        Path.home()
        / "Library/Application Support/World of Warcraft/_classic_beta_/Interface/AddOns",
    )
    for candidate in candidates:
        if candidate.parent.parent.parent.exists():
            return candidate
    return candidates[0]


def install_addon(build_dir: Path = ADDON_DIR, addons_dir: Path | None = None) -> Path:
    """Copy the built addon into the client's AddOns folder."""
    addons_dir = addons_dir or default_addons_dir()
    source = build_dir / "ForeverManaTick.toc"
    if not source.is_file():
        raise FileNotFoundError(f"Built addon TOC is missing: {source}")
    destination = addons_dir / "ForeverManaTick"
    if destination.exists():
        shutil.rmtree(destination)
    addons_dir.mkdir(parents=True, exist_ok=True)
    shutil.copytree(build_dir, destination)
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build .compiled/ForeverManaTick for local installation."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="list the output files without deleting or copying anything",
    )
    parser.add_argument(
        "--install",
        action="store_true",
        help="install the built addon into the Forever client's AddOns directory",
    )
    parser.add_argument(
        "--addons-dir",
        type=Path,
        help="override the client's Interface/AddOns directory (also via WOW_FOREVER_ADDONS)",
    )
    args = parser.parse_args()

    files = compile_addon(dry_run=args.dry_run)
    if args.dry_run:
        for path in files:
            print(path.relative_to(ROOT))
        return
    print(f"Built {len(files)} files in {ADDON_DIR}")
    if args.install:
        destination = install_addon(ADDON_DIR, args.addons_dir)
        print(f"Installed ForeverManaTick in {destination}")


if __name__ == "__main__":
    main()
