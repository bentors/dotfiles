#!/bin/sh
# Dynamic island da Waybar: relogio na barra, faixa no tooltip.
# O equalizador saiu daqui: agora sao 5 modulos proprios (custom/eq1..eq5)
# alimentados pelo eq-driver.sh. Este script voltou a ser disparo unico.

# 3 barras = 3 instancias por segundo com a mesma saida: reaproveita o JSON
# gerado no segundo corrente (a instancia que calcula tambem roda o job do anel)
CACHE="${XDG_RUNTIME_DIR:-/tmp}/waybar-island.json"
[ "$(stat -c %Y "$CACHE" 2>/dev/null)" = "$(date +%s)" ] && exec cat "$CACHE"

PLAYER=spotify
ACENTO='#ffffff'
FRACO='#71717a'

ART_DIR="$HOME/.cache/waybar/art"
mkdir -p "$ART_DIR"

pango() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

json() {
  # tab vira \t; os demais controles (exceto \n, tratado no awk) sao descartados
  printf '%s' "$1" \
    | tr -d '\000-\010\013-\037\177' \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
    | awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }'
}

mmss() {
  s=${1%%.*}
  [ -z "$s" ] && s=0
  printf '%d:%02d' $((s / 60)) $((s % 60))
}

corta() {
  # sed em locale UTF-8 conta caracteres; o mawk do Ubuntu conta bytes e
  # cortava "Canção" no meio do "ç"
  printf '%s' "$1" | LC_ALL=C.UTF-8 sed -E "s/^(.{$(($2 - 1))}).{2,}\$/\\1…/"
}

repete() {
  awk -v n="$2" -v c="$1" 'BEGIN { while (i++ < n) printf "%s", c }'
}

# --- capa circular com anel de progresso (composta com ImageMagick) ---
PASSOS=36
ANEL_TRILHA='#27272a'

# poda EXT N: mantem os N arquivos *.EXT mais recentes (le linha a linha: aguenta espacos)
poda() {
  ls -1t "$ART_DIR"/*."$1" 2>/dev/null | tail -n +"$(($2 + 1))" \
    | while IFS= read -r f; do rm -f -- "$f"; done
}

anel() {
  url="$1"; pos="$2"; dur="$3"
  [ -z "$url" ] && { anel_limpa; return; }

  hash=$(printf '%s' "$url" | md5sum | cut -c1-12)
  # sem duracao (podcast, troca de faixa): capa sem progresso, nao a anterior
  passo=0
  [ "${dur:-0}" -gt 0 ] && passo=$((pos * PASSOS / dur))
  [ "$passo" -gt "$PASSOS" ] && passo=$PASSOS
  alvo="$ART_DIR/$hash-$passo.png"

  # "pronto" tem de ser o alvo atual: se curl/magick falharam ele ainda aponta
  # para a faixa anterior, e assim a proxima execucao tenta de novo
  [ "$alvo" = "$(cat "$ART_DIR/atual" 2>/dev/null)" ] \
    && [ "$alvo" = "$(cat "$ART_DIR/pronto" 2>/dev/null)" ] && return
  # download da capa falhou ha menos de 30 s (offline, URL quebrada): espera antes
  # de tentar de novo, em vez de um curl por segundo
  falha="${XDG_RUNTIME_DIR:-/tmp}/waybar-island-art.$hash.falha"
  [ -e "$falha" ] && [ $(( $(date +%s) - $(stat -c %Y "$falha" 2>/dev/null || echo 0) )) -lt 30 ] && return
  # lock atomico (mkdir) em XDG_RUNTIME_DIR: some no logout/reboot, entao um
  # SIGKILL no meio do curl/magick nao trava a capa para sempre. As 3 instancias
  # disputam; lock com mais de 1 min e tratado como abandonado.
  lock="${XDG_RUNTIME_DIR:-/tmp}/waybar-island-art.lock"
  [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null
  mkdir "$lock" 2>/dev/null || return

  printf '%s' "$alvo" > "$ART_DIR/atual"
  (
    trap 'rmdir "$lock"' EXIT

    # temporarios por processo ($$) + mv: arquivo meio escrito nunca parece pronto
    capa="$ART_DIR/$hash.jpg"
    if [ ! -s "$capa" ]; then
      curl -sfL --max-time 6 -o "$capa.$$.tmp" -- "$url" && mv "$capa.$$.tmp" "$capa" \
        || { rm -f "$capa.$$.tmp"; : > "$falha"; exit 0; }
      rm -f "$falha"
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
        "PNG:$alvo.$$.tmp" 2>/dev/null && mv "$alvo.$$.tmp" "$alvo" || { rm -f "$alvo.$$.tmp"; exit 0; }
    fi

    # o modulo image#art (art.sh) mostra o PNG pronto; nao depende de recarregar CSS
    printf '%s' "$alvo" > "$ART_DIR/pronto"
    # a ilha fica sempre preta (style.css): nao segue a cor da capa
    poda png 4; poda jpg 3
  # stdout/stderr fora: senao o job herda o pipe da Waybar e ela espera o EOF
  ) >/dev/null 2>&1 &
}

anel_limpa() {
  [ -s "$ART_DIR/atual" ] || return
  : > "$ART_DIR/atual"
  : > "$ART_DIR/pronto"
}

# --- estado, lido uma vez por execucao ---
status=''; pos=0; dur=0; tooltip=''

# so escreve quando o valor muda (roda a cada 1s, em 3 instancias)
grava_estado() {
  atual_estado=''
  { read -r atual_estado < "$ART_DIR/state"; } 2>/dev/null
  [ "$atual_estado" = "$1" ] || echo "$1" > "$ART_DIR/state"
}

atualiza_estado() {
  # mesmo formato do relógio que a barra tinha antes
  relogio=$(LC_ALL=C date +'%H:%M - %A, %b %d' | tr A-Z a-z)

  dia=$(LC_ALL=C date +'%A, %d/%m/%Y' | sed \
    -e 's/Monday/segunda-feira/'   -e 's/Tuesday/terca-feira/' \
    -e 's/Wednesday/quarta-feira/' -e 's/Thursday/quinta-feira/' \
    -e 's/Friday/sexta-feira/'     -e 's/Saturday/sabado/' \
    -e 's/Sunday/domingo/')

  # separador \037 (unit separator): nao aparece em titulo/artista, ao contrario de '|'
  US=$(printf '\037')
  dados=$(playerctl --player="$PLAYER" metadata \
    --format "{{status}}${US}{{title}}${US}{{artist}}${US}{{album}}${US}{{position}}${US}{{mpris:length}}${US}{{mpris:artUrl}}" 2>/dev/null)
  # um so parse em vez de um "cut" por campo (o script roda a cada 1s)
  IFS=$US read -r status titulo artista album pos_us dur_us art_url <<EOF
$dados
EOF
  # so digitos entram na aritmetica (campo vazio ou texto vira 0)
  case "$pos_us" in ''|*[!0-9]*) pos_us=0 ;; esac
  case "$dur_us" in ''|*[!0-9]*) dur_us=0 ;; esac

  if [ "$status" != "Playing" ] && [ "$status" != "Paused" ]; then
    grava_estado off
    anel_limpa
    tooltip="<b>$dia</b>"
    return
  fi

  grava_estado on

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

saida=$(printf '{"text":"%s","tooltip":"%s","class":"%s"}' \
  "$(json "$relogio")" "$(json "$tooltip")" "$classe")
printf '%s\n' "$saida" > "$CACHE.$$.tmp" && mv -f "$CACHE.$$.tmp" "$CACHE"
printf '%s\n' "$saida"
