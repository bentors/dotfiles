#!/bin/sh
# Controla o painel de midia.
#   (sem argumento)   alterna
#   abrir [x]         abre, opcionalmente numa posicao X
#   fechar            fecha
#
# O painel e um processo residente: ele fica de pe com a janela escondida e
# so aparece com SIGUSR2. Iniciar o Python/GTK a cada abertura custava ~400ms
# e engolia o comeco da animacao.
CLASSE='dev.local.playerpanel'
LARGURA=560
TOPO=0           # a janela comeca no topo: o card sobe ate a barra ao recolher
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/player-panel.pid"
PAINEL="$HOME/.config/waybar/scripts/player-panel.py"

MODO=${1:-alternar}

vivo() {
  [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null
}

visivel() {
  hyprctl clients -j | grep -q "\"class\": \"$CLASSE\""
}

posiciona() {
  if [ -n "$1" ]; then
    ALVO_X=$1
    ALVO_Y=$(( ${2:-0} + TOPO ))
  else
    # Monitor sob o cursor (o clique na barra nao muda o monitor focado).
    set -- $(hyprctl monitors -j | python3 -c "
import json, sys
cx, cy = map(float, sys.argv[1].split(','))
ms = json.load(sys.stdin)
for m in ms:
    w, h = m['width'] / m['scale'], m['height'] / m['scale']
    if m['x'] <= cx < m['x'] + w and m['y'] <= cy < m['y'] + h:
        break
else:
    m = next(m for m in ms if m.get('focused'))
print(m['x'], int(m['width'] / m['scale']), m['y'])
" "$(hyprctl cursorpos)")
    ALVO_X=$(( ${1:-0} + (${2:-1920} - LARGURA) / 2 ))
    ALVO_Y=$(( ${3:-0} + TOPO ))
  fi

  i=0
  while [ "$i" -lt 100 ]; do
    if visivel; then
      hyprctl dispatch movewindowpixel \
        "exact $ALVO_X $ALVO_Y,class:^(dev\.local\.playerpanel)$" >/dev/null
      break
    fi
    sleep 0.02
    i=$((i + 1))
  done
}

sobe_residente() {
  # PANEL_HOVER: quem fecha e o vigia de hover, nao a perda de foco.
  PANEL_HOVER=1 setsid python3 "$PAINEL" >"${XDG_RUNTIME_DIR:-/tmp}/player-panel.log" 2>&1 &
  i=0
  while [ "$i" -lt 150 ]; do
    vivo && return 0
    sleep 0.02
    i=$((i + 1))
  done
  return 1
}

abrir() {
  vivo || sobe_residente || exit 1
  kill -USR2 "$(cat "$PIDFILE")" 2>/dev/null
  posiciona "$1" "$2"
}

fechar() {
  vivo && kill -USR1 "$(cat "$PIDFILE")" 2>/dev/null
}

case "$MODO" in
  abrir)  abrir "$2" "$3" ;;   # o painel ja ignora o sinal se estiver aberto
  fechar) fechar ;;
  *)      if visivel; then fechar; else abrir "$2"; fi ;;
esac
