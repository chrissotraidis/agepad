"""Corruption/refusal tests for the optional backend's source-preservation boundary."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('metal_build', Path(__file__).resolve().parents[1] / 'scripts/build-metal.py')
metal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metal)

class MetalLockTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.old_root = metal.ROOT
        metal.ROOT = self.root
        self.patch = self.root / 'backend.patch'
        self.patch.write_text('locked patch\n')
        backend = {'files': {'backend.patch': hashlib.sha256(self.patch.read_bytes()).hexdigest()}}
        self.lock = self.root / 'metal.lock.json'
        self.lock.write_text(json.dumps(backend))
        (self.root / 'dependencies.lock.json').write_text(json.dumps({'optional_backends': {'metal': {'path': self.lock.name, 'sha256': hashlib.sha256(self.lock.read_bytes()).hexdigest()}}}))
    def tearDown(self):
        metal.ROOT = self.old_root
        self.temp.cleanup()
    def test_valid_pins(self):
        self.assertIn('backend.patch', metal.checked_lock()['files'])
    def test_lock_tamper_refused(self):
        self.lock.write_text('{}')
        with self.assertRaisesRegex(ValueError, 'lock hash mismatch'):
            metal.checked_lock()
    def test_patch_tamper_refused(self):
        self.patch.write_text('unexpected modification\n')
        with self.assertRaisesRegex(ValueError, 'input hash mismatch'):
            metal.checked_lock()

class MetalCheckoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        self.git('init', '-q')
        self.file = self.repo / 'source.txt'
        self.file.write_text('original\n')
        self.git('add', 'source.txt')
        self.git('-c', 'user.name=AgePad Test', '-c', 'user.email=test@invalid', '-c', 'core.hooksPath=/dev/null', 'commit', '--no-gpg-sign', '-qm', 'fixture')
        self.head = self.git('rev-parse', 'HEAD').strip()
        self.source = {'url': 'https://example.invalid/never-fetched.git', 'commit': self.head}
    def tearDown(self):
        self.temp.cleanup()
    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True)
    def test_wrong_revision_does_not_reset(self):
        with self.assertRaisesRegex(ValueError, 'refusing reset'):
            metal.checkout(self.repo, dict(self.source, commit='0'*40))
        self.assertEqual(self.git('rev-parse', 'HEAD').strip(), self.head)
        self.assertEqual(self.file.read_text(), 'original\n')
    def test_staged_modification_is_preserved(self):
        self.file.write_text('user modification\n')
        self.git('add', 'source.txt')
        with self.assertRaisesRegex(ValueError, 'Modified dependency'):
            metal.checkout(self.repo, self.source)
        self.assertEqual(self.file.read_text(), 'user modification\n')
        self.assertIn('M ', self.git('status', '--porcelain'))

if __name__ == '__main__':
    unittest.main()
