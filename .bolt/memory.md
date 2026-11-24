# Project memory

## Product intent & audience

- **MacFire**: native macOS Objective-C app — an Xfire gaming-messenger clone.
- Target audience: macOS gamers wanting IM with friends, live game status, group chat, server lists.
- Core feature set defined by `MacFire.todo` (CoreData XML store, ~87 items, most marked done).

## Brand personality & voice

- Classic native Mac utility; gaming-focused but understated.
- No explicit voice guidelines inferred yet.

## Visual design & UX direction

- Built with Cocoa / AppKit, `NSOutlineView` for friends list, `.nib` XIB files, Growl for notifications.
- Native macOS UI conventions: menu bar, preferences window, About panel, drag-and-drop friend ordering, tabbed chat.
- Pending UI features: chat window with custom chat view, friend inspector, emoticons, servers list, About/help windows, fleshed-out preferences.

## Decisions, constraints & rationale

- Codebase is Objective-C `.h`/`.m` targeting macOS; requires Xcode / macOS SDK / AppKit.
- Current runtime environment is Linux and web-app-oriented (Vite, Supabase, React) — **cannot compile, run, or test native Objective-C** here.
- Writing blind Objective-C changes is possible but unverifiable; flagged as risky.
- Proposed path options: (1) rebuild as web app using todo list as spec, (2) write untested Objective-C, (3) summary only. No path confirmed yet.

## Open questions & assumptions

- **Unresolved**: Which direction does the user want — web-app revival, blind Objective-C, or something else?
- Assumption: `MacFire.todo` is the authoritative feature spec for remaining work.
- Assumption: If web-app path chosen, core scope starts with friends list (groups) + chat.

## Handoff — web revival started (24 Nov 2026)

- Direction taken: web client at the repo root (Vite + React + TypeScript + `@supabase/supabase-js`) over the existing Supabase schema. Native ObjC still cannot be compiled in this Linux environment.
- Schema gaps closed in `supabase/migrations/20261124120000_macfire_realtime_and_bootstrap.sql`: replaced the self-referencing `chat_room_members` RLS policy (Postgres raised "infinite recursion detected in policy") with SECURITY DEFINER helpers, tightened `friends` inserts, added `accept_friend_request()` RPC, added the `auth.users` bootstrap trigger plus backfill, added `updated_at` triggers, and enabled Realtime on the subscribed tables.
- Client scope: email/password auth, profile + status + current game, friend requests, grouped friend list, 1:1 chat with realtime messages, typing state and read flags. Group rooms and the game-server browser have schema but no UI yet.
- Verification: `npm run build` (tsc + vite) passes; dev server answers on 0.0.0.0:3000 through the preview proxy. Runtime was not exercised — there are no Supabase credentials in this environment.
- Next: apply migrations to a Supabase project, set `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`, then test signup → add friend → chat end to end.