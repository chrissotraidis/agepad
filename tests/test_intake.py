import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('intake', Path(__file__).resolve().parents[1] / 'scripts/identify-inputs.py')
intake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(intake)


class InputSafetyTests(unittest.TestCase):
    def test_link_outside_root_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'escape').symlink_to('/etc/passwd')
            with self.assertRaisesRegex(ValueError, 'Link/special'):
                intake.inventory(root)

    def test_content_drift_changes_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            p = root / 'synthetic.dat'
            p.write_bytes(b'first version')
            before = intake.inventory(root)
            self.assertEqual(before, intake.inventory(root))
            p.write_bytes(b'other version')
            self.assertNotEqual(before, intake.inventory(root))

    def test_installer_name_alone_does_not_identify_hd(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / '221380_install.vdf').write_bytes(b'synthetic')
            self.assertEqual(intake.inspect(root, intake.inventory(root))['edition'], 'unknown')

    def test_both_campaign_container_extensions_recorded(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ['cam8.cpn', 'xcam1.cpx']:
                (root / name).write_bytes(b'synthetic')
            record = intake.inspect(root, intake.inventory(root))
            self.assertEqual(record['campaign_files'], ['cam8.cpn', 'xcam1.cpx'])


if __name__ == '__main__':
    unittest.main()
