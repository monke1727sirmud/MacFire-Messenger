#!/usr/bin/env bash
# Applies every migration in supabase/migrations to a disposable PostgreSQL
# cluster and asserts the schema landed.
#
# Requirements: initdb, pg_ctl, psql and postgres on PATH. Point PG_BIN at a
# PostgreSQL bin directory (for example an unpacked pgserver wheel) to use a
# build that is not installed system-wide. Nothing here needs a server running
# beforehand: the cluster is created under a temporary directory and removed on
# exit.
#
# Usage: bash supabase/tests/schema_check.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTS="$ROOT/supabase/tests"
MIGRATIONS=("$ROOT"/supabase/migrations/*.sql)

if [ -n "${PG_BIN:-}" ]; then
  export PATH="$PG_BIN:$PATH"
fi

for bin in initdb pg_ctl psql postgres; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "missing '$bin' on PATH; install PostgreSQL or set PG_BIN to its bin directory" >&2
    exit 1
  }
done

[ -e "${MIGRATIONS[0]}" ] || { echo "no migrations found in $ROOT/supabase/migrations" >&2; exit 1; }

WORK="$(mktemp -d -t macfire-schema-XXXXXX)"
PGDATA="$WORK/data"
SOCK="$WORK/socket"
PORT="${PG_PORT:-55432}"
DB=macfire_schema_check
FAILED=0

cleanup() {
  pg_ctl -D "$PGDATA" stop -m immediate >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "postgres: $(postgres --version)"
echo "workdir:  $WORK"

mkdir -p "$SOCK"
initdb -D "$PGDATA" -U postgres --auth=trust > "$WORK/initdb.log" 2>&1 || {
  echo "initdb failed"; tail -20 "$WORK/initdb.log"; exit 1
}

# Needed so the realtime publication can be created and extended.
printf "wal_level = logical\n" >> "$PGDATA/postgresql.conf"

pg_ctl -D "$PGDATA" -o "-p $PORT -k $SOCK -c listen_addresses=''" -l "$WORK/postgres.log" -w start >/dev/null || {
  echo "server start failed"; tail -20 "$WORK/postgres.log"; exit 1
}

PSQL() { psql -X -h "$SOCK" -p "$PORT" -U postgres "$@"; }
q() { psql -X -tA -h "$SOCK" -p "$PORT" -U postgres -d "$DB" -c "$1"; }

PSQL -d postgres -c "create database $DB" >/dev/null || exit 1

run_sql() {
  local file=$1 label=$2
  if PSQL -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -f "$file" > "$WORK/last.log" 2>&1; then
    echo "ok    $label"
  else
    echo "FAIL  $label"
    tail -30 "$WORK/last.log"
    FAILED=1
    exit 1
  fi
}

check() {
  local expected=$1 actual=$2 label=$3
  if [ "$expected" = "$actual" ]; then
    echo "PASS  $label = $actual"
  else
    echo "FAIL  $label: expected $expected, got $actual"
    FAILED=1
  fi
}

run_sql "$TESTS/00_supabase_stub.sql" "stub: auth schema, roles, supabase_realtime publication"

# Every migration except the bootstrap one runs against an empty auth schema, so
# the pre-trigger accounts can be seeded before the backfill executes.
LAST=$(( ${#MIGRATIONS[@]} - 1 ))
for ((i = 0; i < LAST; i++)); do
  run_sql "${MIGRATIONS[$i]}" "migration: $(basename "${MIGRATIONS[$i]}")"
done

run_sql "$TESTS/10_pre_trigger_accounts.sql" "seed: pre-trigger accounts with duplicate usernames"
run_sql "${MIGRATIONS[$LAST]}" "migration: $(basename "${MIGRATIONS[$LAST]}")"

echo "--- backfill result ---"
q "select username || ' <- ' || email from profiles p join auth.users u on u.id = p.id order by username"
check "3/3" "$(q "select count(*) || '/' || count(distinct username) from profiles")" "backfilled profiles with unique usernames"
check "3" "$(q "select count(*) from user_settings")" "user_settings rows"
check "3" "$(q "select count(*) from friend_groups where name = 'Friends'")" "default Friends groups"

echo "--- trigger path on a new duplicate ---"
q "insert into auth.users (email) values ('alex@delta.test')" >/dev/null
NEWID=$(q "select id from auth.users where email = 'alex@delta.test'")
check "4/4" "$(q "select count(*) || '/' || count(distinct username) from profiles")" "profiles after trigger signup"
echo "new signup ${NEWID} -> $(q "select username from profiles where id = '$NEWID'")"

echo "--- schema objects ---"
check "15" "$(q "select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE'")" "public tables"
echo "policies: $(q "select count(*) from pg_policies where schemaname='public'")"
check "4" "$(q "select count(*) from pg_publication_tables where pubname='supabase_realtime'")" "realtime tables"
check "1" "$(q "select count(*) from pg_trigger where tgrelid='auth.users'::regclass and not tgisinternal")" "auth.users trigger"

echo "--- RLS smoke test (previously recursed) ---"
if psql -X -tA -h "$SOCK" -p "$PORT" -U postgres -d "$DB" -v ON_ERROR_STOP=1 --single-transaction \
  -f "$TESTS/20_rls_smoke.sql" > "$WORK/rls.log" 2>&1; then
  grep -E '^(members|rooms|messages)=[0-9]+$' "$WORK/rls.log" | sed 's/^/PASS  authenticated user sees /'
  check "1" "$(grep -c '^members=1$' "$WORK/rls.log")" "room membership visible without recursion"
  check "1" "$(grep -c '^rooms=1$' "$WORK/rls.log")" "private room visible to owner"
  check "1" "$(grep -c '^messages=1$' "$WORK/rls.log")" "room messages visible to member"
else
  echo "FAIL  RLS smoke test"
  tail -20 "$WORK/rls.log"
  FAILED=1
fi

echo "--- functions ---"
q "select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' order by proname" | tr '\n' ' '
echo

if [ "$FAILED" -eq 0 ]; then echo "RESULT: all checks passed"; else echo "RESULT: failures present"; fi
exit "$FAILED"
