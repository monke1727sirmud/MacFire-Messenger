/*
# MacFire Messaging Schema — RLS Policies

Adds row-level security policies for all messaging tables created in the
previous migration. Splitting policies from table creation avoids
forward-reference errors when policies reference other tables.
*/

-- ============ CHAT MESSAGES ============
DROP POLICY IF EXISTS "chat_messages_select" ON chat_messages;
CREATE POLICY "chat_messages_select"
  ON chat_messages FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "chat_messages_insert" ON chat_messages;
CREATE POLICY "chat_messages_insert"
  ON chat_messages FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "chat_messages_update" ON chat_messages;
CREATE POLICY "chat_messages_update"
  ON chat_messages FOR UPDATE TO authenticated
  USING (auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = receiver_id);

DROP POLICY IF EXISTS "chat_messages_delete" ON chat_messages;
CREATE POLICY "chat_messages_delete"
  ON chat_messages FOR DELETE TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- ============ CHAT ROOMS ============
DROP POLICY IF EXISTS "chat_rooms_select" ON chat_rooms;
CREATE POLICY "chat_rooms_select"
  ON chat_rooms FOR SELECT TO authenticated
  USING (
    is_private = false
    OR owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM chat_room_members WHERE chat_room_members.room_id = chat_rooms.id AND chat_room_members.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "chat_rooms_insert" ON chat_rooms;
CREATE POLICY "chat_rooms_insert"
  ON chat_rooms FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "chat_rooms_update" ON chat_rooms;
CREATE POLICY "chat_rooms_update"
  ON chat_rooms FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "chat_rooms_delete" ON chat_rooms;
CREATE POLICY "chat_rooms_delete"
  ON chat_rooms FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- ============ CHAT ROOM MEMBERS ============
DROP POLICY IF EXISTS "crm_select" ON chat_room_members;
CREATE POLICY "crm_select"
  ON chat_room_members FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM chat_room_members crm2
      WHERE crm2.room_id = chat_room_members.room_id AND crm2.user_id = auth.uid()
    )
    OR EXISTS (SELECT 1 FROM chat_rooms WHERE chat_rooms.id = room_id AND chat_rooms.owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "crm_insert" ON chat_room_members;
CREATE POLICY "crm_insert"
  ON chat_room_members FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM chat_rooms WHERE chat_rooms.id = room_id AND chat_rooms.owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "crm_delete" ON chat_room_members;
CREATE POLICY "crm_delete"
  ON chat_room_members FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ============ CHAT ROOM MESSAGES ============
DROP POLICY IF EXISTS "crm_msg_select" ON chat_room_messages;
CREATE POLICY "crm_msg_select"
  ON chat_room_messages FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM chat_room_members WHERE chat_room_members.room_id = chat_room_messages.room_id AND chat_room_members.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "crm_msg_insert" ON chat_room_messages;
CREATE POLICY "crm_msg_insert"
  ON chat_room_messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (SELECT 1 FROM chat_room_members WHERE chat_room_members.room_id = chat_room_messages.room_id AND chat_room_members.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "crm_msg_delete" ON chat_room_messages;
CREATE POLICY "crm_msg_delete"
  ON chat_room_messages FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- ============ GAME SERVERS ============
DROP POLICY IF EXISTS "game_servers_select" ON game_servers;
CREATE POLICY "game_servers_select"
  ON game_servers FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "game_servers_insert" ON game_servers;
CREATE POLICY "game_servers_insert"
  ON game_servers FOR INSERT TO authenticated
  WITH CHECK (posted_by = auth.uid());

DROP POLICY IF EXISTS "game_servers_update" ON game_servers;
CREATE POLICY "game_servers_update"
  ON game_servers FOR UPDATE TO authenticated
  USING (posted_by = auth.uid())
  WITH CHECK (posted_by = auth.uid());

DROP POLICY IF EXISTS "game_servers_delete" ON game_servers;
CREATE POLICY "game_servers_delete"
  ON game_servers FOR DELETE TO authenticated
  USING (posted_by = auth.uid());

-- ============ USER SETTINGS ============
DROP POLICY IF EXISTS "user_settings_select" ON user_settings;
CREATE POLICY "user_settings_select"
  ON user_settings FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_settings_insert" ON user_settings;
CREATE POLICY "user_settings_insert"
  ON user_settings FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_settings_update" ON user_settings;
CREATE POLICY "user_settings_update"
  ON user_settings FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============ TYPING INDICATORS ============
DROP POLICY IF EXISTS "typing_select" ON typing_indicators;
CREATE POLICY "typing_select"
  ON typing_indicators FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "typing_insert" ON typing_indicators;
CREATE POLICY "typing_insert"
  ON typing_indicators FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "typing_update" ON typing_indicators;
CREATE POLICY "typing_update"
  ON typing_indicators FOR UPDATE TO authenticated
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "typing_delete" ON typing_indicators;
CREATE POLICY "typing_delete"
  ON typing_indicators FOR DELETE TO authenticated
  USING (auth.uid() = sender_id);