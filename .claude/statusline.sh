#!/usr/bin/env bash
# Claude Code status line, Tokyo Night. Needs jq.
input=$(cat)
# Repassa o payload ao Orca (status dos agentes), que antes era a statusline.
[ -r ~/.orca/agent-hooks/claude-statusline.sh ] && { printf '%s' "$input" | sh ~/.orca/agent-hooks/claude-statusline.sh >/dev/null 2>&1 & }
IFS=$'\x1f' read -r dir model effort pct < <(jq -r '[.workspace.current_dir // .cwd // "", .model.display_name // "", .effort.level // "", (.context_window.used_percentage // "" | tostring)] | join("\u001f")' <<<"$input")

c() { printf '\033[38;2;%sm' "$1"; }
# Paleta (Tokyo Night)
navy=$(c '84;112;196')    # pasta
purple=$(c '157;124;216') # branch
fg=$(c '192;202;245')     # modelo
blue=$(c '122;162;247')   # barra < 50%
yellow=$(c '224;175;104') # barra 50–79%, branch com alterações
red=$(c '247;118;142')    # barra ≥ 80%
dim=$(c '86;95;137')      # separadores, effort
rst=$'\033[0m'

short=${dir/#$HOME/\~}
out="${navy}${short}${rst}"

if branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null || git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null); then
  mark=""
  [ -n "$(git -C "$dir" --no-optional-locks status --porcelain -uno 2>/dev/null | head -n1)" ] && mark="${yellow} •"
  out+=" ${dim}›${rst} ${purple}${branch}${mark}${rst}"
fi

[ -n "$model" ] && out+=" ${dim}›${rst} ${fg}${model}${rst}"
[ -n "$effort" ] && out+=" ${dim}(${effort})${rst}"

if [ -n "$pct" ]; then
  p=${pct%.*}
  col=$blue; [ "$p" -ge 50 ] && col=$yellow; [ "$p" -ge 80 ] && col=$red
  cheio=$(( (p + 5) / 10 )); [ "$cheio" -gt 10 ] && cheio=10
  barra=""
  for ((i = 0; i < 10; i++)); do [ "$i" -lt "$cheio" ] && barra+="▰" || barra+="▱"; done
  out+=" ${dim}›${rst} ${col}${barra} ${p}%${rst}"
fi

printf '%s\n' "$out"
