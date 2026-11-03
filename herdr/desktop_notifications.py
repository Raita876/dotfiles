import argparse
import json
import logging
import socket
import subprocess
import time
from pathlib import Path


class Monitor:
    def __init__(self):
        self.previous = None

    def update(self, snapshot):
        current = {}
        notifications = []
        for space in snapshot["spaces"]:
            for tab in space["tabs"]:
                for terminal in tab["terminals"]:
                    key = (space.get("machine"), terminal["terminal"])
                    status = terminal.get("status")
                    current[key] = status
                    if self.previous is None or key not in self.previous:
                        continue
                    previous = self.previous[key]
                    blocked = status in ("blocked", "error")
                    if blocked and previous not in ("blocked", "error"):
                        event = "入力待ち・エラー"
                    elif status == "done" and previous in ("working", "blocked", "error"):
                        event = "完了"
                    else:
                        continue
                    name = terminal.get("name") or terminal.get("app") or "エージェント"
                    notifications.append({
                        "title": f"Herdr: {name} — {event}",
                        "body": f"{space.get('name') or 'Space'} / {tab.get('name') or 'Tab'}",
                    })
        self.previous = current
        return notifications


def read_snapshot(path):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(str(path))
        client.sendall(b'{"ls":true}\n')
        with client.makefile("rb") as response:
            line = response.readline(2 * 1024 * 1024 + 1)
    if len(line) > 2 * 1024 * 1024 or not line.endswith(b"\n"):
        raise ValueError("Herdr reply is incomplete or too large")
    snapshot = json.loads(line)
    if not isinstance(snapshot, dict) or not isinstance(snapshot.get("spaces"), list):
        raise ValueError("Herdr did not return a spaces list")
    return snapshot


def send_notification(notifier, notification):
    # terminal-notifier interprets a leading '-' as an option even in a value.
    def text(value):
        return "\u200b" + value

    subprocess.run(
        [notifier, "-title", text(notification["title"]),
         "-message", text(notification["body"]), "-activate", "dev.herdr.app"],
        check=True, timeout=10, capture_output=True,
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--notifier", required=True)
    parser.add_argument("--socket", type=Path, required=True)
    args = parser.parse_args()
    logging.basicConfig(level=logging.WARNING)
    monitor = Monitor()
    failed = False
    while True:
        try:
            notifications = monitor.update(read_snapshot(args.socket))
            failed = False
        except (OSError, ValueError, KeyError, TypeError):
            # Reconnecting must not replay work that finished while Herdr was closed.
            monitor = Monitor()
            notifications = []
            if not failed:
                logging.warning("Herdr is unavailable; waiting to reconnect")
            failed = True
        for notification in notifications:
            try:
                send_notification(args.notifier, notification)
            except (OSError, subprocess.SubprocessError):
                logging.warning("Desktop notification failed")
        time.sleep(2)


if __name__ == "__main__":
    main()
