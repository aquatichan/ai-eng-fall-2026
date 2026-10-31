import type { SupabaseClient, User } from "@supabase/supabase-js";
import { displayName } from "./auth";
import { memberColumns, parseCard } from "./card";

// Adds you to a group (no-op if you're already in it), filling the legacy
// member columns from your profile, or your Google account before onboarding.
export async function ensureMember(db: SupabaseClient, groupId: string, user: User) {
  const { data: profile, error: pErr } = await db.from("profiles").select("*").eq("user_id", user.id).maybeSingle();
  if (pErr) return pErr;
  const columns = profile
    ? memberColumns(parseCard(profile), user)
    : { name: displayName(user), email: user.email ?? "", phone: null, org: null };

  const { error } = await db
    .from("members")
    .upsert({ group_id: groupId, user_id: user.id, ...columns }, { onConflict: "group_id,user_id", ignoreDuplicates: true });
  return error;
}
