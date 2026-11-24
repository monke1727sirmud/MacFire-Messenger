import { useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';

type Mode = 'signin' | 'signup';

export default function AuthScreen() {
  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);

    if (mode === 'signup') {
      const clean = username.trim().toLowerCase();
      if (!/^[a-z0-9_.-]{3,24}$/.test(clean)) {
        setError('Username must be 3–24 characters: letters, numbers, dot, dash or underscore.');
        setBusy(false);
        return;
      }

      const { data, error: err } = await supabase.auth.signUp({
        email: email.trim(),
        password,
        options: { data: { username: clean, display_name: username.trim() } },
      });

      setBusy(false);
      if (err) {
        setError(err.message);
        return;
      }
      if (!data.session) setSent(true);
      return;
    }

    const { error: err } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    setBusy(false);
    if (err) setError(err.message);
  }

  if (sent) {
    return (
      <div className="center-screen">
        <div className="card">
          <div className="brand brand-large">
            <span className="flame">◆</span> MacFire
          </div>
          <h1>Check your inbox</h1>
          <p className="muted">
            We sent a confirmation link to <strong>{email}</strong>. Follow it, then sign in.
          </p>
          <button className="primary" onClick={() => { setSent(false); setMode('signin'); }}>
            Back to sign in
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="center-screen">
      <form className="card" onSubmit={submit}>
        <div className="brand brand-large">
          <span className="flame">◆</span> MacFire
        </div>
        <p className="muted">Gaming messenger — friends, game status, and chat.</p>

        <label>
          <span>Email</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            required
          />
        </label>

        {mode === 'signup' && (
          <label>
            <span>Username</span>
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoComplete="username"
              placeholder="player_one"
              required
            />
          </label>
        )}

        <label>
          <span>Password</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete={mode === 'signup' ? 'new-password' : 'current-password'}
            minLength={6}
            required
          />
        </label>

        {error && <div className="error">{error}</div>}

        <button className="primary" type="submit" disabled={busy}>
          {busy ? 'Working…' : mode === 'signup' ? 'Create account' : 'Sign in'}
        </button>

        <button
          className="link"
          type="button"
          onClick={() => { setMode(mode === 'signin' ? 'signup' : 'signin'); setError(null); }}
        >
          {mode === 'signin' ? 'No account? Create one' : 'Have an account? Sign in'}
        </button>
      </form>
    </div>
  );
}
