#!/bin/sh
# Applies an optional baseline schema dump (only into a database that has
# never been baselined), then runs the tracked migrations in
# database/migrations/.
#
# database/run_migrations.py documents a HISTORY GAP: migrations before 017
# were applied by hand to every real environment and their SQL was never
# committed, so this runner alone cannot build a schema from an empty
# database. A schema-only dump (with the `schema_migrations` rows for
# whatever it already contains) in backend/database/baseline/*.sql is
# applied here, in filename order, before the numbered migrations run.
#
# The baseline is skipped once `schema_migrations` exists, so re-running
# this container (e.g. via `docker compose up`) never re-applies it.
set -e

BASELINE_DIR="/app/database/baseline"

already_baselined=$(psql "$DATABASE_URL" -tAc "SELECT to_regclass('public.schema_migrations') IS NOT NULL")

if [ "$already_baselined" = "t" ]; then
    echo "Database already baselined — skipping baseline."
elif [ -n "$(ls -A "$BASELINE_DIR"/*.sql 2>/dev/null)" ]; then
    for f in "$BASELINE_DIR"/*.sql; do
        echo "Applying baseline: $f"
        psql "$DATABASE_URL" -q -1 -v ON_ERROR_STOP=1 -f "$f" >/dev/null
    done
else
    echo "No baseline dump found in $BASELINE_DIR — applying tracked migrations only."
    echo "(This will fail on a brand-new database if it needs tables from before migration 017 — see database/run_migrations.py.)"
fi

exec uv run python database/run_migrations.py
