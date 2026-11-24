import { useCallback, useEffect, useMemo, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import type { FriendGroup, FriendRequest, Game, Profile, StatusType } from '../types';
import ChatWindow from './ChatWindow';

const STATUS_LABEL: Record<StatusType, string> = {
  online: 'Online',
  away: 'Away',
  busy: 'Busy',
  afk: 'AFK',
  offline: 'Offline',
};

const STATUS_ORDER: StatusType[] = ['online', 'away', 'busy', 'afk', 'offline'];

type Section = { id: string; name: string; friends: Profile[] };

function initials(name: string): string {
  const parts = name.trim().split(/\s+/).slice(0, 2);
  return parts.map((part) => part[0]?.toUpperCase() ?? '').join('') || '?';
}

function sortFriends(list: Profile[]): Profile[] {
  return [...list].sort((a, b) => {
    const byStatus = STATUS_ORDER.indexOf(a.status_type) - STATUS_ORDER.indexOf(b.status_type);
    if (byStatus !== 0) return byStatus;
    return (a.display_name || a.username).localeCompare(b.display_name || b.username);
  });
}

export default function Messenger({ session }: { session: Session }) {
  const meId = session.user.id;

  const [me, setMe] = useState<Profile | null>(null);
  const [friends, setFriends] = useState<Profile[]>([]);
  const [groups, setGroups] = useState<FriendGroup[]>([]);
  const [members, setMembers] = useState<{ group_id: string; friend_id: string }[]>([]);
  const [requests, setRequests] = useState<(FriendRequest & { sender: Profile | null })[]>([]);
  const [games, setGames] = useState<Game[]>([]);
  const [unread, setUnread] = useState<Record<string, number>>({});
  const [activeId, setActiveId] = useState<string | null>(null);
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});
  const [addOpen, setAddOpen] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const loadFriends = useCallback(async () => {
    const { data: links } = await supabase.from('friends').select('friend_id').eq('user_id', meId);
    const ids = (links ?? []).map((row) => row.friend_id as string);
    if (ids.length === 0) {
      setFriends([]);
      return;
    }
    const { data } = await supabase.from('profiles').select('*').in('id', ids);
    setFriends(sortFriends((data ?? []) as Profile[]));
  }, [meId]);

  const loadRequests = useCallback(async () => {
    const { data } = await supabase
      .from('friend_requests')
      .select('*')
      .eq('receiver_id', meId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });

    const rows = (data ?? []) as FriendRequest[];
    const senderIds = rows.map((row) => row.sender_id);
    let senders: Profile[] = [];

    if (senderIds.length > 0) {
      const { data: profiles } = await supabase.from('profiles').select('*').in('id', senderIds);
      senders = (profiles ?? []) as Profile[];
    }

    const byId = new Map(senders.map((profile) => [profile.id, profile]));
    setRequests(rows.map((row) => ({ ...row, sender: byId.get(row.sender_id) ?? null })));
  }, [meId]);

  const loadUnread = useCallback(async () => {
    const { data } = await supabase
      .from('chat_messages')
      .select('sender_id')
      .eq('receiver_id', meId)
      .eq('is_read', false);

    const next: Record<string, number> = {};
    for (const row of data ?? []) {
      const sender = row.sender_id as string;
      next[sender] = (next[sender] ?? 0) + 1;
    }
    setUnread(next);
  }, [meId]);

  // Initial load: profile, groups, games, friends and pending requests.
  useEffect(() => {
    let alive = true;

    async function boot() {
      const [profileRes, groupsRes, membersRes, gamesRes] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', meId).maybeSingle(),
        supabase.from('friend_groups').select('*').order('sort_order'),
        supabase.from('friend_group_members').select('group_id, friend_id'),
        supabase.from('games').select('*').order('name'),
      ]);

      if (!alive) return;

      setMe((profileRes.data as Profile) ?? null);
      setGroups((groupsRes.data as FriendGroup[]) ?? []);
      setMembers((membersRes.data as { group_id: string; friend_id: string }[]) ?? []);
      setGames((gamesRes.data as Game[]) ?? []);

      await Promise.all([loadFriends(), loadRequests(), loadUnread()]);
      if (alive) setLoading(false);
    }

    void boot();
    return () => {
      alive = false;
    };
  }, [meId, loadFriends, loadRequests, loadUnread]);

  // Presence: online while the tab is open, heartbeating last_seen_online.
  useEffect(() => {
    void supabase
      .from('profiles')
      .update({ status_type: 'online', last_seen_online: new Date().toISOString() })
      .eq('id', meId);

    const heartbeat = window.setInterval(() => {
      void supabase
        .from('profiles')
        .update({ last_seen_online: new Date().toISOString() })
        .eq('id', meId);
    }, 60_000);

    const goOffline = () => {
      void supabase.from('profiles').update({ status_type: 'offline' }).eq('id', meId);
    };

    window.addEventListener('beforeunload', goOffline);

    return () => {
      window.clearInterval(heartbeat);
      window.removeEventListener('beforeunload', goOffline);
    };
  }, [meId]);

  // Live friend status, incoming requests and unread counters.
  useEffect(() => {
    const channel = supabase
      .channel('macfire-activity')
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'profiles' }, (payload) => {
        const updated = payload.new as Profile;
        setMe((current) => (current && current.id === updated.id ? { ...current, ...updated } : current));
        setFriends((current) =>
          current.map((friend) => (friend.id === updated.id ? { ...friend, ...updated } : friend)),
        );
      })
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'friend_requests', filter: `receiver_id=eq.${meId}` },
        () => void loadRequests(),
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'chat_messages', filter: `receiver_id=eq.${meId}` },
        (payload) => {
          const message = payload.new as { sender_id: string };
          setUnread((current) => ({
            ...current,
            [message.sender_id]: (current[message.sender_id] ?? 0) + 1,
          }));
        },
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [meId, loadRequests]);

  useEffect(() => {
    if (!notice) return;
    const timer = window.setTimeout(() => setNotice(null), 5000);
    return () => window.clearTimeout(timer);
  }, [notice]);

  const handleRead = useCallback((friendId: string) => {
    setUnread((current) => {
      if (!current[friendId]) return current;
      const next = { ...current };
      delete next[friendId];
      return next;
    });
  }, []);

  async function updateStatus(status_type: StatusType) {
    setMe((current) => (current ? { ...current, status_type } : current));
    const { error } = await supabase
      .from('profiles')
      .update({ status_type, last_seen_online: new Date().toISOString() })
      .eq('id', meId);
    if (error) setNotice(error.message);
  }

  async function updateGame(current_game_id: string | null) {
    setMe((current) => (current ? { ...current, current_game_id } : current));
    const { error } = await supabase.from('profiles').update({ current_game_id }).eq('id', meId);
    if (error) setNotice(error.message);
  }

  async function acceptRequest(requestId: string) {
    const { error } = await supabase.rpc('accept_friend_request', { p_request: requestId });
    if (error) {
      setNotice(error.message);
      return;
    }
    await Promise.all([loadRequests(), loadFriends()]);
  }

  async function declineRequest(requestId: string) {
    const { error } = await supabase
      .from('friend_requests')
      .update({ status: 'declined', responded_at: new Date().toISOString() })
      .eq('id', requestId);
    if (error) setNotice(error.message);
    await loadRequests();
  }

  async function sendRequest(username: string): Promise<string> {
    const clean = username.trim().replace(/^@/, '');
    if (!clean) return 'Enter a username.';

    const { data, error } = await supabase
      .from('profiles')
      .select('id, username, display_name')
      .ilike('username', clean)
      .limit(1);

    if (error) return error.message;
    const target = (data ?? [])[0] as Pick<Profile, 'id' | 'username' | 'display_name'> | undefined;
    if (!target) return `No player named “${clean}”.`;
    if (target.id === meId) return 'That is your own account.';
    if (friends.some((friend) => friend.id === target.id)) {
      return `${target.display_name || target.username} is already a friend.`;
    }

    const { error: insertError } = await supabase.from('friend_requests').insert({
      sender_id: meId,
      receiver_id: target.id,
      message: `${me?.display_name || me?.username || 'Someone'} wants to add you.`,
    });

    if (insertError) {
      return insertError.code === '23505'
        ? `You already sent ${target.display_name || target.username} a request.`
        : insertError.message;
    }

    return `Request sent to ${target.display_name || target.username}.`;
  }

  const sections = useMemo<Section[]>(() => {
    const groupOf = new Map(members.map((member) => [member.friend_id, member.group_id]));
    const buckets = new Map<string, Profile[]>(groups.map((group) => [group.id, []]));
    const ungrouped: Profile[] = [];

    for (const friend of friends) {
      const groupId = groupOf.get(friend.id);
      const bucket = groupId ? buckets.get(groupId) : undefined;
      if (bucket) bucket.push(friend);
      else ungrouped.push(friend);
    }

    const built: Section[] = groups
      .filter((group) => (buckets.get(group.id) ?? []).length > 0)
      .map((group) => ({
        id: group.id,
        name: group.name,
        friends: sortFriends(buckets.get(group.id) ?? []),
      }));

    if (ungrouped.length > 0) {
      built.push({ id: 'ungrouped', name: 'Friends', friends: sortFriends(ungrouped) });
    }

    return built;
  }, [friends, groups, members]);

  const activeFriend = friends.find((friend) => friend.id === activeId) ?? null;
  const onlineCount = friends.filter((friend) => friend.status_type !== 'offline').length;
  const gameName = (id: string | null) => games.find((game) => game.id === id)?.name ?? null;

  if (loading) return <div className="boot">Loading your friends…</div>;

  return (
    <div className="app">
      <aside className="sidebar">
        <header className="brand">
          <span className="flame">◆</span> MacFire
        </header>

        <div className="profile-card">
          <div className={`avatar status-${me?.status_type ?? 'offline'}`}>
            {initials(me?.display_name || me?.username || '?')}
          </div>
          <div className="profile-meta">
            <div className="profile-name">{me?.display_name || me?.username || 'Player'}</div>
            <div className="profile-sub">@{me?.username ?? '…'}</div>
          </div>
          <button className="ghost small" onClick={() => void supabase.auth.signOut()}>
            Sign out
          </button>

          <div className="profile-controls">
            <select
              aria-label="Status"
              value={me?.status_type ?? 'online'}
              onChange={(event) => void updateStatus(event.target.value as StatusType)}
            >
              {STATUS_ORDER.map((status) => (
                <option key={status} value={status}>
                  {STATUS_LABEL[status]}
                </option>
              ))}
            </select>
            <select
              aria-label="Current game"
              value={me?.current_game_id ?? ''}
              onChange={(event) => void updateGame(event.target.value || null)}
            >
              <option value="">Not playing</option>
              {games.map((game) => (
                <option key={game.id} value={game.id}>
                  {game.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="sidebar-tools">
          <button className="ghost" onClick={() => setAddOpen((open) => !open)}>
            {addOpen ? 'Close' : '+ Add friend'}
          </button>
        </div>

        {addOpen && <AddFriend onSubmit={sendRequest} />}

        {requests.length > 0 && (
          <div className="requests">
            <div className="section-title">
              Friend requests <span className="pill">{requests.length}</span>
            </div>
            {requests.map((request) => (
              <div className="request" key={request.id}>
                <div className="request-who">
                  {request.sender?.display_name || request.sender?.username || 'Unknown player'}
                </div>
                <div className="request-actions">
                  <button className="primary tiny" onClick={() => void acceptRequest(request.id)}>
                    Accept
                  </button>
                  <button className="ghost tiny" onClick={() => void declineRequest(request.id)}>
                    Decline
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="friend-scroll">
          {sections.length === 0 && (
            <p className="muted pad">
              No friends yet. Add someone by username to start chatting.
            </p>
          )}

          {sections.map((section) => {
            const isCollapsed = collapsed[section.id] ?? false;
            return (
              <div className="group" key={section.id}>
                <button
                  className="group-header"
                  onClick={() =>
                    setCollapsed((current) => ({ ...current, [section.id]: !isCollapsed }))
                  }
                >
                  <span className="chevron">{isCollapsed ? '▸' : '▾'}</span>
                  {section.name}
                  <span className="count">{section.friends.length}</span>
                </button>

                {!isCollapsed &&
                  section.friends.map((friend) => (
                    <button
                      key={friend.id}
                      className={`friend-row ${activeId === friend.id ? 'active' : ''}`}
                      onClick={() => setActiveId(friend.id)}
                    >
                      <span className={`dot status-${friend.status_type}`} />
                      <span className="friend-info">
                        <span className="friend-name">{friend.display_name || friend.username}</span>
                        <span className="friend-detail">
                          {friend.status_type === 'offline'
                            ? 'Offline'
                            : gameName(friend.current_game_id) ??
                              (friend.status_text || STATUS_LABEL[friend.status_type])}
                        </span>
                      </span>
                      {unread[friend.id] ? <span className="badge">{unread[friend.id]}</span> : null}
                    </button>
                  ))}
              </div>
            );
          })}
        </div>

        <footer className="sidebar-footer">
          {friends.length} {friends.length === 1 ? 'friend' : 'friends'} · {onlineCount} online
        </footer>

        {notice && <div className="toast">{notice}</div>}
      </aside>

      <main className="main">
        {activeFriend ? (
          <ChatWindow
            key={activeFriend.id}
            meId={meId}
            friend={activeFriend}
            gameName={gameName(activeFriend.current_game_id)}
            onRead={handleRead}
          />
        ) : (
          <div className="empty">
            <div className="flame flame-large">◆</div>
            <h1>MacFire</h1>
            <p className="muted">
              Pick a friend to chat, or add someone by username. Set your game above so friends see
              what you are playing.
            </p>
          </div>
        )}
      </main>
    </div>
  );
}

function AddFriend({ onSubmit }: { onSubmit: (username: string) => Promise<string> }) {
  const [username, setUsername] = useState('');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<string | null>(null);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setResult(await onSubmit(username));
    setBusy(false);
    setUsername('');
  }

  return (
    <form className="add-friend" onSubmit={submit}>
      <input
        value={username}
        onChange={(event) => setUsername(event.target.value)}
        placeholder="username"
        aria-label="Friend username"
      />
      <button className="primary small" type="submit" disabled={busy}>
        {busy ? '…' : 'Send'}
      </button>
      {result && <div className="hint">{result}</div>}
    </form>
  );
}
