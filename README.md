# Lady K ★ Fih — dynamic art portfolio

A responsive React + TypeScript portfolio with Supabase Auth, Postgres and **private** Supabase Storage. Tag-based categories are derived from each artwork's tags; a piece appears in multiple galleries without duplication. The NSFW toggle defaults OFF and asks for age confirmation before revealing adult artwork. Gallery images use expiring signed URLs from a private bucket.

## Setup and deployment

1. Create a Supabase project at https://supabase.com/dashboard and run `supabase/schema.sql` in its SQL Editor.
2. In Supabase Authentication → Users, create one admin account. Set its password privately in Supabase (do not put the password in project files, Netlify variables, or browser code). Supabase verifies it securely; the star opens a single password prompt (no email field or separate login screen). The admin email is configured as a Netlify build variable, so only you enter the password. Promote the account through trusted SQL, replacing the email with the admin account: `update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb where email = 'ADMIN_EMAIL';` Never put the role in `user_metadata`, since users can change that themselves. Disable public signups under Authentication → Settings.
3. Set the project URL, publishable/anon key, and admin account email in the local `.env` (copy `.env.example`) or in Netlify environment variables as `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_ADMIN_EMAIL`. The URL, anon key and email are client configuration, not passwords; **never** use the service-role key in `.env` or browser code. The password itself is set privately for that Supabase Auth user and is entered only in the star's password prompt, then checked by Supabase Auth over HTTPS; it is not embedded in the app.
4. Install Node.js 20+, run `npm install`, `npm run dev` for local review, and `npm run build`. For Netlify, deploy the project folder from a Git repository or Netlify CLI. The included `netlify.toml` sets the build command (`npm run build`), publish directory (`dist`) and SPA fallback.
5. In Netlify → Site configuration → Environment variables, add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` from Supabase Project Settings → API. Trigger a fresh deploy after setting them. Never expose the Supabase service-role key.
6. Tap the blue star at the bottom and enter the admin password; there is no email field or separate sign-in page. The manager supports artwork uploads from phone file pickers, tags, drafts/publishing, edits, replacement/deletion, tag additions, and artist-profile edits.

## Security notes

- This site **cannot** be safely hosted by Zapia's static page publisher: that service rejects JavaScript and forms and does not provide an app backend, authentication, or persistent database. Deploy this app to an app host and connect Supabase first.
- Never publish the Supabase service-role/secret key or the initial admin password. Admin operations are checked by Postgres RLS against trusted `app_metadata.role=admin`; image bucket remains private. Do not grant public bucket access.
- Changing the signed URL lifespan is in `src/portfolio.tsx` (`3600` seconds). A browser may retain an already obtained image in its in-memory cache until refreshed; no artwork is embedded in public markup.
- The artist can change/reset the Supabase Auth password from the Supabase dashboard or recovery flow; this app never stores the password itself. The blue star is visually discreet, not hidden from source inspection; access control is enforced by Supabase Auth and RLS.
