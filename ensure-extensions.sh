#!/bin/bash
# Background task, forked by the entrypoint on every boot.
#
# Waits for the real postmaster (only it binds TCP — the initdb-time
# temporary server is socket-only), then:
#   1. creates the default extensions if they don't exist yet
#   2. runs ALTER EXTENSION ... UPDATE for any installed extension whose
#      SQL version is older than what this image ships
#
# Step 2 is what makes image upgrades safe for existing volumes:
# pgvectorscale's shared library is version-named (vectorscale-X.Y.Z.so),
# so a database left on an old extension version would reference a library
# a newer image no longer ships. Errors are logged and retried on the next
# boot — never fatal. Disable with POSTGRES_ENSURE_EXTENSIONS=off.

[ "${POSTGRES_ENSURE_EXTENSIONS:-on}" = "off" ] && exit 0

EXTENSIONS="vector,vectorscale"
PG_USER="${POSTGRES_USER:-postgres}"
PG_DB="${POSTGRES_DB:-$PG_USER}"

deadline=$(( $(date +%s) + 900 ))
until pg_isready -q -h 127.0.0.1 -p 5432 -U "$PG_USER" 2>/dev/null; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "ensure-extensions: timed out waiting for postgres; skipping" >&2
    exit 1
  fi
  sleep 3
done

run_sql() {
  gosu postgres psql -X -v ON_ERROR_STOP=1 --no-password \
    -h /var/run/postgresql -p 5432 -U "$PG_USER" -d "$PG_DB" -qc "$1"
}

ensure() {
  local ext rc=0
  local IFS=','
  for ext in $EXTENSIONS; do
    if run_sql "CREATE EXTENSION IF NOT EXISTS \"${ext}\" CASCADE;" >/dev/null 2>&1; then
      echo "ensure-extensions: extension ready: ${ext}"
    else
      echo "ensure-extensions: WARNING could not create extension: ${ext}" >&2
      rc=1
    fi
  done

  run_sql "DO \$\$
    DECLARE r record;
    BEGIN
      FOR r IN SELECT name, installed_version, default_version
                 FROM pg_available_extensions
                WHERE installed_version IS NOT NULL
                  AND default_version <> installed_version
      LOOP
        BEGIN
          EXECUTE format('ALTER EXTENSION %I UPDATE', r.name);
          RAISE NOTICE 'ensure-extensions: updated % (% -> %)',
            r.name, r.installed_version, r.default_version;
        EXCEPTION WHEN OTHERS THEN
          RAISE WARNING 'ensure-extensions: could not update % (% -> %): %',
            r.name, r.installed_version, r.default_version, SQLERRM;
        END;
      END LOOP;
    END\$\$;" >/dev/null || rc=1

  return $rc
}

for attempt in 1 2 3; do
  ensure && exit 0
  echo "ensure-extensions: attempt ${attempt} had errors, retrying in 10s..." >&2
  sleep 10
done
echo "ensure-extensions: WARNING finished with errors; will retry next boot" >&2
