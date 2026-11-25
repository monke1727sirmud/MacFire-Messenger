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

# The pre-trigger accounts seeded by 10_pre_trigger_accounts.sql.
SENDER=11111111-1111-4111-8111-111111111111
RECEIVER=22222222-2222-4222-8222-222222222222
BYSTANDER=33333333-3333-4333-8333-333333333333

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
q() { PSQL -tA -d "$DB" -c "$1"; }

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

# Like run_sql, but keeps the output so a test can assert on what a signed-in
# user sees; a failure is reported without stopping the remaining checks.
run_capture() {
  local file=$1 log=$2 label=$3
  if PSQL -tA -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -f "$file" > "$WORK/$log" 2>&1; then
    echo "ok    $label"
  else
    echo "FAIL  $label"
    tail -20 "$WORK/$log"
    FAILED=1
  fi
}

# SQL that must be refused, with the message the function raises.
rejects() {
  local expected=$1 label=$2 sql=$3
  if PSQL -tA -d "$DB" -v ON_ERROR_STOP=1 -c "$sql" > "$WORK/last.log" 2>&1; then
    echo "FAIL  $label: statement succeeded"
    FAILED=1
  elif grep -qF "$expected" "$WORK/last.log"; then
    echo "PASS  $label"
  else
    echo "FAIL  $label: expected error '$expected'"
    tail -5 "$WORK/last.log"
    FAILED=1
  fi
}

# SQL that must be permitted; the mirror of rejects.
succeeds() {
  local label=$1 sql=$2
  if PSQL -tA -d "$DB" -v ON_ERROR_STOP=1 -c "$sql" > "$WORK/last.log" 2>&1; then
    echo "PASS  $label"
  else
    echo "FAIL  $label: statement was refused"
    tail -5 "$WORK/last.log"
    FAILED=1
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
run_capture "$TESTS/20_rls_smoke.sql" rls.log "RLS smoke test"
check "members=1,rooms=1,messages=1" "$(grep '^members=' "$WORK/rls.log")" "authenticated user sees room, membership and messages"

# A pending request from SENDER to RECEIVER, accepted by RECEIVER.
echo "--- accept_friend_request end to end ---"
run_capture "$TESTS/30_friend_request.sql" friend.log "friend request: sender asks, receiver accepts"
check "accepted" "$(q "select status from friend_requests where sender_id = '$SENDER' and receiver_id = '$RECEIVER'")" "request marked accepted"
check "2" "$(q "select count(*) from friends where (user_id, friend_id) in (('$SENDER','$RECEIVER'), ('$RECEIVER','$SENDER'))")" "friendship written in both directions"
check "receiver_sees_friend=1" "$(grep '^receiver_sees_friend=' "$WORK/friend.log")" "receiver sees the friendship through RLS"
check "sender_sees_friend=1" "$(grep '^sender_sees_friend=' "$WORK/friend.log")" "sender sees the friendship through RLS"

echo "--- accept_friend_request guards ---"
REQUEST="(select id from friend_requests where sender_id = '$SENDER' and receiver_id = '$RECEIVER')"
rejects "only the receiver can accept this request" "sender cannot accept their own request" \
  "begin; set local role authenticated; select set_config('request.jwt.claim.sub', '$SENDER', true); select accept_friend_request($REQUEST); commit;"
rejects "friend request already handled" "an accepted request cannot be accepted twice" \
  "begin; set local role authenticated; select set_config('request.jwt.claim.sub', '$RECEIVER', true); select accept_friend_request($REQUEST); commit;"
# With no claim auth.uid() is NULL, which must fail rather than satisfy the
# receiver check.
rejects "only the receiver can accept this request" "a session without a JWT claim cannot accept" \
  "begin; insert into friend_requests (id, sender_id, receiver_id) values ('eeeeeeee-1111-4111-8111-eeeeeeeeeeee', '$SENDER', '$BYSTANDER'); set local role authenticated; select accept_friend_request('eeeeeeee-1111-4111-8111-eeeeeeeeeeee'); commit;"

# friends_insert has to allow a user's own side of a friendship and refuse the
# other user's side; the old permissive policy allowed the latter, which is why
# accepting a request goes through the RPC.
echo "--- friends_insert policy (one-way inserts only) ---"
rejects "new row violates row-level security policy" "a user cannot write the other side of a friendship" \
  "begin; set local role authenticated; select set_config('request.jwt.claim.sub', '$SENDER', true); insert into friends (user_id, friend_id) values ('$BYSTANDER', '$SENDER'); commit;"
succeeds "a user can write their own side of a friendship" \
  "begin; set local role authenticated; select set_config('request.jwt.claim.sub', '$SENDER', true); insert into friends (user_id, friend_id) values ('$SENDER', '$BYSTANDER'); commit;"

if [ "$FAILED" -eq 0 ]; then echo "RESULT: all checks passed"; else echo "RESULT: failures present"; fi
exit "$FAILED"
