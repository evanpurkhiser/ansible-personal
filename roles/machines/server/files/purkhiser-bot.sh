#!/usr/bin/sh

# Send a message to my telegram via purkhiser-bot

source /etc/purkhiser-bot.conf

message="$(cat)"

curl -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d "parse_mode=Markdown" \
  -d "chat_id=${TELEGRAM_CHANNEL}" \
  -d "text=${message}"
