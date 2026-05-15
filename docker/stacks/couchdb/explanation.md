# CouchDB Stack

## Context

- **Location:** docker/stacks/couchdb
- **Compose file:** compose.yml
- **Data path:** /opt/homelab/data/obsidian/couchdb/data
- **Config path:** /opt/homelab/data/obsidian/couchdb-etc
- **Secrets:** COUCHDB_USER, COUCHDB_PASSWORD in docker/.env

## Deploy

```bash
docker compose --env-file docker/.env -f docker/stacks/couchdb/compose.yml up -d
```

## Access

- **Port:** 5984
- **URL:** http://<node-ip>:5984

## Obsidian Live Sync Setup

- **URL:** http://<node-ip>:5984
- **Username:** value from COUCHDB_USER
- **Password:** value from COUCHDB_PASSWORD
- **Database name:** choose one (e.g., obsidian-vault)

Create a database manually if needed:

```bash
curl -X PUT http://<user>:<pass>@<node-ip>:5984/obsidian-vault
```

## Production Notes

- Backup uses OCI restic snapshots of the CouchDB data path rather than a separate logical dump.
- CouchDB is no longer scraped by Prometheus in the default monitoring stack.
