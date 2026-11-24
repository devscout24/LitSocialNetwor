import { getSupabaseClient, isSupabaseConfigured } from "./lib/supabase";

export function App() {
  const configured = isSupabaseConfigured();
  if (configured) {
    getSupabaseClient();
  }

  return (
    <main className="dashboard-shell">
      <section className="dashboard-card">
        <h1>Lit Social — Dashboard</h1>
        <p className="subtitle">
          Admin dashboard placeholder — under construction for future use.
        </p>
        <div
          className={`status-badge ${configured ? "status-ok" : "status-pending"}`}
        >
          Supabase: {configured ? "configured" : "not configured"}
        </div>
      </section>
    </main>
  );
}

export default App;
