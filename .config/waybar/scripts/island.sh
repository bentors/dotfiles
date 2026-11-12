#!/bin/sh
# Dynamic island da Waybar: relogio na barra, faixa no tooltip.
# O equalizador saiu daqui: agora sao 5 modulos proprios (custom/eq1..eq5)
# alimentados pelo eq-driver.sh. Este script voltou a ser disparo unico.

PLAYER=spotify
ACENTO='#ffffff'
FRACO='#565f89'

ART_DIR="$HOME/.cache/waybar/art"
ART_CSS="$HOME/.config/waybar/art.css"
STYLE="$HOME/.config/waybar/style.css"
mkdir -p "$ART_DIR"

pango() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

json() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }'
}

mmss() {
  s=${1%%.*}
  [ -z "$s" ] && s=0
  printf '%d:%02d' $((s / 60)) $((s % 60))
}

corta() {
  printf '%s' "$1" | awk -v n="$2" \
    '{ if (length($0) > n) print substr($0, 1, n - 1) "…"; else print $0 }'
}

repete() {
  awk -v n="$2" -v c="$1" 'BEGIN { while (i++ < n) printf "%s", c }'
}

# --- capa circular com anel de progresso (composta com ImageMagick) ---
PASSOS=36
ANEL_TRILHA='#4a2f87'

anel() {
  url="$1"; pos="$2"; dur="$3"
  [ -z "$url" ] && { anel_limpa; return; }
  [ "${dur:-0}" -le 0 ] && return

  hash=$(printf '%s' "$url" | md5sum | cut -c1-12)
  passo=$((pos * PASSOS / dur))
  [ "$passo" -gt "$PASSOS" ] && passo=$PASSOS
  alvo="$ART_DIR/$hash-$passo.png"

  [ "$alvo" = "$(cat "$ART_DIR/atual" 2>/dev/null)" ] && [ -s "$ART_DIR/pronto" ] && return
  [ -e "$ART_DIR/lock" ] && return

  printf '%s' "$alvo" > "$ART_DIR/atual"
  (
    : > "$ART_DIR/lock"
    trap 'rm -f "$ART_DIR/lock"' EXIT

    capa="$ART_DIR/$hash.jpg"
    if [ ! -s "$capa" ]; then
      curl -sfL --max-time 6 -o "$capa.tmp" "$url" && mv "$capa.tmp" "$capa" \
        || { rm -f "$capa.tmp"; exit 0; }
    fi

    if [ ! -s "$alvo" ]; then
      fim=$(awk -v p="$passo" -v n="$PASSOS" 'BEGIN { print -90 + (360 * p / n) }')
      magick -size 44x44 xc:none \
        \( "$capa" -alpha set -background none -resize 32x32^ \
           -gravity center -extent 32x32 \
           \( +clone -alpha extract -evaluate set 0 -fill white -draw 'circle 16,16 16,0' \) \
           -alpha off -compose copy_opacity -composite \) \
        -gravity center -compose over -composite \
        -stroke "$ANEL_TRILHA" -strokewidth 3 -fill none -draw "ellipse 22,22 19,19 0,360" \
        -stroke "$ACENTO" -strokewidth 3 -fill none -draw "ellipse 22,22 19,19 -90,$fim" \
        "PNG:$alvo.tmp" 2>/dev/null && mv "$alvo.tmp" "$alvo" || { rm -f "$alvo.tmp"; exit 0; }
    fi

    # cor media da capa, escurecida como no painel (player-panel.py, tinge_card)
    cor="$capa.cor"
    [ -s "$cor" ] || magick "$capa" -scale '1x1!' \
      -format '%[fx:int(255*r*0.38)],%[fx:int(255*g*0.38)],%[fx:int(255*b*0.38)]' \
      info: > "$cor" 2>/dev/null

    # o modulo image#art (art.sh) mostra o PNG pronto; nao depende de recarregar CSS
    printf '%s' "$alvo" > "$ART_DIR/pronto"

    # tinta da ilha: CSS so e relido quando a Waybar recarrega o estilo
    # (reload_style_on_change nao dispara com o style.css linkado pelo stow)
    # window#waybar: mais especifico que o #island do style.css
    [ -s "$cor" ] && printf 'window#waybar #island { background-color: rgb(%s); }\n' "$(cat "$cor")" > "$ART_CSS"
    ls -1t "$ART_DIR"/*.png 2>/dev/null | tail -n +4 | xargs -r rm -f
    ls -1t "$ART_DIR"/*.jpg 2>/dev/null | tail -n +3 | xargs -r rm -f
    ls -1t "$ART_DIR"/*.cor 2>/dev/null | tail -n +3 | xargs -r rm -f
    touch "$STYLE"
  ) &
}

anel_limpa() {
  [ -s "$ART_DIR/atual" ] || return
  : > "$ART_DIR/atual"
  : > "$ART_DIR/pronto"
  : > "$ART_CSS"
  touch "$STYLE"
}

# --- estado, lido uma vez por execucao ---
status=''; pos=0; dur=0; tooltip=''

atualiza_estado() {
  # mesmo formato do relógio que a barra tinha antes
  relogio=$(LC_ALL=C date +'%H:%M - %A, %b %d' | tr A-Z a-z)

  dia=$(LC_ALL=C date +'%A, %d/%m/%Y' | sed \
    -e 's/Monday/segunda-feira/'   -e 's/Tuesday/terca-feira/' \
    -e 's/Wednesday/quarta-feira/' -e 's/Thursday/quinta-feira/' \
    -e 's/Friday/sexta-feira/'     -e 's/Saturday/sabado/' \
    -e 's/Sunday/domingo/')

  dados=$(playerctl --player="$PLAYER" metadata \
    --format '{{status}}|{{title}}|{{artist}}|{{album}}|{{position}}|{{mpris:length}}|{{mpris:artUrl}}' 2>/dev/null)
  # um so parse em vez de um "cut" por campo (o script roda a cada 1s)
  IFS='|' read -r status titulo artista album pos_us dur_us art_url <<EOF
$dados
EOF

  if [ "$status" != "Playing" ] && [ "$status" != "Paused" ]; then
    echo off > "$ART_DIR/state"
    anel_limpa
    tooltip="<b>$dia</b>"
    return
  fi

  echo on > "$ART_DIR/state"

  pos=$(( ${pos_us:-0} / 1000000 ))
  dur=$(( ${dur_us:-0} / 1000000 ))

  anel "$art_url" "$pos" "$dur"

  case "$status" in
    Playing) icone="" ;;
    Paused)  icone="" ;;
  esac

  tooltip="<b>$dia</b>"
  tooltip=$(printf '%s\n<span foreground="%s">%s</span>' \
    "$tooltip" "$FRACO" "$(repete '─' 28)")
  tooltip=$(printf '%s\n\n<span foreground="%s" size="large">%s</span>  <b>%s</b>' \
    "$tooltip" "$ACENTO" "$icone" "$(pango "$(corta "$titulo" 34)")")
  [ -n "$artista" ] && tooltip=$(printf '%s\n<span foreground="%s">     %s</span>' \
    "$tooltip" "$ACENTO" "$(pango "$(corta "$artista" 34)")")
  [ -n "$album" ] && tooltip=$(printf '%s\n<span foreground="%s" size="small"><i>     %s</i></span>' \
    "$tooltip" "$FRACO" "$(pango "$(corta "$album" 34)")")

  if [ "$dur" -gt 0 ]; then
    cheio=$(awk -v p="$pos" -v d="$dur" -v n=22 \
      'BEGIN { v = int(p / d * n); print (v < 0 ? 0 : (v > n ? n : v)) }')
    tooltip=$(printf '%s\n\n<span foreground="%s">%s</span><span foreground="%s">%s</span>' \
      "$tooltip" "$ACENTO" "$(repete '━' "$cheio")" "$FRACO" "$(repete '━' $((22 - cheio)))")
    tooltip=$(printf '%s\n<span foreground="%s" size="small">%s%s%s</span>' \
      "$tooltip" "$FRACO" "$(mmss "$pos")" "$(repete ' ' 14)" "$(mmss "$dur")")
  fi
}

atualiza_estado

case "$status" in
  Playing) classe=playing ;;
  Paused)  classe=paused ;;
  *)       classe=idle ;;
esac

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
  "$(json "$relogio")" "$(json "$tooltip")" "$classe"
