/*
# MacFire — Realtime, account bootstrap, and RLS fixes

Continues the schema started in the previous migrations.

## What this adds
1. **Fixes a recursive RLS policy** — `chat_room_members` selected through a
   policy that queried `chat_room_members` again, which Postgres rejects with
   "infinite recursion detected in policy". Membership/ownership checks now go
   through SECURITY DEFINER helpers.
2. **Tightens friend inserts** — previously a user could write a row into
   anybody's friend list. Accepting a request now happens in one validated RPC.
3. **Bootstraps new accounts** — every `auth.users` row gets a profile, default
   settings, and a starter "Friends" group.
4. **Enables Realtime** on the tables the client subscribes to.
*/

-- ============ ROOM MEMBERSHIP HELPERS ============
-- SECURITY DEFINER so the policies can check membership without re-entering
-- the RLS policies they are a part of.
CREATE OR REPLACE FUNCTION public.is_room_member(p_room uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM chat_room_members m
    WHERE m.room_id = p_room AND m.user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_room_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_room_member(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_room_owner(p_room uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM chat_rooms r
    WHERE r.id = p_room AND r.owner_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_room_owner(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_room_owner(uuid) TO authenticated;

-- ============ CHAT ROOMS (non-recursive) ============
DROP POLICY IF EXISTS "chat_rooms_select" ON chat_rooms;
CREATE POLICY "chat_rooms_select"
  ON chat_rooms FOR SELECT TO authenticated
  USING (is_private = false OR owner_id = auth.uid() OR public.is_room_member(id));

DROP POLICY IF EXISTS "crm_select" ON chat_room_members;
CREATE POLICY "crm_select"
  ON chat_room_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_room_member(room_id) OR public.is_room_owner(room_id));

DROP POLICY IF EXISTS "crm_insert" ON chat_room_members;
CREATE POLICY "crm_insert"
  ON chat_room_members FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.is_room_owner(room_id));

-- Members may leave a room, owners may remove anyone.
DROP POLICY IF EXISTS "crm_delete" ON chat_room_members;
CREATE POLICY "crm_delete"
  ON chat_room_members FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR public.is_room_owner(room_id));

DROP POLICY IF EXISTS "crm_msg_select" ON chat_room_messages;
CREATE POLICY "crm_msg_select"
  ON chat_room_messages FOR SELECT TO authenticated
  USING (public.is_room_member(room_id));

DROP POLICY IF EXISTS "crm_msg_insert" ON chat_room_messages;
CREATE POLICY "crm_msg_insert"
  ON chat_room_messages FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid() AND public.is_room_member(room_id));

-- ============ FRIENDS: one-way inserts only ============
-- Both rows of a friendship are created by accept_friend_request(), not by the
-- client, so a user cannot graft themselves onto someone else's friend list.
DROP POLICY IF EXISTS "friends_insert" ON friends;
CREATE POLICY "friends_insert"
  ON friends FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "friends_delete" ON friends;
CREATE POLICY "friends_delete"
  ON friends FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Accepting a request validates the caller, then writes both directions.
CREATE OR REPLACE FUNCTION public.accept_friend_request(p_request uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r friend_requests;
BEGIN
  SELECT * INTO r FROM friend_requests WHERE id = p_request FOR UPDATE;
  IF r.id IS NULL THEN
    RAISE EXCEPTION 'friend request not found';
  END IF;
  -- IS DISTINCT FROM so a missing claim (auth.uid() is NULL) is refused rather
  -- than silently skipped by the NULL comparison.
  IF r.receiver_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'only the receiver can accept this request';
  END IF;
  IF r.status <> 'pending' THEN
    RAISE EXCEPTION 'friend request already handled';
  END IF;

  UPDATE friend_requests
    SET status = 'accepted', responded_at = now()
    WHERE id = r.id;

  INSERT INTO friends (user_id, friend_id)
    VALUES (r.sender_id, r.receiver_id), (r.receiver_id, r.sender_id)
    ON CONFLICT (user_id, friend_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_friend_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_friend_request(uuid) TO authenticated;

-- ============ NEW ACCOUNT BOOTSTRAP ============
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  base text;
  shown text;
BEGIN
  base := COALESCE(NULLIF(new.raw_user_meta_data->>'username', ''), split_part(new.email, '@', 1), 'player');
  shown := COALESCE(NULLIF(new.raw_user_meta_data->>'display_name', ''), base);

  BEGIN
    INSERT INTO profiles (id, username, display_name) VALUES (new.id, base, shown);
  EXCEPTION WHEN unique_violation THEN
    INSERT INTO profiles (id, username, display_name)
      VALUES (new.id, base || '_' || substr(new.id::text, 1, 4), shown);
  END;

  INSERT INTO user_settings (user_id) VALUES (new.id) ON CONFLICT DO NOTHING;
  INSERT INTO friend_groups (user_id, name, sort_order) VALUES (new.id, 'Friends', 0) ON CONFLICT DO NOTHING;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill accounts that signed up before the trigger existed. Two emails can
-- share a local part (alex@a.com, alex@b.com) and collide on the unique
-- username, so fall back to a suffixed name exactly like the signup trigger.
DO $$
DECLARE
  account record;
  base text;
  shown text;
BEGIN
  FOR account IN
    SELECT u.id, u.email, u.raw_user_meta_data
    FROM auth.users u
    WHERE NOT EXISTS (SELECT 1 FROM profiles p WHERE p.id = u.id)
  LOOP
    base := COALESCE(NULLIF(account.raw_user_meta_data->>'username', ''), split_part(account.email, '@', 1), 'player');
    shown := COALESCE(NULLIF(account.raw_user_meta_data->>'display_name', ''), base);

    BEGIN
      INSERT INTO profiles (id, username, display_name) VALUES (account.id, base, shown);
    EXCEPTION WHEN unique_violation THEN
      INSERT INTO profiles (id, username, display_name)
        VALUES (account.id, base || '_' || substr(account.id::text, 1, 4), shown);
    END;
  END LOOP;
END;
$$;

INSERT INTO user_settings (user_id)
SELECT p.id FROM profiles p
WHERE NOT EXISTS (SELECT 1 FROM user_settings s WHERE s.user_id = p.id)
ON CONFLICT DO NOTHING;

INSERT INTO friend_groups (user_id, name, sort_order)
SELECT p.id, 'Friends', 0 FROM profiles p
WHERE NOT EXISTS (SELECT 1 FROM friend_groups g WHERE g.user_id = p.id AND g.name = 'Friends')
ON CONFLICT DO NOTHING;

-- ============ UPDATED_AT ============
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  new.updated_at := now();
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS profiles_touch_updated_at ON profiles;
CREATE TRIGGER profiles_touch_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS user_settings_touch_updated_at ON user_settings;
CREATE TRIGGER user_settings_touch_updated_at
  BEFORE UPDATE ON user_settings
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ============ REALTIME ============
-- Keep the client's subscriptions alive; skip silently if the publication is
-- absent (plain Postgres without the Supabase realtime setup).
DO $$
DECLARE
  t text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    RETURN;
  END IF;

  FOREACH t IN ARRAY ARRAY['profiles', 'chat_messages', 'typing_indicators', 'friend_requests']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END;
$$;

-- Typing indicators are overwritten in place, so the sender's update has to
-- carry the whole row for subscribers to see the new state.
ALTER TABLE typing_indicators REPLICA IDENTITY FULL;
