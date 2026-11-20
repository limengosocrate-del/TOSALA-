create table if not exists public.direct_messages (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 body text not null check (char_length(trim(body)) between 1 and 5000),
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index if not exists direct_messages_user_created_idx on public.direct_messages(user_id,created_at asc);
create index if not exists direct_messages_sender_id_idx on public.direct_messages(sender_id);
create index if not exists direct_messages_unread_idx on public.direct_messages(user_id,read_at) where read_at is null;
alter table public.direct_messages enable row level security;
revoke all on public.direct_messages from anon, authenticated;
grant select,insert,delete on public.direct_messages to authenticated;
grant update(read_at) on public.direct_messages to authenticated;
drop policy if exists "direct_messages_read_own_or_admin" on public.direct_messages;
create policy "direct_messages_read_own_or_admin" on public.direct_messages for select to authenticated
using ((select auth.uid())=user_id or (select public.is_admin()));
drop policy if exists "direct_messages_send_own_or_admin" on public.direct_messages;
create policy "direct_messages_send_own_or_admin" on public.direct_messages for insert to authenticated
with check ((select auth.uid())=sender_id and ((select auth.uid())=user_id or (select public.is_admin())));
drop policy if exists "direct_messages_mark_read" on public.direct_messages;
create policy "direct_messages_mark_read" on public.direct_messages for update to authenticated
using ((select auth.uid())=user_id or (select public.is_admin()))
with check ((select auth.uid())=user_id or (select public.is_admin()));
drop policy if exists "direct_messages_delete_admin" on public.direct_messages;
create policy "direct_messages_delete_admin" on public.direct_messages for delete to authenticated
using ((select public.is_admin()));
do $$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime')
 and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='direct_messages') then
  alter publication supabase_realtime add table public.direct_messages;
 end if;
end $$;
