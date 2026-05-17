#!/usr/bin/env python3

# HTTP notification service that forwards messages to Telegram via purkhiser-bot.
# POST text/plain to send a message; POST application/json to pass a raw
# sendMessage payload (chat_id is always overridden from config).

import http.server
import json
import os
import urllib.request
import urllib.parse

TOKEN = os.environ["TELEGRAM_TOKEN"]
CHANNEL = os.environ["TELEGRAM_CHANNEL"]
PORT = int(os.environ["PURKHISER_BOT_PORT"])

TELEGRAM_URL = f"https://api.telegram.org/bot{TOKEN}/sendMessage"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        if "json" in self.headers.get("Content-Type", ""):
            payload = json.loads(body)
            payload["chat_id"] = CHANNEL
        else:
            payload = {
                "chat_id": CHANNEL,
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


http.server.HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
