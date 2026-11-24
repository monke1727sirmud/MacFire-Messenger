/*
# MacFire — Seed Games Registry

Adds a starter list of popular games to the games table so users can
set their current game status. Uses explicit UUIDs for stable references.
*/

INSERT INTO games (id, name, short_name, category) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Counter-Strike 2', 'CS2', 'FPS'),
  ('a0000000-0000-0000-0000-000000000002', 'Dota 2', 'DOTA', 'MOBA'),
  ('a0000000-0000-0000-0000-000000000003', 'Team Fortress 2', 'TF2', 'FPS'),
  ('a0000000-0000-0000-0000-000000000004', 'Valorant', 'VAL', 'FPS'),
  ('a0000000-0000-0000-0000-000000000005', 'Minecraft', 'MC', 'Sandbox'),
  ('a0000000-0000-0000-0000-000000000006', 'World of Warcraft', 'WoW', 'MMORPG'),
  ('a0000000-0000-0000-0000-000000000007', 'Overwatch 2', 'OW2', 'FPS'),
  ('a0000000-0000-0000-0000-000000000008', 'League of Legends', 'LoL', 'MOBA'),
  ('a0000000-0000-0000-0000-000000000009', 'Apex Legends', 'APEX', 'Battle Royale'),
  ('a0000000-0000-0000-0000-000000000010', 'Rocket League', 'RL', 'Sports')
ON CONFLICT (name) DO NOTHING;