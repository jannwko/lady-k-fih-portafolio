-- Lady K ★ Fih portfolio — run in Supabase SQL Editor as project owner.
create extension if not exists pgcrypto;
create table if not exists public.artwork (
 id uuid primary key default gen_random_uuid(),
 title text not null check (char_length(title) between 1 and 120),
 description text check (description is null or char_length(description)<=1000),
 tags text[] not null default '{}',
 storage_path text not null unique,
 published boolean not null default false,
 nsfw boolean not null default false,
 created_at timestamptz not null default now()
);
alter table public.artwork drop constraint if exists artwork_nsfw_tag_consistent;
alter table public.artwork add constraint artwork_nsfw_tag_consistent check (nsfw = ('NSFW'=any(tags)));
create table if not exists public.tags (name text primary key check (char_length(name) between 1 and 40));
create table if not exists public.artist_profile (
 id integer primary key check (id=1),
 name text not null default 'Lady K ★ Fih',
 bio text not null default '',
 specialties text[] not null default '{}',
 commission_url text not null default 'https://ponkstarfihcomms.carrd.co/',
 contact text not null default '',
 socials jsonb not null default '[]'::jsonb
);
insert into public.tags(name) values
('SFW'),('NSFW'),('Normal Art'),('Furry'),('Adopts'),('Background'),('Character'),('Fullbody'),('Halfbody'),('Bust'),('Chibi'),('Reference Sheet'),('Sketch'),('Illustration'),('Digital Painting'),('Character Design'),('Adoptable'),('Commission'),('Personal Artwork') on conflict do nothing;
insert into public.artist_profile(id,name,bio,specialties,commission_url,socials) values
(1,'Lady K ★ Fih','¡Hola! Soy una artista digital independiente. Aquí comparto mis ilustraciones, personajes y diseños.',array['Ilustración digital','Diseño de personajes','Furry','Adopts'],'https://ponkstarfihcomms.carrd.co/','[{"label":"X / Twitter","url":"https://x.com/LadyK_fih"}]'::jsonb) on conflict(id) do nothing;
create or replace function public.is_portfolio_admin() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce((auth.jwt()->'app_metadata'->>'role')='admin',false)
$$;
alter table public.artwork enable row level security;
alter table public.tags enable row level security;
alter table public.artist_profile enable row level security;
grant select on public.artwork,public.tags,public.artist_profile to anon,authenticated;
grant insert,update,delete on public.artwork,public.tags,public.artist_profile to authenticated;
drop policy if exists "Published artwork is readable" on public.artwork;
create policy "Published SFW artwork is readable" on public.artwork for select to anon,authenticated using ((published and not nsfw) or public.is_portfolio_admin());
-- Public gallery endpoint returns SFW by default. NSFW records are only included after the visitor explicitly opts in in the UI.
create or replace function public.get_gallery_artwork(show_nsfw boolean default false)
returns setof public.artwork language sql stable security definer set search_path=public as $$
 select * from public.artwork where published and (show_nsfw or not nsfw) order by created_at desc
$$;
grant execute on function public.get_gallery_artwork(boolean) to anon,authenticated;
drop policy if exists "Only admins manage artwork" on public.artwork;
create policy "Only admins manage artwork" on public.artwork for all to authenticated using (public.is_portfolio_admin()) with check (public.is_portfolio_admin());
drop policy if exists "Tags are public" on public.tags;
create policy "Tags are public" on public.tags for select to anon,authenticated using (true);
drop policy if exists "Only admins manage tags" on public.tags;
create policy "Only admins manage tags" on public.tags for all to authenticated using (public.is_portfolio_admin()) with check (public.is_portfolio_admin());
drop policy if exists "Artist profile is public" on public.artist_profile;
create policy "Artist profile is public" on public.artist_profile for select to anon,authenticated using (true);
drop policy if exists "Only admins manage artist profile" on public.artist_profile;
create policy "Only admins manage artist profile" on public.artist_profile for all to authenticated using (public.is_portfolio_admin()) with check (public.is_portfolio_admin());
-- Private artwork bucket; file size cap 20MB and MIME allowlist. Signed URLs only.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('artwork','artwork',false,20971520,array['image/png','image/jpeg','image/webp']) on conflict(id) do update set public=false,file_size_limit=20971520,allowed_mime_types=array['image/png','image/jpeg','image/webp'];
drop policy if exists "Admin uploads artwork" on storage.objects;
create policy "Admin uploads artwork" on storage.objects for insert to authenticated with check (bucket_id='artwork' and public.is_portfolio_admin());
drop policy if exists "Admins update artwork files" on storage.objects;
create policy "Admins update artwork files" on storage.objects for update to authenticated using(bucket_id='artwork' and public.is_portfolio_admin()) with check(bucket_id='artwork' and public.is_portfolio_admin());
drop policy if exists "Admins delete artwork files" on storage.objects;
create policy "Admins delete artwork files" on storage.objects for delete to authenticated using(bucket_id='artwork' and public.is_portfolio_admin());
-- A signed URL can be minted for a published art object (or any object by the admin).
drop policy if exists "Published artwork signed read" on storage.objects;
create policy "Published artwork signed read" on storage.objects for select to anon,authenticated using(bucket_id='artwork' and (public.is_portfolio_admin() or exists(select 1 from public.artwork a where a.storage_path=name and a.published=true)));
