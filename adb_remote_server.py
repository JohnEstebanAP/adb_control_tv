#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import subprocess
import urllib.parse

ADB_PATH = "/Users/jealvarez/Library/Android/sdk/platform-tools/adb"
DEVICE_ID = "emulator-5554"

KEY_EVENTS = {
    "up": "KEYCODE_DPAD_UP",
    "down": "KEYCODE_DPAD_DOWN",
    "left": "KEYCODE_DPAD_LEFT",
    "right": "KEYCODE_DPAD_RIGHT",
    "ok": "KEYCODE_DPAD_CENTER",
    "back": "KEYCODE_BACK",
    "home": "KEYCODE_HOME",
}

class AdbRemoteHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, data):
        response = json.dumps(data).encode("utf-8")

        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def do_OPTIONS(self):
        self._send_json(200, {"ok": True})

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)

        if parsed_url.path == "/health":
            self._send_json(200, {"status": "ok"})
            return

        self._send_json(404, {"error": "Not found"})

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)

        if parsed_url.path != "/key":
            self._send_json(404, {"error": "Not found"})
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            payload = json.loads(body.decode("utf-8"))
            key = payload.get("key")

            if key not in KEY_EVENTS:
                self._send_json(
                    400,
                    {
                        "error": "Invalid key",
                        "allowed": list(KEY_EVENTS.keys()),
                    },
                )
                return

            key_event = KEY_EVENTS[key]

            command = [
                ADB_PATH,
                "-s",
                DEVICE_ID,
                "shell",
                "input",
                "keyevent",
                key_event,
            ]

            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=5,
            )

            if result.returncode != 0:
                self._send_json(
                    500,
                    {
                        "ok": False,
                        "error": result.stderr,
                    },
                )
                return

            self._send_json(
                200,
                {
                    "ok": True,
                    "key": key,
                    "keyEvent": key_event,
                },
            )

        except Exception as error:
            self._send_json(
                500,
                {
                    "ok": False,
                    "error": str(error),
                },
            )

def main():
    host = "0.0.0.0"
    port = 8080

    server = HTTPServer((host, port), AdbRemoteHandler)
    print(f"ADB Remote Server running on http://{host}:{port}")
    print("Use from phone: http://192.168.0.104:8080")
    server.serve_forever()

if __name__ == "__main__":
    main()