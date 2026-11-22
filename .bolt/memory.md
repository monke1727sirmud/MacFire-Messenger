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