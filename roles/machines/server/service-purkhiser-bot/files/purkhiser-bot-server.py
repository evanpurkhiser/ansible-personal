#!/usr/bin/env python3

# HTTP notification service that forwards messages to Telegram via purkhiser-bot.
# POST text/plain to send a message; POST application/json to pass a raw
# sendMessage payload. The optional channel query parameter selects a configured
# destination, while requests without it use System Notices.

import http.server
import json
import os
import re
import urllib.parse
import urllib.request

TOKEN = os.environ["TELEGRAM_TOKEN"]
CHANNEL = os.environ["TELEGRAM_CHANNEL"]
PORT = int(os.environ["PURKHISER_BOT_PORT"])

TELEGRAM_URL = f"https://api.telegram.org/bot{TOKEN}/sendMessage"
CHANNEL_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def resolve_channel(path):
    query = urllib.parse.parse_qs(
        urllib.parse.urlparse(path).query, keep_blank_values=True
    )
    names = query.get("channel", [])
    if not names:
        return CHANNEL
    if len(names) != 1 or not CHANNEL_PATTERN.fullmatch(names[0]):
        raise ValueError("Invalid channel")

    variable = f"TELEGRAM_CHANNEL_{names[0].upper().replace('-', '_')}"
    try:
        return os.environ[variable]
    except KeyError as error:
        raise ValueError("Unknown channel") from error


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            channel = resolve_channel(self.path)
        except ValueError as error:
            self.send_error(400, str(error))
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        if "json" in self.headers.get("Content-Type", ""):
            payload = json.loads(body)
            payload["chat_id"] = channel
        else:
            payload = {
                "chat_id": channel,
                "text": body.decode(),
                "parse_mode": "Markdown",
            }

        data = json.dumps(payload).encode()
        req = urllib.request.Request(
            TELEGRAM_URL, data=data, headers={"Content-Type": "application/json"}
        )
        urllib.request.urlopen(req)

        self.send_response(200)
        self.end_headers()

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
