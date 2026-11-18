// submit-lead — the public website's contact / quote form posts here.
//
// Why a function and not a direct insert: strangers may NOT write to the database. This function is the one
// narrow door. It checks the message, blocks spam and floods, then saves it as a lead using the server key.
// The key lives only here; it never reaches the website.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const clean = (v: unknown, max: number) => String(v ?? "").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "").trim().slice(0, max);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "Use POST." });

  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return json(400, { error: "Bad request." }); }

  // Spam trap 1: a hidden field real people never fill. Pretend success so bots learn nothing.
  if (clean(b.website, 200) !== "") return json(200, { ok: true });
  // Spam trap 2: a form filled in under 3 seconds is a bot.
  const openedAt = Number(b.opened_at);
  if (Number.isFinite(openedAt) && Date.now() - openedAt < 3000) return json(200, { ok: true });

  const fullName = clean(b.full_name, 120);
  const email = clean(b.email, 200).toLowerCase();
  const phone = clean(b.phone, 40) || null;
  const message = clean(b.message, 4000);
  const projectType = clean(b.project_type, 120) || null;
  const location = clean(b.location, 160) || null;
  const kind = b.kind === "quote" ? "quote" : "contact";
  const preferred = ["phone", "email", "whatsapp"].includes(String(b.preferred_contact)) ? String(b.preferred_contact) : null;

  if (fullName.length < 2) return json(400, { error: "Please tell us your name." });
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json(400, { error: "That email address does not look right." });
  if (message.length < 10) return json(400, { error: "Please write a little more about what you need." });
  // links in the message are the most common spam signal
  if ((message.match(/https?:\/\//gi) ?? []).length > 2) return json(400, { error: "Please remove the extra links." });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  // Flood limits: 3 per email per hour, 60 per hour for the whole site.
  const since = new Date(Date.now() - 3600_000).toISOString();
  const [{ count: mine }, { count: all }] = await Promise.all([
    db.from("leads").select("id", { count: "exact", head: true }).eq("email", email).gte("created_at", since),
    db.from("leads").select("id", { count: "exact", head: true }).eq("source", "website").gte("created_at", since),
  ]);
  if ((mine ?? 0) >= 3) return json(429, { error: "We already have your messages. We will reply soon." });
  if ((all ?? 0) >= 60) return json(429, { error: "Too many messages right now. Please call us instead." });

  const { error } = await db.from("leads").insert({
    kind, full_name: fullName, email, phone, message, project_type: projectType, location,
    preferred_contact: preferred, source: "website",
  });
  if (error) {
    console.error("lead insert failed", error.message);
    return json(500, { error: "Sorry, something went wrong. Please call or WhatsApp us." });
  }
  return json(200, { ok: true });
});
