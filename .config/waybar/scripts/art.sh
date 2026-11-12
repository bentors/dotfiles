#!/bin/sh
# Capa do album para o modulo image#art: imprime o PNG atual (capa + anel de
# progresso) que o island.sh gerou. O download e a composicao ficam com o
# island.sh, que tem os metadados.
ART_DIR="$HOME/.cache/waybar/art"

img=$(cat "$ART_DIR/pronto" 2>/dev/null)
if [ "$(cat "$ART_DIR/state" 2>/dev/null)" = "on" ] && [ -s "$img" ]; then
  printf '%s\n' "$img"
else
  # saida vazia faz o modulo manter a ultima imagem; um caminho inexistente o esconde
  printf '%s\n' "$ART_DIR/nenhuma"
fi
