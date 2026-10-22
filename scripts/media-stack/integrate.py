#!/usr/bin/env python3
"""Liga os servicos da media stack entre si via API (idempotente).

Le as variaveis do .env (ja exportadas pelo bootstrap.sh) e configura:
  * Prowlarr -> proxy FlareSolverr + applications Sonarr/Radarr (full sync)
  * Sonarr/Radarr -> download client Transmission + root folder

Usa apenas a stdlib. Rode depois de `docker compose up -d`.
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

TIMEOUT = 15


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None:
        sys.exit(f"variavel {name} nao definida no .env")
    return value


def call(method: str, base: str, path: str, api_key: str, payload=None):
    url = f"{base.rstrip('/')}{path}"
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("X-Api-Key", api_key)
    if data:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        body = resp.read()
    return json.loads(body) if body else None


def wait_for(name: str, base: str, api_key: str, attempts: int = 60) -> None:
    """Espera o app subir. Erro de credencial falha na hora - insistir 2min
    numa API key errada so esconde a causa."""
    for i in range(attempts):
        try:
            call("GET", base, f"{_api(name)}/system/status", api_key)
            print(f"  [ok] {name} respondendo")
            return
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403):
                sys.exit(f"  [erro] {name} recusou a API key ({exc.code}) - "
                         f"confira {name.upper()}_API_KEY no .env")
            if i == attempts - 1:
                sys.exit(f"  [erro] {name} respondeu HTTP {exc.code}")
            time.sleep(2)
        except Exception as exc:  # noqa: BLE001 - servico ainda subindo
            if i == attempts - 1:
                sys.exit(f"  [erro] {name} nao respondeu: {exc}")
            time.sleep(2)


def wait_for_transmission(base: str, attempts: int = 60) -> None:
    """O RPC responde 401/409 sem sessao - qualquer um dos dois prova que esta
    de pe. Precisa estar pronto ANTES de cadastrar o download client: o
    Sonarr/Radarr testam a conexao no POST e devolvem 400 se ela falhar."""
    url = f"{base.rstrip('/')}{env('TRANSMISSION_RPC_URL', '/transmission/')}rpc"
    for i in range(attempts):
        try:
            urllib.request.urlopen(url, timeout=TIMEOUT)
            print("  [ok] transmission respondendo")
            return
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 409):
                print("  [ok] transmission respondendo")
                return
            if i == attempts - 1:
                sys.exit(f"  [erro] transmission respondeu HTTP {exc.code}")
            time.sleep(2)
        except Exception as exc:  # noqa: BLE001 - servico ainda subindo
            if i == attempts - 1:
                sys.exit(f"  [erro] transmission nao respondeu: {exc}")
            time.sleep(2)


def _api(name: str) -> str:
    return "/api/v1" if name == "prowlarr" else "/api/v3"


def schema_for(base: str, api_key: str, path: str, implementation: str) -> dict:
    for item in call("GET", base, f"{path}/schema", api_key):
        if item.get("implementation") == implementation:
            return item
    sys.exit(f"  [erro] implementation {implementation} nao existe em {path}/schema")


def set_fields(schema: dict, values: dict) -> dict:
    """Preenche os campos do schema que existirem; ignora o resto."""
    for field in schema.get("fields", []):
        if field["name"] in values:
            field["value"] = values[field["name"]]
    return schema


def upsert(base: str, api_key: str, path: str, body: dict) -> None:
    existing = call("GET", base, path, api_key) or []
    for item in existing:
        if item.get("name") == body["name"]:
            body["id"] = item["id"]
            call("PUT", base, f"{path}/{item['id']}", api_key, body)
            print(f"  [=] {body['name']} atualizado ({path})")
            return
    call("POST", base, path, api_key, body)
    print(f"  [+] {body['name']} criado ({path})")


# --------------------------------------------------------------------------
# Prowlarr
# --------------------------------------------------------------------------
def setup_prowlarr(prowlarr: str, key: str) -> None:
    print("prowlarr:")

    # FlareSolverr como indexer proxy (Prowlarr exige uma tag associada)
    tags = call("GET", prowlarr, "/api/v1/tag", key) or []
    tag = next((t for t in tags if t["label"] == "flaresolverr"), None)
    if tag is None:
        tag = call("POST", prowlarr, "/api/v1/tag", key, {"label": "flaresolverr"})
    schema = schema_for(prowlarr, key, "/api/v1/indexerproxy", "FlareSolverr")
    schema.update(name="FlareSolverr", tags=[tag["id"]])
    flare = env("FLARESOLVERR_INTERNAL_URL").rstrip("/") + "/"
    set_fields(schema, {"host": flare, "requestTimeout": 60})
    upsert(prowlarr, key, "/api/v1/indexerproxy", schema)

    # Applications: Sonarr e Radarr (sync completo dos indexers)
    apps = [
        ("Sonarr", env("SONARR_INTERNAL_URL"), env("SONARR_API_KEY"),
         [5000, 5010, 5020, 5030, 5040, 5045, 5050]),
        ("Radarr", env("RADARR_INTERNAL_URL"), env("RADARR_API_KEY"),
         [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060]),
    ]
    for impl, url, app_key, categories in apps:
        schema = schema_for(prowlarr, key, "/api/v1/applications", impl)
        schema.update(name=impl, syncLevel="fullSync", tags=[])
        set_fields(schema, {
            "prowlarrUrl": env("PROWLARR_INTERNAL_URL"),
            "baseUrl": url,
            "apiKey": app_key,
            "syncCategories": categories,
        })
        upsert(prowlarr, key, "/api/v1/applications", schema)


# --------------------------------------------------------------------------
# Sonarr / Radarr
# --------------------------------------------------------------------------
def setup_arr(name: str, base: str, key: str, category: str, root_folder: str) -> None:
    print(f"{name}:")

    schema = schema_for(base, key, "/api/v3/downloadclient", "Transmission")
    url = env("TRANSMISSION_INTERNAL_URL")
    host = url.split("//", 1)[1].split(":")[0]
    port = int(url.rsplit(":", 1)[1])
    schema.update(
        name="Transmission",
        enable=True,
        protocol="torrent",
        priority=1,
        removeCompletedDownloads=True,
        removeFailedDownloads=True,
        tags=[],
    )
    set_fields(schema, {
        "host": host,
        "port": port,
        "useSsl": False,
        "urlBase": env("TRANSMISSION_RPC_URL", "/transmission/"),
        "username": env("TRANSMISSION_USER"),
        "password": env("TRANSMISSION_PASS"),
        # o nome do campo muda entre Sonarr e Radarr; set_fields ignora o ausente
        "tvCategory": category,
        "movieCategory": category,
        "addPaused": False,
    })
    upsert(base, key, "/api/v3/downloadclient", schema)

    folders = call("GET", base, "/api/v3/rootfolder", key) or []
    if any(f["path"].rstrip("/") == root_folder for f in folders):
        print(f"  [=] root folder {root_folder} ja existe")
    else:
        call("POST", base, "/api/v3/rootfolder", key, {"path": root_folder})
        print(f"  [+] root folder {root_folder} criado")


def main() -> None:
    prowlarr = env("PROWLARR_HOST_URL")
    sonarr = env("SONARR_HOST_URL")
    radarr = env("RADARR_HOST_URL")

    print("aguardando os servicos...")
    wait_for_transmission(env("TRANSMISSION_HOST_URL"))
    wait_for("prowlarr", prowlarr, env("PROWLARR_API_KEY"))
    wait_for("sonarr", sonarr, env("SONARR_API_KEY"))
    wait_for("radarr", radarr, env("RADARR_API_KEY"))

    setup_arr("sonarr", sonarr, env("SONARR_API_KEY"), "tv-sonarr", "/data/content/tv")
    setup_arr("radarr", radarr, env("RADARR_API_KEY"), "radarr", "/data/content/movies")
    setup_prowlarr(prowlarr, env("PROWLARR_API_KEY"))
    print("\nintegracao concluida.")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as exc:
        # Sonarr/Radarr/Prowlarr testam a conexao no POST e respondem 400 com o
        # motivo no corpo - vale mais que o traceback.
        sys.exit(f"HTTP {exc.code} em {exc.url}: {exc.read().decode(errors='replace')[:400]}")
    except urllib.error.URLError as exc:
        sys.exit(f"falha de conexao: {exc.reason}")
    except OSError as exc:
        sys.exit(f"falha de rede: {exc}")
