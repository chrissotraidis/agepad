import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gates', Path(__file__).resolve().parents[1] / 'scripts/validate-gates.py')
gates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gates)

class GateTests(unittest.TestCase):
    def test_empty_evidence_cannot_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            errors = gates.validate({}, 'ipad-singleplayer', Path(tmp))
            self.assertIn('Row 8: missing', errors)
            self.assertIn('Missing identity: artifact_sha256', errors)

    def test_deferred_mandatory_row_fails_optional_rows_do_not(self):
        with tempfile.TemporaryDirectory() as tmp:
            errors = gates.validate({'rows': {'8': {'status': 'deferred'}, '27': {'status': 'deferred'}}}, 'ipad-singleplayer', Path(tmp))
            self.assertIn('Row 8: deferred', errors)
            self.assertFalse(any(e.startswith('Row 27:') for e in errors))

    def test_apple_requires_phone(self):
        with tempfile.TemporaryDirectory() as tmp:
            errors = gates.validate({}, 'apple-singleplayer', Path(tmp))
            self.assertIn('Row 26: missing', errors)

    def test_declared_pass_with_no_files_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            record = {'rows': {'8': {'status': 'pass', 'evidence': [{'path': 'absent', 'sha256': '0'*64}]}}}
            errors = gates.validate(record, 'ipad-singleplayer', Path(tmp))
            self.assertIn('Row 8 missing/changed evidence', errors)

if __name__ == '__main__':
    unittest.main()
