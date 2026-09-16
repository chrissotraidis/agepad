from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

class RepoSafetyTests(unittest.TestCase):
    def test_ignored_input_is_private_but_force_staging_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'scripts').mkdir()
            source = Path(__file__).resolve().parents[1] / 'scripts/check-repo-safety.py'
            script = root / 'scripts/check-repo-safety.py'
            shutil.copy2(source, script)
            (root / '.gitignore').write_text('/ref/\n')
            (root / 'ref').mkdir()
            (root / 'ref/synthetic.dat').write_bytes(b'synthetic')
            clean = subprocess.run(['python3', str(script)], capture_output=True)
            self.assertEqual(clean.returncode, 0, clean.stderr)
            subprocess.run(['git', '-C', str(root), 'add', '-f', 'ref/synthetic.dat'], check=True)
            rejected = subprocess.run(['python3', str(script)], capture_output=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn(b'protected path', rejected.stderr)

if __name__ == '__main__':
    unittest.main()
