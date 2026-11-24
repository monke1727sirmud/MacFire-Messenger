import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';
import type { ChatMessage, Profile } from '../types';

type Props = {
  meId: string;
  friend: Profile;
  gameName: string | null;
  onRead: (friendId: string) => void;
};

function timeOf(iso: string): string {
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

export default function ChatWindow({ meId, friend, gameName, onRead }: Props) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [friendTyping, setFriendTyping] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scroller = useRef<HTMLDivElement | null>(null);
  const lastTypingSent = useRef(0);

  const markRead = useCallback(async () => {
    await supabase
      .from('chat_messages')
      .update({ is_read: true })
      .eq('sender_id', friend.id)
      .eq('receiver_id', meId)
      .eq('is_read', false);
    onRead(friend.id);
  }, [friend.id, meId, onRead]);

  // History for this conversation.
  useEffect(() => {
    let alive = true;

    async function load() {
      const { data, error: loadError } = await supabase
        .from('chat_messages')
        .select('*')
        .or(
          `and(sender_id.eq.${meId},receiver_id.eq.${friend.id}),and(sender_id.eq.${friend.id},receiver_id.eq.${meId})`,
        )
        .order('created_at', { ascending: true })
        .limit(300);

      if (!alive) return;
      if (loadError) {
        setError(loadError.message);
        return;
      }

      setMessages((data ?? []) as ChatMessage[]);
      await markRead();
    }

    void load();
    return () => {
      alive = false;
    };
  }, [meId, friend.id, markRead]);

  // Live messages and typing state for this conversation.
  useEffect(() => {
    const channel = supabase
      .channel(`macfire-chat-${meId}-${friend.id}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'chat_messages', filter: `sender_id=eq.${friend.id}` },
        (payload) => {
          const message = payload.new as ChatMessage;
          if (message.receiver_id !== meId) return;
          setMessages((current) =>
            current.some((existing) => existing.id === message.id) ? current : [...current, message],
          );
          void markRead();
        },
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'chat_messages', filter: `sender_id=eq.${meId}` },
        (payload) => {
          const message = payload.new as ChatMessage;
          if (message.receiver_id !== friend.id) return;
          setMessages((current) =>
            current.some((existing) => existing.id === message.id) ? current : [...current, message],
          );
        },
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'typing_indicators', filter: `sender_id=eq.${friend.id}` },
        (payload) => {
          const row = payload.new as { receiver_id?: string; is_typing?: boolean };
          if (row.receiver_id !== meId) return;
          setFriendTyping(Boolean(row.is_typing));
        },
      )
      .subscribe();

    return () => {
      setFriendTyping(false);
      void supabase.removeChannel(channel);
    };
  }, [meId, friend.id, markRead]);

  // Keep the newest message in view.
  useEffect(() => {
    const node = scroller.current;
    if (node) node.scrollTop = node.scrollHeight;
  }, [messages.length, friendTyping]);

  async function setTyping(isTyping: boolean) {
    await supabase.from('typing_indicators').upsert(
      {
        sender_id: meId,
        receiver_id: friend.id,
        is_typing: isTyping,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'sender_id,receiver_id' },
    );
  }

  function handleDraft(value: string) {
    setDraft(value);
    const now = Date.now();
    if (value && now - lastTypingSent.current > 2500) {
      lastTypingSent.current = now;
      void setTyping(true);
    }
    if (!value) void setTyping(false);
  }

  async function send(event: FormEvent) {
    event.preventDefault();
    const content = draft.trim();
    if (!content) return;

    setDraft('');
    setError(null);
    void setTyping(false);

    const { error: sendError } = await supabase
      .from('chat_messages')
      .insert({ sender_id: meId, receiver_id: friend.id, content });

    if (sendError) setError(sendError.message);
  }

  return (
    <section className="chat">
      <header className="chat-header">
        <span className={`dot status-${friend.status_type}`} />
        <div>
          <div className="chat-name">{friend.display_name || friend.username}</div>
          <div className="chat-sub">
            {friendTyping
              ? 'typing…'
              : friend.status_type === 'offline'
                ? 'Offline'
                : gameName ?? (friend.status_text || friend.status_type)}
          </div>
        </div>
      </header>

      <div className="messages" ref={scroller}>
        {messages.length === 0 && (
          <p className="muted pad">No messages yet. Say hello to {friend.display_name || friend.username}.</p>
        )}

        {messages.map((message) => {
          const mine = message.sender_id === meId;
          return (
            <div key={message.id} className={`bubble-row ${mine ? 'mine' : 'theirs'}`}>
              <div className={`bubble ${mine ? 'bubble-mine' : 'bubble-theirs'}`}>
                <div className="bubble-text">{message.content}</div>
                <div className="bubble-time">{timeOf(message.created_at)}</div>
              </div>
            </div>
          );
        })}
      </div>

      {error && <div className="error chat-error">{error}</div>}

      <form className="composer" onSubmit={send}>
        <input
          value={draft}
          onChange={(event) => handleDraft(event.target.value)}
          onBlur={() => void setTyping(false)}
          placeholder={`Message ${friend.display_name || friend.username}`}
          aria-label="Message"
        />
        <button className="primary" type="submit" disabled={!draft.trim()}>
          Send
        </button>
      </form>
    </section>
  );
}
