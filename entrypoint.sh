#!/bin/bash
# Entrypoint: fork the extension ensure/update task, then hand off to the
# postgres-ssl base image's wrapper (SSL certs, pgBackRest, volume guards).
# Deliberately no `set -e` — a failure in our extras must never stop
# postgres from booting.

/usr/local/bin/ensure-extensions.sh &

exec /usr/local/bin/wrapper.sh "$@"
