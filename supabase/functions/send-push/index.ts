// send-push — delivers one bell notification to the person's phones and computers.
//
// Called only by the database (a trigger on notifications), with a shared secret. It:
//   1. checks the secret, so nobody else can make phones buzz;
//   2. skips the person's quiet hours (Kampala time);
//   3. sends the alert to each registered device, and forgets devices that no longer exist.
// Keys live in Supabase Vault (encrypted) and are read through public.push_config(), which only the server key may call.
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3";

const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const APP_URL = (Deno.env.get("APP_URL") ?? "https://icon-extreme.pages.dev").replace(/\/$/, "");

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

// read the keys once per function start-up
let config: Promise<Record<string, string>> | null = null;
const keys = () =>
  (config ??= (async () => {
    const { data, error } = await db.rpc("push_config");
    if (error) throw new Error(error.message);
    const c = (data ?? {}) as Record<string, string>;
    webpush.setVapidDetails("https://icon-site-bv6.pages.dev", c.vapid_public_key, c.vapid_private_key);
    return c;
  })());

function inQuietHours(from: number | null, to: number | null): boolean {
  if (from == null || to == null || from === to) return false;
  const hour = (new Date().getUTCHours() + 3) % 24; // Kampala is UTC+3 all year
  return from < to ? hour >= from && hour < to : hour >= from || hour < to; // e.g. 20 -> 7 wraps past midnight
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Use POST." });
  let c: Record<string, string>;
  try { c = await keys(); } catch (e) { config = null; console.error("config", (e as Error).message); return json(500, { error: "not configured" }); }
  if (!c.push_hook_secret || req.headers.get("x-push-secret") !== c.push_hook_secret) return json(401, { error: "not allowed" });

  let id: number;
  try { id = Number((await req.json()).notification_id); } catch { return json(400, { error: "bad request" }); }
  if (!Number.isInteger(id)) return json(400, { error: "bad request" });

  const { data: n } = await db.from("notifications").select("id,user_id,kind,title,body,link").eq("id", id).maybeSingle();
  if (!n) return json(404, { error: "not found" });

  const { data: who } = await db.from("profiles").select("is_active,quiet_from,quiet_to").eq("id", n.user_id).maybeSingle();
  if (!who?.is_active) return json(200, { sent: 0, reason: "inactive" });
  if (n.kind !== "test" && inQuietHours(who.quiet_from, who.quiet_to)) return json(200, { sent: 0, reason: "quiet hours" });

  const { data: devices } = await db.from("push_subscriptions").select("id,endpoint,p256dh,auth").eq("user_id", n.user_id);
  const payload = JSON.stringify({
    title: n.title,
    body: n.body ?? "",
    url: `${APP_URL}/#${n.link ?? "/"}`, // the app uses #/ addresses
    tag: `icon-${n.kind}`,
  });

  let sent = 0;
  for (const d of devices ?? []) {
    try {
      await webpush.sendNotification({ endpoint: d.endpoint, keys: { p256dh: d.p256dh, auth: d.auth } }, payload, { TTL: 86400 });
      sent++;
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) await db.from("push_subscriptions").delete().eq("id", d.id); // device gone
      else console.error("push failed", code, (e as Error).message);
    }
  }
  return json(200, { sent });
});
