"""Error-message and rejection checks with synthetic files only."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('kit_diagnostics', root / 'scripts/agepad-kit.py')
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)


class KitDiagnosticsTests(unittest.TestCase):
    def test_empty_summary(self):
        self.assertEqual(kit.file_summary([]), '')

    def test_single_summary(self):
        self.assertEqual(kit.file_summary(['steam:fixture-0']), 'steam:fixture-0')

    def test_five_names_need_no_suffix(self):
        names = ['steam:fixture-%d' % n for n in range(5)]
        self.assertEqual(kit.file_summary(reversed(names)), ', '.join(names))

    def test_six_names_report_one_omitted(self):
        names = ['steam:fixture-%d' % n for n in range(6)]
        self.assertEqual(kit.file_summary(names), ', '.join(names[:5]) + ' (and 1 more)')

    def test_duplicates_do_not_inflate_count(self):
        names = ['steam:fixture-%d' % n for n in range(8)]
        self.assertEqual(kit.file_summary(names + names), ', '.join(names[:5]) + ' (and 3 more)')

    def injection(self, missing=False, matching=False):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            steam = directory / 'steam'
            steam.mkdir()
            entries = []
            for n in range(6):
                name = 'fixture-%d' % n
                data = b'synthetic input fixture'
                if not missing:
                    (steam / name).write_bytes(data)
                entries.append({'source': 'steam:' + name, 'path': name,
                                'source_sha256': kit.sha(data if matching else b'different synthetic fixture'),
                                'op': 'copy'})
            base = directory / 'base.ipa'
            with zipfile.ZipFile(base, 'w') as archive:
                archive.writestr('Payload/Fixture.app/AgePadKit.json', json.dumps({'files': entries}))
            output = directory / 'personal.ipa'
            output.write_bytes(b'preserved previous output')
            with mock.patch.object(kit, 'zip_app') as pack, contextlib.redirect_stdout(io.StringIO()):
                if matching:
                    kit.inject(base, output, directory / 'game', steam, directory / 'steamapps')
                    pack.assert_called_once()
                else:
                    with self.assertRaises(SystemExit) as error:
                        kit.inject(base, output, directory / 'game', steam, directory / 'steamapps')
                    message = str(error.exception)
                    self.assertIn('(and 1 more)', message)
                    self.assertIn('steam:fixture-0', message)
                    self.assertIn('steam:fixture-4', message)
                    self.assertNotIn('steam:fixture-5', message)
                    self.assertIn('Not found' if missing else 'different version', message)
                    pack.assert_not_called()
                self.assertEqual(output.read_bytes(), b'preserved previous output')

    def test_missing_inputs_report_omitted_count_and_do_not_package(self):
        self.injection(missing=True)

    def test_mismatched_inputs_report_omitted_count_and_do_not_package(self):
        self.injection()

    def test_matching_inputs_still_reach_packaging(self):
        self.injection(matching=True)


if __name__ == '__main__':
    unittest.main()
