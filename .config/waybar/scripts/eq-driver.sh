#!/bin/sh
# Alimenta as 5 barras do equalizador da ilha.
#
# Um unico cava; para cada quadro escreve uma linha JSON por barra num arquivo
# proprio. Os modulos da Waybar so fazem "tail -F" nesses arquivos: nao ha
# polling nem processo de shell por barra, quem acorda os modulos e o inotify
# do tail. Varios "tail" podem seguir o mesmo arquivo sem disputar linhas, o
# que um FIFO nao permitiria (a Waybar cria um modulo por monitor).

DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-eq"
CONF="$HOME/.config/waybar/cava-island.conf"
LIMPA_A_CADA=4000

mkdir -p "$DIR"

# Uma so instancia.
exec 9> "$DIR/lock"
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || exit 0
fi

PIPE="$DIR/pipe"
rm -f "$PIPE"
mkfifo "$PIPE" || exit 1

limpa() {
  # Sem isso o cava vira orfao quando o driver morre e vai se acumulando a
  # cada reinicio da barra.
  [ -n "$CAVA_PID" ] && kill "$CAVA_PID" 2>/dev/null
  rm -f "$PIPE" "$DIR"/[1-5]
}
trap 'limpa; exit 0' EXIT INT TERM HUP

for i in 1 2 3 4 5; do
  : > "$DIR/$i"
done

while :; do
  cava -p "$CONF" > "$PIPE" 2>/dev/null &
  CAVA_PID=$!

  n=0
  p1=; p2=; p3=; p4=; p5=   # ultimo valor escrito por barra; vazio forca a escrita
  while IFS=';' read -r b1 b2 b3 b4 b5 _; do
    # so anexa quando o valor da barra mudou (cava manda 12 quadros/s, ate no silencio)
    b1=${b1:-0}; b2=${b2:-0}; b3=${b3:-0}; b4=${b4:-0}; b5=${b5:-0}
    [ "$b1" = "$p1" ] || printf '{"text":" ","class":"h%s"}\n' "$b1" >> "$DIR/1"
    [ "$b2" = "$p2" ] || printf '{"text":" ","class":"h%s"}\n' "$b2" >> "$DIR/2"
    [ "$b3" = "$p3" ] || printf '{"text":" ","class":"h%s"}\n' "$b3" >> "$DIR/3"
    [ "$b4" = "$p4" ] || printf '{"text":" ","class":"h%s"}\n' "$b4" >> "$DIR/4"
    [ "$b5" = "$p5" ] || printf '{"text":" ","class":"h%s"}\n' "$b5" >> "$DIR/5"
    p1=$b1; p2=$b2; p3=$b3; p4=$b4; p5=$b5

    n=$((n + 1))
    if [ "$n" -ge "$LIMPA_A_CADA" ]; then
      # Troca atomica por arquivo novo: o "tail -F" (por nome) reabre e le do
      # inicio, que estara vazio. Truncar no lugar o uutils tail as vezes nao
      # percebe e a barra congela. Nao ha replay de quadros velhos.
      for i in 1 2 3 4 5; do : > "$DIR/$i.new" && mv -f "$DIR/$i.new" "$DIR/$i"; done
      n=0
      p1=; p2=; p3=; p4=; p5=   # arquivo novo e vazio: reescreve o valor atual
    fi
  done < "$PIPE"

  kill "$CAVA_PID" 2>/dev/null
  sleep 2   # cava caiu (troca de sink, por exemplo): tenta de novo
done
