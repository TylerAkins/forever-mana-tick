#!/usr/bin/env python3
"""Tests for the local addon compiler and installer."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "compile_addon.py"
SPEC = importlib.util.spec_from_file_location("compile_addon", SCRIPT)
assert SPEC and SPEC.loader
COMPILE_ADDON = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPILE_ADDON)


class CompileAddonTests(unittest.TestCase):
    def test_build_is_clean_and_installable(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "ForeverManaTick"
            stale = output / "stale.txt"
            stale.parent.mkdir(parents=True)
            stale.write_text("remove me", encoding="utf-8")

            built = COMPILE_ADDON.compile_addon(output)

            self.assertFalse(stale.exists())
            self.assertIn(output / "ForeverManaTick.toc", built)
            self.assertIn(output / "ForeverManaTick.lua", built)
            self.assertTrue((output / "README.md").is_file())
            self.assertFalse((output / "VERSION").exists())
            self.assertNotIn(
                "@project-version@",
                (output / "ForeverManaTick.toc").read_text(encoding="utf-8"),
            )

    def test_dry_run_does_not_replace_existing_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "ForeverManaTick"
            stale = output / "stale.txt"
            stale.parent.mkdir(parents=True)
            stale.write_text("keep me", encoding="utf-8")

            built = COMPILE_ADDON.compile_addon(output, dry_run=True)

            self.assertTrue(stale.exists())
            self.assertIn(output / "ForeverManaTick.toc", built)

    def test_every_toc_entry_is_shipped(self) -> None:
        toc = (ROOT / "ForeverManaTick.toc").read_text(encoding="utf-8")
        entries = [
            line.strip().replace("\\", "/")
            for line in toc.splitlines()
            if line.strip() and not line.startswith("#")
        ]
        shipped = {
            path.relative_to(ROOT).as_posix() for path in COMPILE_ADDON.iter_files()
        }
        for entry in entries:
            self.assertIn(entry, shipped, f"{entry} is in the TOC but not built")

    def test_install_replaces_only_addon_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            build = Path(temp_dir) / "build" / "ForeverManaTick"
            addons = Path(temp_dir) / "AddOns"
            installed = addons / "ForeverManaTick"
            unrelated = addons / "SomeOtherAddon" / "keep.txt"
            unrelated.parent.mkdir(parents=True)
            unrelated.write_text("keep", encoding="utf-8")
            installed.mkdir(parents=True)
            (installed / "stale.txt").write_text("remove", encoding="utf-8")

            COMPILE_ADDON.compile_addon(build)
            COMPILE_ADDON.install_addon(build, addons)

            self.assertFalse((installed / "stale.txt").exists())
            self.assertTrue((installed / "ForeverManaTick.toc").is_file())
            self.assertEqual(unrelated.read_text(encoding="utf-8"), "keep")

    def test_install_cli_uses_selected_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / ".compiled" / "ForeverManaTick"
            addons = Path(temp_dir) / "client" / "Interface" / "AddOns"
            actual_compile_addon = COMPILE_ADDON.compile_addon
            compile_into_output = lambda output_dir=None, dry_run=False: actual_compile_addon(
                output, dry_run=dry_run
            )
            with patch.object(COMPILE_ADDON, "ADDON_DIR", output), patch.object(
                COMPILE_ADDON, "default_addons_dir", return_value=addons
            ), patch.object(COMPILE_ADDON, "compile_addon", side_effect=compile_into_output), patch(
                "sys.argv", [str(SCRIPT), "--install"]
            ):
                COMPILE_ADDON.main()

            self.assertTrue((addons / "ForeverManaTick" / "ForeverManaTick.toc").is_file())


if __name__ == "__main__":
    unittest.main()
