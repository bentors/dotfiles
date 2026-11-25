#!/usr/bin/env python3
"""Abre e fecha o painel de midia conforme o mouse passa sobre a ilha.

A Waybar 0.15.0 nao tem evento de hover para modulos, entao a deteccao e feita
pela posicao do cursor, lida direto do socket IPC do Hyprland (sem "hyprctl",
que forkaria um processo a cada leitura).

Zona quente = a faixa da ilha no topo da tela. Enquanto o painel esta aberto a
zona passa a incluir o retangulo dele, para o mouse poder descer da barra ate
os controles sem que ele feche no meio do caminho.
"""

import os
import signal
import socket
import subprocess
import sys
import time

TOGGLE = os.path.expanduser("~/.config/waybar/scripts/player-panel-toggle.sh")

ILHA_LARGURA = 340   # faixa centrada que conta como "sobre a ilha"
BARRA_ALTURA = 40   # 34 da barra + 6 de margem no topo
PAINEL_W, PAINEL_H = 560, 371
PAINEL_TOPO = 0      # o painel aberto encosta no topo, cobrindo a ilha
PONTE = 0            # sem folga entre barra e painel: nao ha buraco no caminho

INTERVALO = 0.06     # ~16 leituras por segundo
CARENCIA_ABRIR = 0.18   # tempo parado sobre a ilha antes de abrir
CARENCIA_FECHAR = 0.2   # tempo fora da zona antes de fechar
CHECA_ABERTO = 1.0   # no maximo 1 checagem/s de que o painel segue aberto
REVARRE = 5.0        # intervalo para reler a geometria dos monitores


def hypr_socket_path():
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        return None
    base = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    caminho = f"{base}/hypr/{his}/.socket.sock"
    return caminho if os.path.exists(caminho) else None


def hypr(cmd, sock_path):
    """Uma requisicao no socket IPC. Conexao nova por chamada, sem fork."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(0.4)
            s.connect(sock_path)
            s.sendall(cmd.encode())
            partes = []
            while True:
                d = s.recv(8192)
                if not d:
                    break
                partes.append(d)
        return b"".join(partes).decode(errors="replace")
    except Exception:
        return ""


def cursor(sock_path):
    resposta = hypr("cursorpos", sock_path)
    try:
        x, y = resposta.strip().split(",")
        return int(x), int(y.strip())
    except Exception:
        return None


def monitores(sock_path):
    import json

    try:
        mons = json.loads(hypr("j/monitors", sock_path))
        # cursorpos vem em coordenadas lógicas; monitor com escala (notebook 1.25)
        # tem largura/altura físicas maiores que a área que ocupa
        for m in mons:
            m["width"] = round(m["width"] / m["scale"])
            m["height"] = round(m["height"] / m["scale"])
        return mons
    except Exception:
        return []


def fullscreen_ativo(mon, sock_path):
    """True se o workspace ativo do monitor tem janela em tela cheia (barra oculta)."""
    import json

    try:
        # lista de monitores lida agora: a de main() pode ter ate REVARRE s
        atual = next(m for m in json.loads(hypr("j/monitors", sock_path))
                     if m["name"] == mon["name"])
        ws_id = atual["activeWorkspace"]["id"]
        wss = json.loads(hypr("j/workspaces", sock_path))
        return any(w["id"] == ws_id and w.get("hasfullscreen") for w in wss)
    except Exception:
        return False  # sem resposta: abre como antes


def main():
    # Os Popen do toggle nunca recebem wait(); com SIG_IGN o kernel os recolhe
    # sozinho e nao sobram processos <defunct>.
    signal.signal(signal.SIGCHLD, signal.SIG_IGN)
    sock_path = hypr_socket_path()
    if not sock_path:
        print("HYPRLAND_INSTANCE_SIGNATURE ausente", file=sys.stderr)
        return 1

    # A geometria muda com hotplug/dock/reload: relê a cada REVARRE s e quando o
    # cursor cai fora de todo monitor conhecido. Lista vazia nao encerra: espera.
    mons = monitores(sock_path)
    ultima_leitura = time.monotonic()

    aberto = False
    desde_dentro = None
    desde_fora = None
    painel_x = 0
    aberto_desde = ultima_checagem = 0.0

    while True:
        time.sleep(INTERVALO)
        pos = cursor(sock_path)
        if pos is None:
            # Hyprland reiniciou: o socket antigo sumiu e este processo e orfao
            if not os.path.exists(sock_path):
                print("socket do Hyprland sumiu", file=sys.stderr)
                return 1
            continue
        x, y = pos

        def sob_cursor():
            return next(
                (m for m in mons
                 if m["x"] <= x < m["x"] + m["width"]
                 and m["y"] <= y < m["y"] + m["height"]),
                None,
            )

        # Monitor sob o cursor.
        mon = sob_cursor()
        agora = time.monotonic()
        # fora de qualquer monitor: relê, mas no maximo 1x por segundo
        limite = REVARRE if mon else 1.0
        if agora - ultima_leitura >= limite:
            mons = monitores(sock_path) or mons
            ultima_leitura = agora
            mon = sob_cursor()
        if mon is None:
            continue

        centro = mon["x"] + mon["width"] // 2
        alvo_x = centro - PAINEL_W // 2

        sobre_ilha = (
            mon["y"] <= y < mon["y"] + BARRA_ALTURA
            and abs(x - centro) <= ILHA_LARGURA // 2
        )

        sobre_painel = aberto and (
            painel_x <= x < painel_x + PAINEL_W
            and mon["y"] + PAINEL_TOPO - PONTE <= y
            < mon["y"] + PAINEL_TOPO + PAINEL_H
        )

        agora = time.monotonic()

        if sobre_ilha or sobre_painel:
            desde_fora = None
            # Esc / Super+C escondem o painel sem avisar este script: com o
            # cursor sobre a ilha, confere (devagar) se a janela ainda existe.
            if (aberto and sobre_ilha
                    and agora - aberto_desde >= CHECA_ABERTO
                    and agora - ultima_checagem >= CHECA_ABERTO):
                ultima_checagem = agora
                clientes = hypr("j/clients", sock_path)
                # resposta vazia = erro de IPC: mantem o palpite atual
                if clientes and '"dev.local.playerpanel"' not in clientes:
                    aberto = False
            if not aberto:
                desde_dentro = desde_dentro or agora
                if agora - desde_dentro >= CARENCIA_ABRIR:
                    if fullscreen_ativo(mon, sock_path):
                        desde_dentro = None
                        continue
                    painel_x = alvo_x
                    subprocess.Popen(
                        [TOGGLE, "abrir", str(alvo_x), str(mon["y"])],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    aberto = True
                    aberto_desde = agora
                    desde_dentro = None
        else:
            desde_dentro = None
            if aberto:
                desde_fora = desde_fora or agora
                if agora - desde_fora >= CARENCIA_FECHAR:
                    subprocess.Popen(
                        [TOGGLE, "fechar"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    aberto = False
                    desde_fora = None


if __name__ == "__main__":
    sys.exit(main() or 0)
