import { requireUser } from "@/lib/auth";
import { memberColumns, parseCard, PROFILE_COLUMNS } from "@/lib/card";
import { error, json, readJsonObject, ValidationError } from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

// GET /api/profile: your contact card, or { profile: null } before onboarding.
export async function GET(req: Request) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;

  const { data, error: pErr } = await supabaseAdmin()
    .from("profiles")
    .select(PROFILE_COLUMNS)
    .eq("user_id", user.id)
    .maybeSingle();
  if (pErr) return error(500, pErr.message);
  return json({ profile: data });
}

// PUT /api/profile { first_name, last_name?, phones?, emails?, company?, job_title?,
// website?, address?, birthday? }: creates or replaces your card. Every group
// you're in shows the new card right away.
export async function PUT(req: Request) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;

  const body = await readJsonObject(req);
  if (!body) return error(400, "Body must be a JSON object");
  let card;
  try {
    card = parseCard(body);
  } catch (e) {
    if (e instanceof ValidationError) return error(400, e.message);
    throw e;
  }

  const db = supabaseAdmin();
  const { data, error: upErr } = await db
    .from("profiles")
    .upsert({ user_id: user.id, ...card, updated_at: new Date().toISOString() })
    .select(PROFILE_COLUMNS)
    .single();
  if (upErr) return error(500, upErr.message);

  const { error: mErr } = await db.from("members").update(memberColumns(card, user)).eq("user_id", user.id);
  if (mErr) return error(500, mErr.message);

  return json({ profile: data });
}
