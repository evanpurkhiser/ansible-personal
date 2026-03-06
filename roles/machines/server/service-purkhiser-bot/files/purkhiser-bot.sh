#!/usr/bin/sh

# Send a message to my telegram via purkhiser-bot

source /etc/purkhiser-bot.conf

message="$(cat)"

response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d "parse_mode=Markdown" \
  -d "chat_id=${TELEGRAM_CHANNEL}" \
  -d "text=${message}")

# Only print response if the request failed
if ! echo "$response" | jq -e '.ok == true' > /dev/null 2>&1; then
  echo "$response" >&2
fi
