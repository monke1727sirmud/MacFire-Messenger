-- Accounts that existed before the bootstrap trigger. All three resolve to the
-- username "alex", so the backfill must disambiguate instead of aborting on the
-- profiles.username unique constraint.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('11111111-1111-4111-8111-111111111111', 'alex@alpha.test', '{}'),
  ('22222222-2222-4222-8222-222222222222', 'alex@bravo.test', '{}'),
  ('33333333-3333-4333-8333-333333333333', 'sam@charlie.test', '{"username":"alex"}');
