# AutoContact

A crew shares a roster, and every member can import everyone into their phone's Contacts in one step.

```
Flutter app (Android/iOS)  ->  Next.js API (api/, on Vercel)  ->  Supabase (Postgres + Auth)
```

## Layout

- `supabase/migrations/`: `001_init.sql` creates `groups` and `members`; `002_profiles_short_codes.sql` adds `profiles` (one contact card per user, shared by all their groups) and switches join codes to `ABC123`. RLS is on with no policies, so only the API (service role) can touch them.
- `api/`: Next.js route handlers. Every route requires `Authorization: Bearer <Supabase access token>`.
- `app/`: the Flutter app (Android + iOS). Bundle/application ID: `com.aquatichan.autocontact`.

## API

| Route | Body | Returns |
| --- | --- | --- |
| `GET /api/profile` | | `{ profile }`: your card, or `null` before onboarding |
| `PUT /api/profile` | `{ first_name, last_name?, phones?, emails?, company?, job_title?, website?, address?, birthday? }` | `{ profile }`. Replaces your card; every group shows it at once. |
| `GET /api/groups` | | `{ groups }`: groups you own or belong to |
| `POST /api/groups` | `{ name }` | `{ group }` with its `join_code` (201). You're added to the roster. |
| `POST /api/groups/join` | `{ code }` | `{ group, member }`. Idempotent. |
| `GET /api/groups/[id]` | | `{ group, members, me_id }`. Each member is a card plus `user_id` and `is_owner`. 403 unless you're in the group. |

`phones` is a list of `{ label, number }` (labels: mobile, iphone, home, work, main, pager, other) and `emails` a list of `{ label, address }` (home, work, school, icloud, other), up to 5 each. `birthday` is `YYYY-MM-DD`.

Join codes are 3 letters then 3 digits, shown as `ABC-123`. Input is case-insensitive and ignores dashes and spaces; `0`/`O` and `1`/`I` are fixed by position. That's about 17.6M codes, so joining is capped at 10 wrong codes per account per 15 minutes (`join_failures`, migration 003). Someone with many accounts could still guess; use longer codes before real use.

## Setup

1. Create a Supabase project. In the SQL editor, run each file in `supabase/migrations/` in order.
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

In Supabase's Google provider, put the Web, iOS and Android client IDs in **Client IDs** (comma-separated, Web first), the Web client's secret in **Client Secret**, and turn on **Skip nonce check** (iOS sign-in fails without it).

Then:

1. `cp app/config.example.json app/config.json` and fill it in. Use the Supabase **publishable** (or legacy anon) key, never the service-role key.
2. `cp app/ios/Flutter/GoogleSignIn.xcconfig.example app/ios/Flutter/GoogleSignIn.xcconfig` and fill in the iOS client ID and its reversed form.
3. Run on a device:
   ```bash
   cd app && flutter run --dart-define-from-file=config.json
   ```
   On iOS, open `app/ios/Runner.xcworkspace` in Xcode once and pick your team under Signing & Capabilities.

**L13 step 2 is done when** you can sign in on each phone and land on "Your groups" showing "No groups yet." (a 200 from `GET /api/groups`).

## What the app does

- **Onboarding:** after first sign-in you set up your card once (or fill it from your own contact in the phone). Every group uses it.
- **Groups:** create one or join with a code; lists refresh every 10 seconds while open, on returning to the app, and on pull-down.
- **Sync to Contacts:** adds new people and merges new numbers, emails and details into people you already have. It never deletes anything or renames anyone.
- **Cards:** tap anyone to see their card; your own card has a QR code any phone camera can scan to add you, no app needed.
