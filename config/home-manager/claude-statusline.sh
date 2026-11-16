#!/usr/bin/env bash
# Claude Code status line: dir, model, 5h and 7d usage limits.
input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_r=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_r=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

out=""
sep=$(printf ' \033[2m·\033[0m ')

add() { if [ -n "$out" ]; then out="$out$sep$1"; else out="$1"; fi; }

[ -n "$dir" ] && add "$(printf '\033[34m%s\033[0m' "$(basename "$dir")")"
[ -n "$model" ] && add "$(printf '\033[36m%s\033[0m' "$model")"

if [ -n "$five" ]; then
  seg=$(printf '5h: %.0f%%' "$five")
  if [ -n "$five_r" ]; then
    t=$(date -d "@$five_r" +%H:%M 2>/dev/null) && seg="$seg (resets $t)"
  fi
  add "$(printf '\033[33m%s\033[0m' "$seg")"
fi

if [ -n "$week" ]; then
  seg=$(printf '7d: %.0f%%' "$week")
  if [ -n "$week_r" ]; then
    t=$(date -d "@$week_r" "+%a %H:%M" 2>/dev/null) && seg="$seg (resets $t)"
  fi
  add "$(printf '\033[35m%s\033[0m' "$seg")"
fi

printf '%s\n' "$out"
