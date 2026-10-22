# Media stack

Três stacks separadas compartilhando a rede docker **`medianet`**:

| Stack | Compose | Serviços |
| --- | --- | --- |
| `arr` | `docker-compose.yml` | prowlarr, flaresolverr, sonarr, radarr, bazarr |
| `transmission` | `docker-compose.transmission.yml` | transmission |
| `plex` | `docker-compose.plex.yml` | plex |

## Portas

| Serviço | Host | Container | URL |
| --- | --- | --- | --- |
| Prowlarr | **7696** | 9696 | http://localhost:7696 |
| Radarr | **7878** | 7878 | http://localhost:7878 |
| FlareSolverr | **7191** | 8191 | http://localhost:7191 |
| Bazarr | **7767** | 6767 | http://localhost:7767 |
| Sonarr | **7989** | 8989 | http://localhost:7989 |
| Transmission | **7091** | 9091 | http://localhost:7091 |
| Plex | 32400 | 32400 | http://localhost:32400/web |

Plex fica fora da faixa 7xxx de propósito: a 32400 é usada pelo próprio Plex
para descoberta e remote access. Para mudar, ajuste `PLEX_PORT` **e**
`PLEX_ADVERTISE_IP` juntos no `.env`.

## Volumes

O `.env` define `MEDIA_ROOT=/home/$USER/media`, e cada container recebe:

```
${MEDIA_ROOT}            -> /data        raiz única (hardlink + atomic move)
${MEDIA_ROOT}/downloads  -> /downloads   atalho
${MEDIA_ROOT}/content    -> /content     atalho
```

**Use os caminhos `/data/...` dentro dos apps.** `/downloads` e `/content` são
bind mounts separados; para o Sonarr/Radarr eles aparecem como mountpoints
diferentes e o import vira cópia em vez de hardlink. Com `/data` tudo fica sob
o mesmo mountpoint:

```
/data/downloads/complete/…   Transmission grava aqui
/data/content/tv             root folder do Sonarr
/data/content/movies         root folder do Radarr
```

O Plex monta só `${CONTENT_DIR}` como `/content:ro` — aponte as bibliotecas
para `/content/tv` e `/content/movies`.

## Subir

```bash
cp .env.example .env      # ajuste PUID/PGID/TZ/MEDIA_ROOT e as senhas
$EDITOR .env
./bootstrap.sh            # cria dirs + rede, sobe as 3 stacks e integra
```

O `bootstrap.sh` aceita `--prepare` (só diretórios/rede/configs) e `--wire`
(só a integração via API), caso prefira subir as stacks na mão:

```bash
docker network create medianet
docker compose -f docker-compose.transmission.yml up -d
docker compose up -d
docker compose -f docker-compose.plex.yml up -d
./bootstrap.sh --wire
```

## Como a integração acontece

As API keys são **fixadas no `.env`** e injetadas nos apps por variável de
ambiente (`SONARR__AUTH__APIKEY`, `RADARR__AUTH__APIKEY`,
`PROWLARR__AUTH__APIKEY`) — o Servarr aceita config via
`PREFIXO__SEÇÃO__CHAVE`. Assim os serviços já nascem com chaves conhecidas e
podem ser ligados sem passar pela UI.

Como os containers estão na mesma rede, o hostname é o nome do container:

| Variável | Valor |
| --- | --- |
| `PROWLARR_INTERNAL_URL` | `http://prowlarr:9696` |
| `SONARR_INTERNAL_URL` | `http://sonarr:8989` |
| `RADARR_INTERNAL_URL` | `http://radarr:7878` |
| `BAZARR_INTERNAL_URL` | `http://bazarr:6767` |
| `FLARESOLVERR_INTERNAL_URL` | `http://flaresolverr:8191` |
| `TRANSMISSION_INTERNAL_URL` | `http://transmission:9091` |

O que cada peça faz com essas variáveis:

- **`integrate.py`** (chamado pelo `bootstrap.sh --wire`) usa a API para criar,
  de forma idempotente: o proxy FlareSolverr no Prowlarr (com a tag
  `flaresolverr`), as applications Sonarr e Radarr no Prowlarr em `fullSync`, o
  download client Transmission no Sonarr/Radarr e as root folders.
- **Bazarr** não lê configuração por env; o `bootstrap.sh` escreve
  `config/bazarr/config/config.yaml` (desde a v1.4.3 o formato é YAML — o
  `config.ini` antigo só sobrevive por uma migração legada) com as seções
  `sonarr:` e `radarr:` apontadas para os hostnames e API keys, antes do
  primeiro start.
- **Transmission** recebe `config/transmission/settings.json` completo, com
  `download-dir = /data/downloads/complete`, para casar com o path que o
  Sonarr/Radarr enxergam. A imagem só copia o default dela quando o arquivo
  não existe, por isso o arquivo semeado é o conjunto inteiro e não só os
  paths; `USER`/`PASS`/`WHITELIST`/`PEERPORT`/`UMASK` são aplicados por cima
  pelo init da imagem a cada start.

Depois disso resta apenas adicionar os indexers no Prowlarr (Settings →
Indexers) — eles são sincronizados sozinhos para Sonarr e Radarr.

## Notas

- **Login dos apps *arr:** as variáveis `*__AUTH__*` definem o método, mas não
  existe variável para semear usuário/senha (`AuthOptions` expõe só `ApiKey`,
  `Enabled`, `Method` e `Required`). Como `AUTH__REQUIRED` está em
  `DisabledForLocalAddresses`, o acesso pela LAN entra sem login; defina
  usuário e senha em Settings → General → Security no primeiro acesso, senão
  ninguém consegue logar de fora da rede local.
- **Não defina `TRANSMISSION_WEB_HOME`:** a imagem LinuxServer não empacota
  mais as UIs alternativas (flood, kettu, combustion). Apontar para elas serve
  uma página "Upgrade Required!" no lugar da interface.
- `.env` está coberto pelo `.gitignore` do repo (`*.env`); só o `.env.example`
  é versionado. As chaves e a senha do Transmission no `.env` local foram
  geradas aleatoriamente — troque se quiser.
- Autenticação dos apps *arr vem como `Forms` + `DisabledForLocalAddresses`:
  a UI pede login, chamadas da LAN/rede docker não. Para exigir sempre, troque
  `*__AUTH__REQUIRED` para `Enabled`.
- **WSL:** o `PLEX_ADVERTISE_IP` foi preenchido com o IP da interface do WSL,
  que não é alcançável da LAN. Se os clientes Plex estiverem em outras
  máquinas, troque pelo IP do host Windows e configure o port proxy
  (`netsh interface portproxy`).
- Transcoding por hardware no Plex: descomente o bloco `devices: /dev/dri` em
  `docker-compose.plex.yml`. O transcode fica em `config/plex-transcode`, fora
  de `config/plex`, para não aninhar um bind mount dentro do outro.
- A biblioteca é montada no Plex como `/content:ro`. Isso protege a mídia, mas
  impede apagar arquivos pela UI do Plex — tire o `:ro` se quiser essa função.
