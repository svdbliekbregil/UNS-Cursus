# Sessie 2 — Docker, Grafana, TimescaleDB & Historian

## Wat we bouwen

De volledige UNS-stack lokaal draaien met Docker Compose:

```
┌──────────────────────────────────────────────┐
│  Docker Compose Stack                        │
│                                              │
│  UMH Core ─── Redpanda (intern) ─── UNS     │
│                                              │
│  TimescaleDB ── asset / tag / tag_string     │
│                                              │
│  Grafana ───── dashboards (leest DB)         │
│                                              │
│  HiveMQ ────── lokale MQTT broker            │
│                                              │
│  Node-RED ──── visuele flow editor           │
│                                              │
│  Portainer ─── container management          │
└──────────────────────────────────────────────┘
```

## Starten

```bash
cd stack
cp .env.example .env
# Vul AUTH_TOKEN in (gratis via https://management.umh.app/)
docker compose up -d
```

## Services

| Service     | URL / Poort          | Login              |
|-------------|----------------------|--------------------|
| Grafana     | http://localhost:3000 | admin / changeme   |
| Node-RED    | http://localhost:1880 | (geen login)       |
| Portainer   | http://localhost:9000 | (setup bij eerste keer) |
| TimescaleDB | localhost:5432       | postgres / changeme |
| HiveMQ MQTT | localhost:1883       | (geen auth)        |
| UMH Core    | Management Console   | via AUTH_TOKEN     |

## Database Schema (TimescaleDB)

Drie tabellen:

```
asset       (id, enterprise, site, area, line, workcell, asset_name)
tag         (time, asset_id, tag_name, value, origin)      -- hypertable, numeriek
tag_string  (time, asset_id, tag_name, value, origin)      -- hypertable, tekst
```

De functie `get_asset_id()` maakt assets automatisch aan bij het eerste datapunt.

SQL-scripts voor handmatige setup: `sql/01-create-schema.sql` t/m `sql/04-create-users.sql`.

## Deploy: Historian Flow

De historian is de brug tussen UNS en TimescaleDB.

1. Open **Management Console** → Data Flows → Stand-alone → Add
2. Plak de volledige inhoud van [`sessie-3/flows/flow-historian.yaml`](../sessie-3/flows/flow-historian.yaml)
3. Klik **Save & Deploy**

**Verificatie:** throughput > 0 zodra een bridge data levert.

Wat het doet:
- Luistert naar alle `_raw` topics in de UNS
- Ontleedt het topic naar ISA-95 hiërarchie (enterprise/site/area/line)
- Numerieke waarden → `tag` tabel, tekst → `tag_string` tabel

## Referentie

- `sql/` — Database schema scripts
- `grafana/` — Grafana setup en query voorbeelden
