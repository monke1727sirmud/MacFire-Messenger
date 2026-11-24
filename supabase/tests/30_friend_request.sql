-- accept_friend_request() end to end: SENDER asks, RECEIVER accepts. Both
-- statements run as the authenticated user, so the request insert and the RPC
-- grant are exercised the way the client uses them.
SET ROLE authenticated;

SELECT set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', false);
INSERT INTO friend_requests (sender_id, receiver_id, message)
VALUES (
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  'hello from alpha'
);

SELECT set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', false);
SELECT accept_friend_request((
  SELECT id FROM friend_requests
  WHERE sender_id = '11111111-1111-4111-8111-111111111111'
    AND receiver_id = '22222222-2222-4222-8222-222222222222'
));

RESET ROLE;
