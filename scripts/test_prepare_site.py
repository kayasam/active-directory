"""Regression checks for installing generated content without directory renames."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('prepare_site', Path(__file__).with_name('prepare-site.py'))
prepare_site = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare_site)


class InstallContentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        root_patch = patch.object(prepare_site, 'ROOT', self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)
        self.stage = self.root/'.template-stage'
        self.stage.mkdir()
        (self.stage/'.generated-template').write_text('1\n')
        (self.stage/'index.md').write_text('new')
        self.target = self.root/'content'

    def test_missing_target_and_repeated_install_without_rename(self):
        with patch.object(Path, 'rename', side_effect=PermissionError('Windows directory lock')):
            prepare_site.install_content(self.stage, self.target)
            (self.target/'private').mkdir()
            (self.target/'private/correction.md').write_text('unpublished')
            (self.target/'index.md').write_text('old')
            prepare_site.install_content(self.stage, self.target)
        self.assertEqual((self.target/'index.md').read_text(), 'new')
        self.assertFalse((self.target/'private').exists())

    def test_unmarked_content_is_preserved(self):
        self.target.mkdir()
        (self.target/'notes.md').write_text('manual')
        with self.assertRaises(AssertionError):
            prepare_site.install_content(self.stage, self.target)
        self.assertEqual((self.target/'notes.md').read_text(), 'manual')
        self.assertFalse((self.target/'index.md').exists())

    def test_copy_failure_does_not_delete_previous_content(self):
        prepare_site.install_content(self.stage, self.target)
        (self.target/'previous.md').write_text('previous')
        with patch.object(prepare_site.shutil, 'copytree', side_effect=PermissionError('locked file')):
            with self.assertRaises(PermissionError):
                prepare_site.install_content(self.stage, self.target)
        self.assertTrue((self.target/'previous.md').is_file())

    def test_stage_cleanup_keeps_directory(self):
        (self.stage/'nested').mkdir()
        (self.stage/'nested/old.md').write_text('old')
        prepare_site.clean(self.stage)
        self.assertTrue(self.stage.is_dir())
        self.assertEqual(list(self.stage.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
