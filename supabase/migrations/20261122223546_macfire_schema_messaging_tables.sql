/*
# MacFire Messaging Schema — Tables Only

Creates tables for direct messages, chat history, chat rooms, game server
browser, user preferences, and typing indicators. Policies added in a
follow-up migration to avoid forward-reference issues.
*/

-- ============ CHAT MESSAGES (1:1) ============
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ CHAT ROOMS ============
CREATE TABLE IF NOT EXISTS chat_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  topic text,
  is_private boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ CHAT ROOM MEMBERS ============
CREATE TABLE IF NOT EXISTS chat_room_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(room_id, user_id)
);

-- ============ CHAT ROOM MESSAGES ============
CREATE TABLE IF NOT EXISTS chat_room_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ GAME SERVERS ============
CREATE TABLE IF NOT EXISTS game_servers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  server_name text NOT NULL,
  ip_address text NOT NULL,
  port integer NOT NULL DEFAULT 27015,
  country text,
  max_players integer NOT NULL DEFAULT 0,
  current_players integer NOT NULL DEFAULT 0,
  map_name text,
  posted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ USER SETTINGS ============
CREATE TABLE IF NOT EXISTS user_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  enable_sound_notifications boolean NOT NULL DEFAULT true,
  enable_message_beep boolean NOT NULL DEFAULT true,
  sound_type text NOT NULL DEFAULT 'system_beep' CHECK (sound_type IN ('system_beep','custom','none')),
  custom_sound_url text,
  idle_timeout_seconds integer NOT NULL DEFAULT 300,
  auto_set_away boolean NOT NULL DEFAULT true,
  auto_expand_groups boolean NOT NULL DEFAULT true,
  tabbed_chat_mode boolean NOT NULL DEFAULT false,
  show_chat_window_on_handshake boolean NOT NULL DEFAULT true,
  enable_packet_logging boolean NOT NULL DEFAULT false,
  enable_itunes_status boolean NOT NULL DEFAULT false,
  version_posing_mode text NOT NULL DEFAULT 'cancel' CHECK (version_posing_mode IN ('cancel','this_session','always')),
  auto_login boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============ TYPING INDICATORS ============
CREATE TABLE IF NOT EXISTS typing_indicators (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_typing boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(sender_id, receiver_id)
);

-- Enable RLS on all
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_room_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_rooms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_room_members TO authenticated;
GRANT SELECT, INSERT, DELETE ON chat_room_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON game_servers TO authenticated;
GRANT SELECT, INSERT, UPDATE ON user_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON typing_indicators TO authenticated;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver ON chat_messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON chat_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_chat_room_members_room ON chat_room_members(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_room_messages_room ON chat_room_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_room_messages_created ON chat_room_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_game_servers_game ON game_servers(game_id);
CREATE INDEX IF NOT EXISTS idx_typing_receiver ON typing_indicators(receiver_id);