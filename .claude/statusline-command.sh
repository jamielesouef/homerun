#!/bin/bash
# statusline: model, context usage %, git branch, branch status — single line
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
[ -n "$effort" ] && model="$model ($effort)"

dir=$(echo "$input" | jq -r '.workspace.current_dir')
folder=$(basename "$dir")

used=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$pct" ]; then
  if [ "$total" -gt 0 ] 2>/dev/null; then
    pct_int=$(( used * 100 / total ))
  else
    pct_int=0
  fi
else
  pct_int=$(printf '%.0f' "$pct")
fi

branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch="no-branch"

dirty=""
[ -n "$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null)" ] && dirty="*"

ahead=0
behind=0
upstream=$(git -C "$dir" --no-optional-locks rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
if [ -n "$upstream" ]; then
  read -r behind ahead < <(git -C "$dir" --no-optional-locks rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
fi

status=""
if [ -z "$upstream" ]; then
  status="no-upstream"
else
  [ "$ahead" -gt 0 ] 2>/dev/null && status="${status}$(printf '\xe2\x86\x91')${ahead}"
  [ "$behind" -gt 0 ] 2>/dev/null && status="${status}$(printf '\xe2\x86\x93')${behind}"
  [ -z "$status" ] && status="clean"
fi
status="${status}${dirty}"

printf '\033[2;36m%s\033[0m \033[2;90m\xe2\x80\xa2\033[0m \033[2;33m%s%%\033[0m \033[2;90m\xe2\x80\xa2\033[0m \033[2;34m\xef\x84\x94 %s\033[0m \033[2;90m\xe2\x80\xa2\033[0m \033[2;32m\xef\x90\x98 %s\033[0m \033[2;90m\xe2\x80\xa2\033[0m \033[2;35m%s\033[0m\n' \
  "$model" "$pct_int" "$folder" "$branch" "$status"
