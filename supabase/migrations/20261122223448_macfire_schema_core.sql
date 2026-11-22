/*
# MacFire Core Schema — Games, Profiles, Friends, Groups

## Overview
Creates the foundational tables for a gaming messenger app: game registry,
user profiles, friend relationships, friend requests, custom friend groups,
blocked users, and tagged contacts.

## New Tables

1. **games** — registry of known games with icon URLs.
2. **profiles** — extends auth.users with gaming-specific fields (display name, avatar, status, game state).
3. **friend_requests** — incoming/outgoing friend requests with accept/decline/defer.
4. **friends** — bidirectional friend relationships (one row per direction for simpler queries).
5. **friend_groups** — custom groups a user creates to organize friends.
6. **friend_group_members** — maps friends into groups (many-to-many).
7. **blocked_users** — users who have blocked incoming friend requests.
8. **tagged_contacts** — users tagged for special notifications.

## Security
- All tables use RLS scoped to `authenticated` users.
- Profiles are publicly readable among authenticated users.
- Friend requests visible to both sender and receiver.
- Friends list visible to both parties.
- Groups and blocked users are owner-scoped.
*/

-- ============ GAMES ============
CREATE TABLE IF NOT EXISTS games (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  short_name text,
  icon_url text,
  category text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE games ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON games TO authenticated;

DROP POLICY IF EXISTS "games_select" ON games;
CREATE POLICY "games_select"
  ON games FOR SELECT TO authenticated
  USING (true);

-- ============ PROFILES ============
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  display_name text NOT NULL DEFAULT '',
  avatar_url text,
  status_text text NOT NULL DEFAULT '',
  status_type text NOT NULL DEFAULT 'online' CHECK (status_type IN ('online','away','busy','offline','afk')),
  current_game_id uuid REFERENCES games(id) ON DELETE SET NULL,
  game_server_name text,
  game_server_ip text,
  last_seen_online timestamptz DEFAULT now(),
  is_idle boolean NOT NULL DEFAULT false,
  itunes_status text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON profiles TO authenticated;

DROP POLICY IF EXISTS "profiles_select" ON profiles;
CREATE POLICY "profiles_select"
  ON profiles FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "profiles_insert" ON profiles;
CREATE POLICY "profiles_insert"
  ON profiles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update" ON profiles;
CREATE POLICY "profiles_update"
  ON profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============ FRIEND REQUESTS ============
CREATE TABLE IF NOT EXISTS friend_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','deferred')),
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  UNIQUE(sender_id, receiver_id)
);

ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON friend_requests TO authenticated;

DROP POLICY IF EXISTS "friend_requests_select" ON friend_requests;
CREATE POLICY "friend_requests_select"
  ON friend_requests FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "friend_requests_insert" ON friend_requests;
CREATE POLICY "friend_requests_insert"
  ON friend_requests FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "friend_requests_update" ON friend_requests;
CREATE POLICY "friend_requests_update"
  ON friend_requests FOR UPDATE TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- ============ FRIENDS ============
CREATE TABLE IF NOT EXISTS friends (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  sort_order integer NOT NULL DEFAULT 0,
  UNIQUE(user_id, friend_id)
);

ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON friends TO authenticated;

DROP POLICY IF EXISTS "friends_select" ON friends;
CREATE POLICY "friends_select"
  ON friends FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

DROP POLICY IF EXISTS "friends_insert" ON friends;
CREATE POLICY "friends_insert"
  ON friends FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id OR auth.uid() = friend_id);

DROP POLICY IF EXISTS "friends_update" ON friends;
CREATE POLICY "friends_update"
  ON friends FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "friends_delete" ON friends;
CREATE POLICY "friends_delete"
  ON friends FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- ============ FRIEND GROUPS ============
CREATE TABLE IF NOT EXISTS friend_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_expanded boolean NOT NULL DEFAULT true,
  is_fof_group boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, name)
);

ALTER TABLE friend_groups ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON friend_groups TO authenticated;

DROP POLICY IF EXISTS "friend_groups_select" ON friend_groups;
CREATE POLICY "friend_groups_select"
  ON friend_groups FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "friend_groups_insert" ON friend_groups;
CREATE POLICY "friend_groups_insert"
  ON friend_groups FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "friend_groups_update" ON friend_groups;
CREATE POLICY "friend_groups_update"
  ON friend_groups FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "friend_groups_delete" ON friend_groups;
CREATE POLICY "friend_groups_delete"
  ON friend_groups FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- ============ FRIEND GROUP MEMBERS ============
CREATE TABLE IF NOT EXISTS friend_group_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES friend_groups(id) ON DELETE CASCADE,
  friend_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(group_id, friend_id)
);

ALTER TABLE friend_group_members ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON friend_group_members TO authenticated;

DROP POLICY IF EXISTS "fgm_select" ON friend_group_members;
CREATE POLICY "fgm_select"
  ON friend_group_members FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM friend_groups WHERE friend_groups.id = group_id AND friend_groups.user_id = auth.uid()));

DROP POLICY IF EXISTS "fgm_insert" ON friend_group_members;
CREATE POLICY "fgm_insert"
  ON friend_group_members FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM friend_groups WHERE friend_groups.id = group_id AND friend_groups.user_id = auth.uid()));

DROP POLICY IF EXISTS "fgm_update" ON friend_group_members;
CREATE POLICY "fgm_update"
  ON friend_group_members FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM friend_groups WHERE friend_groups.id = group_id AND friend_groups.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM friend_groups WHERE friend_groups.id = group_id AND friend_groups.user_id = auth.uid()));

DROP POLICY IF EXISTS "fgm_delete" ON friend_group_members;
CREATE POLICY "fgm_delete"
  ON friend_group_members FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM friend_groups WHERE friend_groups.id = group_id AND friend_groups.user_id = auth.uid()));

-- ============ BLOCKED USERS ============
CREATE TABLE IF NOT EXISTS blocked_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, blocked_user_id)
);

ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON blocked_users TO authenticated;

DROP POLICY IF EXISTS "blocked_select" ON blocked_users;
CREATE POLICY "blocked_select"
  ON blocked_users FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "blocked_insert" ON blocked_users;
CREATE POLICY "blocked_insert"
  ON blocked_users FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "blocked_delete" ON blocked_users;
CREATE POLICY "blocked_delete"
  ON blocked_users FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- ============ TAGGED CONTACTS ============
CREATE TABLE IF NOT EXISTS tagged_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tagged_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, tagged_user_id)
);

ALTER TABLE tagged_contacts ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON tagged_contacts TO authenticated;

DROP POLICY IF EXISTS "tagged_select" ON tagged_contacts;
CREATE POLICY "tagged_select"
  ON tagged_contacts FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "tagged_insert" ON tagged_contacts;
CREATE POLICY "tagged_insert"
  ON tagged_contacts FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tagged_delete" ON tagged_contacts;
CREATE POLICY "tagged_delete"
  ON tagged_contacts FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_friends_user_id ON friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend_id ON friends(friend_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver ON friend_requests(receiver_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_sender ON friend_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_friend_groups_user_id ON friend_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_fgm_group_id ON friend_group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_blocked_user_id ON blocked_users(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_status_type ON profiles(status_type);