export type StatusType = 'online' | 'away' | 'busy' | 'offline' | 'afk';

export interface Profile {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  status_text: string;
  status_type: StatusType;
  current_game_id: string | null;
  game_server_name: string | null;
  last_seen_online: string | null;
  is_idle: boolean;
  itunes_status: string | null;
}

export interface Game {
  id: string;
  name: string;
  short_name: string | null;
  icon_url: string | null;
  category: string | null;
}

export interface FriendGroup {
  id: string;
  user_id: string;
  name: string;
  sort_order: number;
  is_expanded: boolean;
}

export interface FriendRequest {
  id: string;
  sender_id: string;
  receiver_id: string;
  message: string | null;
  status: 'pending' | 'accepted' | 'declined' | 'deferred';
  created_at: string;
}

export interface ChatMessage {
  id: string;
  sender_id: string;
  receiver_id: string;
  content: string;
  is_read: boolean;
  created_at: string;
}
