#!/usr/bin/sh

# Send a message to my telegram via purkhiser-bot
curl -sf -X POST "http://localhost:9090" \
	-H "Content-Type: text/plain" \
	--data-binary @-
