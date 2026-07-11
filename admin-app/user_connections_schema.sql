-- Follow/Connections social graph for the Community page.
--
-- There is no per-post author `user_id` anywhere in `posts` (every device's
-- own posts are inserted with a hardcoded display name, e.g. "Sakthi (You)"
-- — see main.dart's composer submit logic) and no real auth/user-accounts
-- system in this app (see CLAUDE.md: "No authentication system"). So the
-- only stable-ish identifier available for "who is being followed" is the
-- author's display name, which is also what the Community feed's existing
-- Follow button already keys off of (post['name']). follower_id is the
-- current device's anonymous id (shared with Podcast/E-book/TBT Points via
-- PodcastService.getOrCreateAnonymousUserId()).
create table if not exists user_connections (
  id uuid primary key default gen_random_uuid(),
  follower_id text not null,
  followed_name text not null,
  created_at timestamptz not null default now(),
  unique (follower_id, followed_name)
);

create index if not exists user_connections_follower_id_idx
  on user_connections (follower_id);

alter table user_connections enable row level security;

-- No real auth system in this app (anon key only) — same open-RLS pattern
-- already used by every other user-facing table (posts, podcast progress,
-- ebook bookmarks, tbt_activity_log, mobile_notifications).
drop policy if exists "Allow anon read" on user_connections;
create policy "Allow anon read" on user_connections
  for select using (true);

drop policy if exists "Allow anon insert" on user_connections;
create policy "Allow anon insert" on user_connections
  for insert with check (true);

drop policy if exists "Allow anon delete" on user_connections;
create policy "Allow anon delete" on user_connections
  for delete using (true);
