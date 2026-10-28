import type { User } from "@supabase/supabase-js";
import { error } from "./http";
import { supabaseAdmin } from "./supabaseAdmin";

// Verifies the Supabase access token from `Authorization: Bearer <token>`.
// Returns the user, or a 401 Response to send back as-is.
export async function requireUser(req: Request): Promise<User | Response> {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return error(401, "Missing bearer token");

  const { data, error: authError } = await supabaseAdmin().auth.getUser(match[1]);
  if (authError || !data.user) return error(401, "Invalid or expired token");
  return data.user;
}

// Display name from the Google profile, falling back to the email's local part.
export function displayName(user: User): string {
  const meta = user.user_metadata ?? {};
  const name = (meta.full_name ?? meta.name ?? "").toString().trim();
  return (name || (user.email ?? "").split("@")[0] || "Member").slice(0, 100);
}
