// invite-user — lets an admin bring a person into the platform.
//
// What it does, in plain words:
//   1. Checks the caller is a signed-in, active admin or super admin (anyone else gets "not allowed").
//   2. Creates the person's account and an invite link. The link is returned to the admin, who can send it
//      by WhatsApp or email. (No email service needed. Supabase's own mail only reaches a few addresses.)
//   3. Sets their role, switches the account on, and links a client to their project.
//   4. Writes who did it into the activity log.
// The service key lives only here, on the server. It never reaches the app.
import { createClient } from "npm:@supabase/supabase-js@2";

const APP_URL = (Deno.env.get("APP_URL") ?? "https://icon-extreme.pages.dev").replace(/\/$/, "");
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const INVITABLE = ["admin", "project_manager", "editor", "support", "client"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "Use POST." });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  // 1. who is calling?
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json(401, { error: "Please sign in again." });
  const { data: who } = await db.auth.getUser(token);
  const caller = who?.user;
  if (!caller) return json(401, { error: "Please sign in again." });

  const { data: me } = await db.from("profiles").select("role,is_active").eq("id", caller.id).maybeSingle();
  if (!me?.is_active || !["super_admin", "admin"].includes(me.role)) {
    return json(403, { error: "Only administrators can invite people." });
  }

  // 2. what are they asking for?
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json(400, { error: "Bad request." }); }
  const email = String(body.email ?? "").trim().toLowerCase();
  const fullName = String(body.full_name ?? "").trim().slice(0, 120);
  const role = String(body.role ?? "client");
  const projectId = body.project_id == null || body.project_id === "" ? null : Number(body.project_id);

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json(400, { error: "That email address does not look right." });
  if (!INVITABLE.includes(role)) return json(400, { error: "That role cannot be given by invitation." });
  if (role === "admin" && me.role !== "super_admin") return json(403, { error: "Only a super admin can invite an admin." });
  if (projectId !== null && (!Number.isInteger(projectId) || role !== "client")) {
    return json(400, { error: "Only clients can be linked to a project." });
  }
  if (projectId !== null) {
    const { data: p } = await db.from("projects").select("id").eq("id", projectId).maybeSingle();
    if (!p) return json(400, { error: "That project was not found." });
  }

  // 3. create the account + invite link (or reuse the account if it already exists)
  let userId: string;
  let link: string | null = null;
  const created = await db.auth.admin.generateLink({
    type: "invite",
    email,
    options: { data: fullName ? { full_name: fullName } : {} },
  });
  if (created.error || !created.data?.user) {
    const { data: existing } = await db.from("profiles").select("id").eq("email", email).maybeSingle();
    if (!existing) return json(400, { error: "Could not create that invitation. Check the email and try again." });
    userId = existing.id;
    const target = await db.from("profiles").select("role").eq("id", userId).single();
    if (["super_admin", "admin"].includes(target.data?.role ?? "") && me.role !== "super_admin") {
      return json(403, { error: "That person is an administrator. Only a super admin can change them." });
    }
    if (userId === caller.id) return json(400, { error: "You cannot change your own access." });
  } else {
    userId = created.data.user.id;
    link = `${APP_URL}/#/accept?token_hash=${encodeURIComponent(created.data.properties.hashed_token)}&type=invite`;
  }

  // 4. role, switch on, project link
  const patch: Record<string, unknown> = { role, is_active: true, approved_at: new Date().toISOString() };
  if (fullName) patch.full_name = fullName;
  const upd = await db.from("profiles").update(patch).eq("id", userId);
  if (upd.error) return json(500, { error: "The account was created but its role could not be set. Try again." });
  if (projectId !== null) await db.from("projects").update({ client_id: userId }).eq("id", projectId);

  // 5. activity log
  await db.from("audit_log").insert({
    actor: caller.id, action: "INVITE", table_name: "profiles", row_id: userId,
    new_data: { email, role, project_id: projectId, link_created: link !== null },
  });

  return json(200, {
    ok: true,
    email,
    existing: link === null,
    link,
    message: link === null
      ? "That person already has an account. Their access has been updated, and they can sign in."
      : "Invitation created. Send them the link.",
  });
});
