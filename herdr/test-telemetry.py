import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


DISABLE_TELEMETRY = sys.argv.pop(1)


class TelemetryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="herdr telemetry ")
        self.addCleanup(self.directory.cleanup)
        self.settings = Path(self.directory.name) / "app home" / "settings.json"

    def write(self, content):
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        self.settings.write_text(content)

    def run_activation(self):
        return subprocess.run(
            [DISABLE_TELEMETRY, str(self.settings)],
            capture_output=True,
            text=True,
        )

    def assert_success(self):
        result = self.run_activation()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.settings.parent.glob(".settings.json.*")), [])

    def test_missing_file(self):
        self.assert_success()
        self.assertEqual(json.loads(self.settings.read_text()), {"telemetry": False})
        self.assertFalse(self.settings.is_symlink())
        self.assertEqual(self.settings.stat().st_mode & 0o777, 0o600)

    def test_existing_settings_and_repeated_runs(self):
        original = {"telemetry": True, "theme": "dark", "nested": {"value": [1, 2]}}
        self.write(json.dumps(original))
        self.assert_success()
        expected = {**original, "telemetry": False}
        self.assertEqual(json.loads(self.settings.read_text()), expected)
        self.assert_success()
        self.assertEqual(json.loads(self.settings.read_text()), expected)

    def test_missing_telemetry_key(self):
        self.write('{"theme": "light"}')
        self.assert_success()
        self.assertEqual(
            json.loads(self.settings.read_text()),
            {"theme": "light", "telemetry": False},
        )

    def test_invalid_settings_are_preserved(self):
        for content in ["{broken", "", "null", "[]", "true", "42", '"text"', "{}\n{}"]:
            with self.subTest(content=content):
                self.write(content)
                result = self.run_activation()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.settings.read_text(), content)
                self.assertEqual(list(self.settings.parent.glob(".settings.json.*")), [])


if __name__ == "__main__":
    unittest.main()
