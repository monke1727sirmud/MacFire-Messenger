-- Minimal Supabase-shaped environment so the app migrations can run on stock Postgres.
-- Only the pieces the migrations touch are stubbed: the auth schema and its
-- users table, auth.uid(), the API roles, and the realtime publication.

CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;

CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA auth TO authenticated;

CREATE TABLE auth.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE,
  raw_user_meta_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Supabase reads the caller's id from the JWT; here the test sets the claim.
CREATE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;

-- Real Supabase projects ship this publication; the bootstrap migration extends it.
CREATE PUBLICATION supabase_realtime;
