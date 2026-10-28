# AutoContact

A crew shares a roster, and every member can import everyone into their phone's Contacts in one step.

```
Flutter app (Android/iOS)  ->  Next.js API (api/, on Vercel)  ->  Supabase (Postgres + Auth)
```

## Layout

- `supabase/migrations/001_init.sql`: the `groups` and `members` tables. RLS is on with no policies, so only the API (service role) can touch them.
- `api/`: Next.js route handlers. Every route requires `Authorization: Bearer <Supabase access token>`.
- `app/`: the Flutter app (Android + iOS). Bundle/application ID: `com.aquatichan.autocontact`.

## API

| Route | Body | Returns |
| --- | --- | --- |
| `GET /api/groups` | | `{ groups }`: groups you own or belong to |
| `POST /api/groups` | `{ name }` | `{ group }` with its `join_code` (201). The owner is **not** added as a member. |
| `POST /api/groups/join` | `{ code }` | `{ group, member }`. Creates your entry from your Google profile; idempotent. |
| `POST /api/members` | `{ group_id, name, phone?, email?, org? }` | `{ member }`. Upserts your own entry; you must own or have joined the group. |
| `GET /api/groups/[id]` | | `{ group, members, me }`. 403 unless you're the owner or a member. |

Join codes are 12 Crockford base32 characters (no I/L/O/U). Input is case-insensitive and ignores dashes and spaces, so `abcd-efgh-jkmn` works.

## Setup

1. Create a Supabase project. In the SQL editor, run `supabase/migrations/001_init.sql`.
2. Copy `api/.env.example` to `api/.env.local` and fill in `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (Project Settings → API).
3. Run locally:
   ```bash
   cd api && npm install && npm run dev
   ```
4. Deploy: import the repo in Vercel, set **Root Directory** to `api`, and add the same two env vars.
5. Check it: `curl https://<your-app>.vercel.app/api/groups` should return `401 {"error":"Missing bearer token"}`.

## Flutter app setup (Google Sign-In)

You need three OAuth clients in one Google Cloud project (APIs & Services → Credentials → Create credentials → OAuth client ID). Set up the OAuth consent screen first, and add both demo Google accounts as test users.

| Client type | Settings | Used for |
| --- | --- | --- |
| **Web application** | none | `GOOGLE_WEB_CLIENT_ID` in `app/config.json`, **and** Supabase → Authentication → Providers → Google (Client IDs + Client Secret) |
| **Android** | package `com.aquatichan.autocontact`, SHA-1 from `cd app/android && ./gradlew signingReport` (debug variant) | nothing to paste; Google matches the package + SHA-1 |
| **iOS** | bundle ID `com.aquatichan.autocontact` | `app/ios/Flutter/GoogleSignIn.xcconfig` |

In Supabase's Google provider, also turn on **Skip nonce check** (iOS sign-in fails without it).

Then:

1. `cp app/config.example.json app/config.json` and fill it in. Use the Supabase **publishable** (or legacy anon) key, never the service-role key.
2. `cp app/ios/Flutter/GoogleSignIn.xcconfig.example app/ios/Flutter/GoogleSignIn.xcconfig` and fill in the iOS client ID and its reversed form.
3. Run on a device:
   ```bash
   cd app && flutter run --dart-define-from-file=config.json
   ```
   On iOS, open `app/ios/Runner.xcworkspace` in Xcode once and pick your team under Signing & Capabilities.

**L13 step 2 is done when** you can sign in on each phone and land on "Your groups" showing "No groups yet." (a 200 from `GET /api/groups`).
