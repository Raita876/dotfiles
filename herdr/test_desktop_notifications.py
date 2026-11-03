import json
import socket
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from desktop_notifications import Monitor, read_snapshot, send_notification


def snapshot(status, machine=None, terminal="t1", children=None):
    return {"spaces": [{
        "name": "作業", "machine": machine,
        "tabs": [{"name": "1", "terminals": [{
            "terminal": terminal, "status": status, "app": "pi",
            "sub_agents": children or [],
        }]}],
    }]}


class MonitorTests(unittest.TestCase):
    def test_initial_snapshot_is_silent(self):
        for status in ("done", "blocked", "working"):
            self.assertEqual(Monitor().update(snapshot(status)), [])

    def test_completion_is_sent_once(self):
        monitor = Monitor()
        monitor.update(snapshot("working"))
        self.assertEqual(monitor.update(snapshot("done")), [{
            "title": "Herdr: pi — 完了", "body": "作業 / 1",
        }])
        self.assertEqual(monitor.update(snapshot("done")), [])
        self.assertEqual(monitor.update(snapshot("idle")), [])

    def test_blocked_and_error_are_one_attention_state(self):
        monitor = Monitor()
        monitor.update(snapshot("working"))
        self.assertEqual(len(monitor.update(snapshot("blocked"))), 1)
        self.assertEqual(monitor.update(snapshot("error")), [])
        monitor.update(snapshot("working"))
        self.assertEqual(len(monitor.update(snapshot("error"))), 1)

    def test_idle_or_unknown_is_not_completion(self):
        for status in ("idle", None):
            monitor = Monitor()
            monitor.update(snapshot("working"))
            self.assertEqual(monitor.update(snapshot(status)), [])

    def test_new_and_removed_terminals_do_not_replay(self):
        monitor = Monitor()
        monitor.update({"spaces": []})
        self.assertEqual(monitor.update(snapshot("done")), [])
        monitor.update({"spaces": []})
        self.assertEqual(monitor.update(snapshot("blocked")), [])

    def test_same_id_on_different_machine_is_independent(self):
        monitor = Monitor()
        monitor.update(snapshot("working"))
        self.assertEqual(monitor.update(snapshot("done", machine="remote")), [])

    def test_sub_agents_are_not_traversed(self):
        monitor = Monitor()
        monitor.update(snapshot("working", children=[{"status": "working"}]))
        self.assertEqual(monitor.update(snapshot("working", children=[{"status": "done"}])), [])

    def test_reconnect_baseline_is_silent(self):
        monitor = Monitor()
        monitor.update(snapshot("working"))
        monitor = Monitor()
        self.assertEqual(monitor.update(snapshot("done")), [])


class TransportTests(unittest.TestCase):
    def test_socket_protocol(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.sock"
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                server.bind(str(path))
                server.listen(1)
                requests = []

                def respond():
                    connection, _ = server.accept()
                    with connection, connection.makefile("rb") as stream:
                        requests.append(json.loads(stream.readline()))
                        connection.sendall(json.dumps(snapshot("working")).encode() + b"\n")

                thread = threading.Thread(target=respond)
                thread.start()
                self.assertEqual(read_snapshot(path), snapshot("working"))
                thread.join(timeout=5)
                self.assertEqual(requests, [{"ls": True}])

    def test_arguments_are_not_shell_interpolated(self):
        with patch("desktop_notifications.subprocess.run") as run:
            send_notification("/bin/notifier", {"title": "-title", "body": "$(touch /tmp/no); '引用'"})
            args, kwargs = run.call_args
            self.assertEqual(args[0], [
                "/bin/notifier", "-title", "\u200b-title", "-message", "\u200b$(touch /tmp/no); '引用'",
                "-activate", "dev.herdr.app",
            ])
            self.assertTrue(kwargs["check"])
            self.assertNotIn("shell", kwargs)

    def test_notification_failure_is_not_silenced_by_sender(self):
        with patch("desktop_notifications.subprocess.run", side_effect=subprocess.TimeoutExpired("notifier", 10)):
            with self.assertRaises(subprocess.TimeoutExpired):
                send_notification("notifier", {"title": "title", "body": "body"})


if __name__ == "__main__":
    unittest.main()
