#!/usr/bin/sh

# Send a message to my telegram via purkhiser-bot
channel="${1:-}"
url="http://localhost:9090"

if [ -n "${channel}" ]; then
	url="${url}?channel=${channel}"
fi

curl -sf -X POST "${url}" \
	-H "Content-Type: text/plain" \
	--data-binary @-
