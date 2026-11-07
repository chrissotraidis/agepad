"""Portable injection with synthetic files; no game, Steam client or signing tools."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('portable_kit', ROOT / 'scripts/agepad-kit.py')
kit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kit)


class PortableKitTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='AgePad portable input \u96ea ')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.game = self.root / 'game Contents'
        self.steam = self.root / 'steam MacOS'
        self.apps = self.root / 'steamapps'
        for path in (self.game / 'MacOS', self.steam / 'nested', self.apps):
            path.mkdir(parents=True)
        (self.game / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleName': 'Synthetic original'}))
        (self.game / 'MacOS/program').write_bytes(b'synthetic game input')
        (self.steam / 'nested/library').write_bytes(b'synthetic client input')
        (self.apps / 'appmanifest_813780.acf').write_text(
            '"buildid" "123"\n"LastOwner" "private-fixture"\n"AutoUpdateBehavior" "0"\n')
        self.plan = [
            {'path': 'Info.plist', 'source': 'game:Info.plist', 'op': 'plist',
             'set': {'CFBundleName': 'Fixture'}, 'delete': [], 'mode': 0o644},
            {'path': 'SteamAppManifest_813780.acf', 'source': 'steamapps:appmanifest_813780.acf',
             'op': 'appmanifest', 'buildid': '123', 'mode': 0o644},
            {'path': 'Game/program', 'source': 'game:MacOS/program', 'op': 'copy',
             'source_sha256': kit.sha(b'synthetic game input'), 'mode': 0o755},
            {'path': 'Frameworks/library', 'source': 'steam:nested/library', 'op': 'wrap',
             'source_sha256': kit.sha(b'synthetic client input'), 'mode': 0o644},
        ]
        self.base = self.root / 'base.ipa'
        self.output = self.root / 'out/personal.ipa'
        self.write_base()

    def write_base(self):
        with zipfile.ZipFile(self.base, 'w') as archive:
            archive.writestr('Payload/Fixture.app/AgePadKit.json', json.dumps({'format': 1, 'files': self.plan}))
            for name, data, mode in (('OwnProgram', b'synthetic shell', stat.S_IFREG | 0o755),
                                     ('Frameworks/alias', b'library', stat.S_IFLNK | 0o777)):
                info = zipfile.ZipInfo('Payload/Fixture.app/' + name, (2026, 1, 2, 3, 4, 6))
                info.create_system = 3
                info.external_attr = mode << 16
                info.comment = b'synthetic metadata'
                archive.writestr(info, data)

    def inject(self):
        with contextlib.redirect_stdout(io.StringIO()):
            kit.inject(self.base, self.output, self.game, self.steam, self.apps)

    def test_nested_source_keys_are_posix_names(self):
        table = kit.sources(self.game, self.steam)
        self.assertEqual(table['game:MacOS/program'].read_bytes(), b'synthetic game input')
        self.assertIn('steam:nested/library', table)
        self.assertFalse(any('\\' in key for key in table))

    def test_recipe_records_the_built_apps_file_permissions(self):
        app = self.root / 'built/Fixture.app'
        (app / 'Game').mkdir(parents=True)
        (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleName': 'Fixture'}))
        program = app / 'Game/program'
        program.write_bytes(b'synthetic game input')
        program.chmod(0o755)
        recipe_path = self.root / 'recorded.json'
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(kit.recipe(app, recipe_path, self.game, self.steam), 0)
        entries = {item['path']: item for item in json.loads(recipe_path.read_text())['files']}
        self.assertEqual(entries['Game/program']['source'], 'game:MacOS/program')
        self.assertEqual(entries['Game/program']['mode'], stat.S_IMODE(program.stat().st_mode))

    def test_full_cli_forwards_all_local_folders_and_preserves_ipa_metadata(self):
        result = subprocess.run([sys.executable, '-X', 'utf8=0', str(ROOT / 'scripts/agepad-kit.py'), 'inject',
                                 str(self.base), str(self.output), '--game', str(self.game),
                                 '--steam', str(self.steam), '--steamapps', str(self.apps)],
                                capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(str(self.output), result.stdout)
        with zipfile.ZipFile(self.output) as archive, zipfile.ZipFile(self.base) as base:
            self.assertFalse(any('\\' in name for name in archive.namelist()))
            for name in ('OwnProgram', 'Frameworks/alias'):
                path = 'Payload/Fixture.app/' + name
                actual, original = archive.getinfo(path), base.getinfo(path)
                self.assertEqual((actual.create_system, actual.external_attr, actual.date_time, actual.comment),
                                 (original.create_system, original.external_attr, original.date_time, original.comment))
                self.assertEqual(archive.read(path), base.read(path))
            program = archive.getinfo('Payload/Fixture.app/Game/program')
            self.assertEqual(program.create_system, 3)
            self.assertEqual(program.external_attr >> 16, stat.S_IFREG | 0o755)
            self.assertEqual(archive.read(program), b'synthetic game input')
            self.assertEqual(archive.read('Payload/Fixture.app/Frameworks/library'), kit.WRAP + b'synthetic client input')
            record = archive.read('Payload/Fixture.app/SteamAppManifest_813780.acf')
            self.assertNotIn(b'private-fixture', record)
            self.assertIn(b'"AutoUpdateBehavior" "1"', record)

    def test_old_recipe_preserves_base_modes_and_gives_header_edits_execute_permission(self):
        for item in self.plan:
            item.pop('mode')
        self.plan[2]['op'] = 'header'
        self.plan[2]['edits'] = []
        self.write_base()
        with mock.patch.object(kit, 'thin', side_effect=lambda data: data), \
                mock.patch.object(kit, 'transform', side_effect=lambda data, _edits: data):
            self.inject()
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.getinfo('Payload/Fixture.app/Game/program').external_attr >> 16,
                             stat.S_IFREG | 0o755)
            self.assertEqual(archive.getinfo('Payload/Fixture.app/OwnProgram').external_attr >> 16,
                             stat.S_IFREG | 0o755)

    def test_mismatched_private_inputs_preserve_previous_output(self):
        self.output.parent.mkdir()
        self.output.write_bytes(b'previous personal output')
        (self.steam / 'nested/library').write_bytes(b'different synthetic client')
        with self.assertRaisesRegex(SystemExit, 'different version'):
            self.inject()
        self.assertEqual(self.output.read_bytes(), b'previous personal output')


if __name__ == '__main__':
    unittest.main()
