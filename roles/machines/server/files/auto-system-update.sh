#!/usr/bin/bash

set -euo pipefail

source /etc/auto-system-update.conf

update_output=$(sudo -u aur-builder yay -Syu --noconfirm 2>&1 || true)

system_prompt="You are analyzing the output of an Arch Linux system update performed with 'yay -Syu --noconfirm'. Your task is to:
1. Summarize what packages were updated
2. Call-out any warnings, errors, or potentially concerning output, quoting them when they seem important
3. If the update completed successfully with no issues, provide a brief positive summary
4. Format your response in Telegram markdown style (if needed)
5. Keep the summary concise (2-4 sentences) unless there are issues that need explanation

Output ONLY the summary text, no preamble."

ai_summary=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -d "$(jq -n \
    --arg model "gpt-4o-mini" \
    --arg system_prompt "$system_prompt" \
    --arg user_content "$update_output" \
    '{
      "model": $model,
      "messages": [
        {"role": "system", "content": $system_prompt},
        {"role": "user", "content": $user_content}
      ],
      "temperature": 0.3
    }')" | jq -r '.choices[0].message.content')

echo "*🔄 System Update Report*"
echo ""
echo "${ai_summary}"
