#!/usr/bin/env bash
# Builds a throw-away database from the migrations and runs the access-rule tests.
# Usage: PGHOST=... PGUSER=postgres supabase/tests/run.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
db="icon_test_$$"
psql -v ON_ERROR_STOP=1 -q -d postgres -c "create database $db"
trap 'psql -q -d postgres -c "drop database if exists $db" >/dev/null' EXIT
psql -v ON_ERROR_STOP=1 -q -d "$db" -f "$here/stubs.sql"
for f in "$here"/../migrations/*.sql; do
  echo "migration: $(basename "$f")"
  psql -v ON_ERROR_STOP=1 -q -1 -d "$db" -f "$f"
done
for t in rls collab; do
  psql -v ON_ERROR_STOP=1 -q -o /dev/null -d "$db" -f "$here/$t.sql" 2>&1 | sed -e "s/^psql:[^ ]* NOTICE:  //"
done
echo "ALL ACCESS-RULE TESTS PASSED"
