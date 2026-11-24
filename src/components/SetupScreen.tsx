export default function SetupScreen() {
  return (
    <div className="center-screen">
      <div className="card setup">
        <div className="brand brand-large">
          <span className="flame">◆</span> MacFire
        </div>
        <h1>Connect a Supabase project</h1>
        <p>
          The client is built, but it has no backend to talk to yet. Run the migrations in{' '}
          <code>supabase/migrations</code> against a Supabase project, then add its URL and anon key
          to <code>.env</code>:
        </p>
        <pre>{`VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key`}</pre>
        <p className="muted">
          Restart the dev server after changing <code>.env</code>. New sign-ups get a profile, default
          settings and a “Friends” group automatically.
        </p>
      </div>
    </div>
  );
}
