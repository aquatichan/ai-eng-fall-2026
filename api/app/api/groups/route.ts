import { requireUser } from "@/lib/auth";
import { error, json, readJsonObject, requiredString, ValidationError } from "@/lib/http";
import { generateJoinCode } from "@/lib/joinCode";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

const GROUP_COLUMNS = "id, name, join_code, owner_id, created_at";

// GET /api/groups: groups you own or belong to, newest first.
export async function GET(req: Request) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;
  const db = supabaseAdmin();

  const { data: memberships, error: mErr } = await db
    .from("members")
    .select("group_id")
    .eq("user_id", user.id);
  if (mErr) return error(500, mErr.message);

  const memberGroupIds = memberships.map((m) => m.group_id as string);
  let query = db.from("groups").select(GROUP_COLUMNS);
  query = memberGroupIds.length
    ? query.or(`owner_id.eq.${user.id},id.in.(${memberGroupIds.join(",")})`)
    : query.eq("owner_id", user.id);

  const { data: groups, error: gErr } = await query.order("created_at", { ascending: false });
  if (gErr) return error(500, gErr.message);

  return json({
    groups: groups.map((g) => ({ ...g, is_owner: g.owner_id === user.id })),
  });
}

// POST /api/groups { name }: creates a group you own and returns its join code.
// The owner is not added as a member; they add themselves via POST /api/members.
export async function POST(req: Request) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;

  const body = await readJsonObject(req);
  if (!body) return error(400, "Body must be a JSON object");
  let name: string;
  try {
    name = requiredString(body.name, "name", 100);
  } catch (e) {
    if (e instanceof ValidationError) return error(400, e.message);
    throw e;
  }

  // A join_code collision is astronomically unlikely, but retry just in case.
  for (let attempt = 0; attempt < 3; attempt++) {
    const { data, error: insErr } = await supabaseAdmin()
      .from("groups")
      .insert({ name, join_code: generateJoinCode(), owner_id: user.id })
      .select(GROUP_COLUMNS)
      .single();
    if (!insErr) return json({ group: { ...data, is_owner: true } }, 201);
    if (insErr.code !== "23505") return error(500, insErr.message);
  }
  return error(500, "Could not generate a unique join code");
}
