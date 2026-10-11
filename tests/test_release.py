# SPDX-License-Identifier: GPL-3.0-or-later
import unittest
from tools.release import Version, plan_automated_release, plan_tag, validate_release_notes


class ReleaseTests(unittest.TestCase):
    def test_only_patch_advance_can_be_automatically_published(self):
        self.assertEqual('v0.1.1', plan_automated_release('0.1.0', '0.1.1', release_content_changed=True))
        for version in ('0.1.0', '0.1.2', '0.2.0'):
            with self.assertRaises(ValueError):
                plan_automated_release('0.1.0', version, release_content_changed=True)
        self.assertIsNone(plan_automated_release('0.1.0', '0.1.0', release_content_changed=False))

    def test_existing_tag_cannot_be_moved(self):
        self.assertEqual('create', plan_tag(None, 'aaa'))
        self.assertEqual('reuse', plan_tag('aaa', 'aaa'))
        with self.assertRaises(ValueError):
            plan_tag('bbb', 'aaa')

    def test_notes_require_current_version_only(self):
        version = Version.parse('0.1.0')
        validate_release_notes('## 0.1.0 - 2026-10-10\n\n- Mana display.\n', version)
        for notes in ('## 0.1.1\n', '## 0.1.0\n\n## 0.0.1\n', '## 0.1.0\nuser@example.com'):
            with self.assertRaises(ValueError):
                validate_release_notes(notes, version)
