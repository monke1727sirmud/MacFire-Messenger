import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const url = (import.meta.env.VITE_SUPABASE_URL ?? '').trim();
const anonKey = (import.meta.env.VITE_SUPABASE_ANON_KEY ?? '').trim();

export const isConfigured = url.length > 0 && anonKey.length > 0;

/**
 * The client is only exercised when `isConfigured` is true. The placeholders
 * keep the type non-nullable so components don't need null checks everywhere.
 */
export const supabase: SupabaseClient = createClient(
  isConfigured ? url : 'https://unconfigured.supabase.co',
  isConfigured ? anonKey : 'unconfigured-anon-key',
  { auth: { persistSession: true, autoRefreshToken: true } },
);
