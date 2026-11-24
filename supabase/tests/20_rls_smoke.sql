-- Exercise the chat-room policies that previously recursed, as a real
-- authenticated user rather than as the table owner.
INSERT INTO chat_rooms (id, name, owner_id, is_private)
VALUES ('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa', 'Private room', '11111111-1111-4111-8111-111111111111', true);
INSERT INTO chat_room_members (room_id, user_id)
VALUES ('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111');
INSERT INTO chat_room_messages (room_id, sender_id, content)
VALUES ('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'hello');

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', false);
SELECT 'members=' || count(*) FROM chat_room_members;
SELECT 'rooms=' || count(*) FROM chat_rooms;
SELECT 'messages=' || count(*) FROM chat_room_messages;
RESET ROLE;
