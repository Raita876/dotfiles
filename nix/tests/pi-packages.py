import json
import subprocess
import sys
import unittest
from pathlib import Path


FILTER = '"/nix/store" as $storeDir | ' + Path(sys.argv.pop(1)).read_text()
OLD = "/nix/store/" + "a" * 32 + "-pi-extensions-node-modules-1.0.0/node_modules/"
NEW = "/nix/store/" + "b" * 32 + "-pi-extensions-node-modules-1.0.0/node_modules/"


def prune(dynamic, packages):
    result = subprocess.run(
        [
            "jaq", "-n", "--argjson", "dynamic", json.dumps(dynamic),
            "--argjson", "static", json.dumps({"packages": packages}), FILTER,
        ],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


class PrunePackages(unittest.TestCase):
    def test_removes_stale_and_removed_managed_packages(self):
        current = [NEW + "pi-web-access", NEW + "pi-subagents"]
        dynamic = {"packages": [OLD + "pi-web-access", OLD + "removed", *current]}
        self.assertEqual(prune(dynamic, current), {"packages": current})

    def test_preserves_unmanaged_packages_and_settings(self):
        unmanaged = [
            "npm:example@1.0", "git:github.com/example/tools@v1", "./tools",
            "/nix/store/" + "c" * 32 + "-other/node_modules/pi-web-access",
            {"source": "~/tools", "extensions": ["index.ts"]},
        ]
        current = NEW + "pi-web-access"
        settings = {
            "packages": [*unmanaged, OLD + "pi-web-access", current],
            "theme": "dark", "defaultModel": "work-model",
            "compaction": {"enabled": False},
        }
        self.assertEqual(
            prune(settings, [current]),
            {**settings, "packages": [*unmanaged, current]},
        )

    def test_object_sources(self):
        current = {"source": NEW + "pi-lsp", "extensions": []}
        settings = {"packages": [{"source": OLD + "pi-lsp"}, current]}
        self.assertEqual(prune(settings, [current]), {"packages": [current]})

    def test_empty_declaration_removes_only_managed_packages(self):
        settings = {"packages": [OLD + "pi-lsp", "npm:example"]}
        self.assertEqual(prune(settings, []), {"packages": ["npm:example"]})

    def test_missing_packages(self):
        self.assertEqual(prune({"theme": "dark"}, []), {"theme": "dark"})

    def test_idempotent(self):
        current = [NEW + "pi-lsp"]
        once = prune({"packages": [OLD + "pi-lsp", *current]}, current)
        self.assertEqual(prune(once, current), once)


unittest.main()
