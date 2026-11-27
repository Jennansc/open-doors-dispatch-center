/* Open Doors Dispatch Center — Supabase persistence adapter.
 * Uses Supabase Auth anonymous sessions for a private, per-user training snapshot.
 * Never place a service_role key in this browser application.
 */
(function () {
  "use strict";

  const config = window.OD_SUPABASE_CONFIG || {};
  const url = String(config.url || "").trim();
  const anonKey = String(config.anonKey || "").trim();
  const configured = Boolean(
    url &&
    anonKey &&
    !anonKey.toLowerCase().includes("paste_") &&
    !anonKey.toLowerCase().includes("your_") &&
    !anonKey.toLowerCase().includes("replace")
  );

  let client = null;
  let userId = null;
  let initPromise = null;
  let writeQueue = Promise.resolve();

  function setStatus(message, state) {
    if (typeof window.odSetBackendStatus === "function") {
      window.odSetBackendStatus(message, state || "info");
    }
  }

  async function init() {
    if (!configured) {
      setStatus("Local mode — add Supabase URL and anon key to supabase-config.js.", "local");
      return null;
    }
    if (initPromise) return initPromise;

    initPromise = (async function () {
      if (!window.supabase || typeof window.supabase.createClient !== "function") {
        throw new Error("Supabase client library did not load.");
      }

      setStatus("Connecting to Supabase…", "syncing");
      client = window.supabase.createClient(url, anonKey, {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: true
        }
      });

      const sessionResult = await client.auth.getSession();
      if (sessionResult.error) throw sessionResult.error;

      let session = sessionResult.data && sessionResult.data.session;
      if (!session) {
        const authResult = await client.auth.signInAnonymously();
        if (authResult.error) throw authResult.error;
        session = authResult.data && authResult.data.session;
      }

      if (!session || !session.user) {
        throw new Error("Supabase did not return an authenticated user session.");
      }

      userId = session.user.id;
      const result = await client
        .from("dispatch_state")
        .select("state, updated_at")
        .eq("user_id", userId)
        .maybeSingle();

      if (result.error) throw result.error;
      setStatus("Supabase connected · private training data", "connected");
      return result.data ? result.data.state : null;
    })();

    try {
      return await initPromise;
    } catch (error) {
      initPromise = null;
      client = null;
      userId = null;
      setStatus("Cloud connection failed — local data remains available.", "error");
      throw error;
    }
  }

  function saveState(state) {
    if (!configured || !client || !userId) {
      return Promise.resolve({ remote: false });
    }

    // Freeze each save's data so queued writes cannot read a later mutated object.
    const snapshot = JSON.parse(JSON.stringify(state));
    writeQueue = writeQueue.catch(function () { /* allow a later save to retry after a transient failure */ }).then(async function () {
      setStatus("Syncing dispatch data…", "syncing");
      const result = await client
        .from("dispatch_state")
        .upsert({
          user_id: userId,
          state: snapshot,
          updated_at: new Date().toISOString()
        }, { onConflict: "user_id" });

      if (result.error) throw result.error;
      setStatus("Cloud synced · dispatch data saved", "connected");
      return { remote: true };
    });

    return writeQueue;
  }

  window.dispatchBackend = {
    isConfigured: function () { return configured; },
    init: init,
    saveState: saveState
  };
})();
