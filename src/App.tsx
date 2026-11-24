import { useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import { isConfigured, supabase } from './lib/supabase';
import AuthScreen from './components/AuthScreen';
import Messenger from './components/Messenger';
import SetupScreen from './components/SetupScreen';

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(isConfigured);

  useEffect(() => {
    if (!isConfigured) return;

    void supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setLoading(false);
    });

    const { data } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next);
    });

    return () => data.subscription.unsubscribe();
  }, []);

  if (!isConfigured) return <SetupScreen />;
  if (loading) return <div className="boot">Connecting to MacFire…</div>;
  if (!session) return <AuthScreen />;

  return <Messenger session={session} />;
}
