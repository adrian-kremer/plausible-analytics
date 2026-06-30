#!/bin/bash
# Restore Plausible migration dumps into running Coolify containers.
# Usage: ./restore-migration.sh [migration_dir]
set -euo pipefail

MIGRATION_DIR="${1:-/root/plausible-migration}"
DB="plausible_events_db"

PLAUSIBLE=$(docker ps --format '{{.Names}}' | grep -E 'plausible-[0-9]+$|plausible-plausible-[0-9]+$' | head -1)
PG=$(docker ps --format '{{.Names}}' | grep plausible_db | head -1)
CH=$(docker ps --format '{{.Names}}' | grep plausible_events_db | head -1)

if [[ -z "$PG" || -z "$CH" ]]; then
  echo "ERROR: plausible_db or plausible_events_db container not found."
  echo "Running containers:"
  docker ps --format '{{.Names}}' | grep -i plausible || true
  exit 1
fi

echo "Using containers:"
echo "  plausible app: ${PLAUSIBLE:-<not running yet>}"
echo "  postgres:      $PG"
echo "  clickhouse:    $CH"
echo "  migration dir: $MIGRATION_DIR"
echo

if [[ ! -f "$MIGRATION_DIR/plausible_pg.sql.gz" ]]; then
  echo "ERROR: $MIGRATION_DIR/plausible_pg.sql.gz not found"
  exit 1
fi

if [[ -n "$PLAUSIBLE" ]]; then
  echo "Stopping plausible app container..."
  docker stop "$PLAUSIBLE"
fi

echo "=== Restoring PostgreSQL ==="
gunzip -c "$MIGRATION_DIR/plausible_pg.sql.gz" | docker exec -i "$PG" psql -U postgres -d plausible_db
echo "PostgreSQL restore done."

echo "=== Restoring ClickHouse ==="
for t in events_v2 sessions_v2 ingest_counters; do
  f="$MIGRATION_DIR/$t.native"
  if [[ ! -f "$f" ]]; then
    echo "WARNING: missing $f, skipping"
    continue
  fi
  echo "Loading $t ..."
  docker exec -i "$CH" clickhouse-client --query="INSERT INTO $DB.$t FORMAT Native" < "$f"
done
echo "ClickHouse restore done."

if [[ -n "$PLAUSIBLE" ]]; then
  echo "Starting plausible app container..."
  docker start "$PLAUSIBLE"
fi

echo
echo "=== Verification ==="
docker exec "$PG" psql -U postgres -d plausible_db -tAc "SELECT 'users=' || count(*) FROM users; SELECT 'sites=' || count(*) FROM sites;"
docker exec "$CH" clickhouse-client --query="SELECT 'events_v2=' || count() FROM $DB.events_v2; SELECT 'sessions_v2=' || count() FROM $DB.sessions_v2; SELECT 'ingest_counters=' || count() FROM $DB.ingest_counters;"
echo
echo "Restore complete."
