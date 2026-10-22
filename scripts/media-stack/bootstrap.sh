#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Prepara e integra a media stack.
#
#   ./bootstrap.sh            # cria dirs/rede, sobe tudo e integra
#   ./bootstrap.sh --prepare  # so cria dirs, rede e os configs semeados
#   ./bootstrap.sh --wire     # so roda a integracao (stack ja de pe)
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

[[ -f .env ]] || { echo "faltando .env - copie de .env.example"; exit 1; }
set -a; source ./.env; set +a

MODE="${1:---all}"

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    echo "docker compose nao encontrado (instale o docker-compose-plugin)" >&2
    exit 1
  fi
}

make_dirs() {
  echo "==> diretorios"
  local dirs=(
    "${DOWNLOADS_DIR}"/{complete,incomplete,watch}
    "${CONTENT_DIR}"/{tv,movies}
    "${CONFIG_ROOT}"/{prowlarr,sonarr,radarr,bazarr/config,transmission,plex,plex-transcode}
  )
  mkdir -p "${MEDIA_ROOT}" "${dirs[@]}"
  # chown so no que foi criado - um -R em MEDIA_ROOT varreria a biblioteca
  # inteira a cada execucao.
  chown "${PUID}:${PGID}" "${MEDIA_ROOT}" "${DOWNLOADS_DIR}" "${CONTENT_DIR}" \
        "${CONFIG_ROOT}" "${dirs[@]}" 2>/dev/null \
    || echo "    (chown pulado - rode com sudo se os UIDs nao baterem)"
}

make_network() {
  echo "==> rede ${MEDIA_NETWORK}"
  docker network inspect "${MEDIA_NETWORK}" >/dev/null 2>&1 \
    || docker network create "${MEDIA_NETWORK}"
}

# Bazarr nao aceita configuracao por env. A partir da v1.4.3 o arquivo e
# config/config.yaml (o config.ini antigo so sobrevive via migracao legada),
# entao semeamos o yaml direto, antes do primeiro start.
seed_bazarr() {
  local cfg="${CONFIG_ROOT}/bazarr/config/config.yaml"
  if [[ -s "${cfg}" ]]; then
    echo "==> bazarr: ${cfg} ja existe, mantido"
    return
  fi
  echo "==> bazarr: escrevendo ${cfg}"
  cat > "${cfg}" <<YAML
general:
  port: 6767
  base_url: ''
  use_sonarr: true
  use_radarr: true
  serie_default_enabled: true
  movie_default_enabled: true
  auto_update: false
auth:
  type: null
sonarr:
  ip: sonarr
  port: 8989
  base_url: /
  ssl: false
  apikey: ${SONARR_API_KEY}
  full_update: Daily
  only_monitored: false
radarr:
  ip: radarr
  port: 7878
  base_url: /
  ssl: false
  apikey: ${RADARR_API_KEY}
  full_update: Daily
  only_monitored: false
YAML
  chown "${PUID}:${PGID}" "${cfg}" 2>/dev/null || true
}

# Transmission: baixa dentro de /data/downloads para que o path visto por ele e
# pelo Sonarr/Radarr seja o mesmo (hardlink no import). Escrevemos o settings
# completo porque a imagem so copia o default dela quando o arquivo nao existe.
# USER/PASS/WHITELIST/PEERPORT/UMASK sao aplicados por cima pelo init da imagem.
seed_transmission() {
  local cfg="${CONFIG_ROOT}/transmission/settings.json"
  if [[ -s "${cfg}" ]]; then
    echo "==> transmission: ${cfg} ja existe, mantido"
    return
  fi
  echo "==> transmission: escrevendo ${cfg}"
  cat > "${cfg}" <<JSON
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "alt-speed-time-begin": 540,
    "alt-speed-time-day": 127,
    "alt-speed-time-enabled": false,
    "alt-speed-time-end": 1020,
    "alt-speed-up": 50,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "cache-size-mb": 4,
    "dht-enabled": true,
    "download-dir": "/data/downloads/complete",
    "download-queue-enabled": true,
    "download-queue-size": 5,
    "encryption": 1,
    "idle-seeding-limit": 30,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "/data/downloads/incomplete",
    "incomplete-dir-enabled": true,
    "lpd-enabled": false,
    "message-level": 2,
    "peer-limit-global": 200,
    "peer-limit-per-torrent": 50,
    "peer-port": ${TRANSMISSION_PEER_PORT},
    "peer-port-random-on-start": false,
    "pex-enabled": true,
    "port-forwarding-enabled": true,
    "preallocation": 1,
    "prefetch-enabled": 1,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 2,
    "ratio-limit-enabled": false,
    "rename-partial-files": true,
    "rpc-authentication-required": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-port": 9091,
    "rpc-url": "${TRANSMISSION_RPC_URL}",
    "scrape-paused-torrents-enabled": true,
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "speed-limit-down": 100,
    "speed-limit-down-enabled": false,
    "speed-limit-up": 100,
    "speed-limit-up-enabled": false,
    "start-added-torrents": true,
    "trash-original-torrent-files": false,
    "upload-slots-per-torrent": 14,
    "utp-enabled": false,
    "watch-dir": "/data/downloads/watch",
    "watch-dir-enabled": true
}
JSON
  chown "${PUID}:${PGID}" "${cfg}" 2>/dev/null || true
}

prepare() {
  # os seeds sao so filesystem - rodam antes da rede para que uma falha de
  # docker nao deixe a preparacao pela metade
  make_dirs
  seed_bazarr
  seed_transmission
  make_network
}

up() {
  echo "==> subindo as stacks"
  compose -f docker-compose.transmission.yml up -d
  compose -f docker-compose.yml up -d
  compose -f docker-compose.plex.yml up -d
}

wire() {
  echo "==> integrando via API"
  PROWLARR_HOST_URL="http://127.0.0.1:${PROWLARR_PORT}" \
  SONARR_HOST_URL="http://127.0.0.1:${SONARR_PORT}" \
  RADARR_HOST_URL="http://127.0.0.1:${RADARR_PORT}" \
  TRANSMISSION_HOST_URL="http://127.0.0.1:${TRANSMISSION_PORT}" \
  python3 ./integrate.py
}

case "${MODE}" in
  --prepare) prepare ;;
  --wire)    wire ;;
  --all)     prepare; up; wire ;;
  *) echo "uso: $0 [--all|--prepare|--wire]"; exit 1 ;;
esac
