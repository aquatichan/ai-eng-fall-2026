import { requireUser } from "@/lib/auth";
import { error, isUuid, json } from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

// GET /api/groups/[id]: the group and its roster. Only for its owner or members.
export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;

  const { id } = await ctx.params;
  if (!isUuid(id)) return error(404, "Group not found");

  const db = supabaseAdmin();
  const { data: group, error: gErr } = await db
    .from("groups")
    .select("id, name, join_code, owner_id, created_at")
    .eq("id", id)
    .maybeSingle();
  if (gErr) return error(500, gErr.message);
  if (!group) return error(404, "Group not found");

  const { data: members, error: mErr } = await db
    .from("members")
    .select("id, user_id, name, phone, email, org, created_at")
    .eq("group_id", id)
    .order("name", { ascending: true });
  if (mErr) return error(500, mErr.message);

  const me = members.find((m) => m.user_id === user.id) ?? null;
  const isOwner = group.owner_id === user.id;
  if (!me && !isOwner) return error(403, "You are not a member of this group");

  return json({ group: { ...group, is_owner: isOwner }, members, me });
}
