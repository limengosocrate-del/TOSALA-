create table if not exists public.direct_messages (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 body text not null check (char_length(trim(body)) between 1 and 5000),
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index if not exists direct_messages_user_created_idx on public.direct_messages(user_id,created_at asc);
create index if not exists direct_messages_unread_idx on public.direct_messages(user_id,read_at) where read_at is null;
create or replace function public.tosala_is_admin() returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles p where p.user_id=auth.uid() and p.approuve=true and lower(coalesce(p.role,'')) in ('admin','super_admin')); $$;
revoke all on function public.tosala_is_admin() from public;
grant execute on function public.tosala_is_admin() to authenticated;
alter table public.direct_messages enable row level security;
drop policy if exists "direct_messages_read_own_or_admin" on public.direct_messages;
create policy "direct_messages_read_own_or_admin" on public.direct_messages for select to authenticated using(user_id=auth.uid() or public.tosala_is_admin());
drop policy if exists "direct_messages_send_own_or_admin" on public.direct_messages;
create policy "direct_messages_send_own_or_admin" on public.direct_messages for insert to authenticated with check(sender_id=auth.uid() and (user_id=auth.uid() or public.tosala_is_admin()));
drop policy if exists "direct_messages_mark_read" on public.direct_messages;
create policy "direct_messages_mark_read" on public.direct_messages for update to authenticated using(user_id=auth.uid() or public.tosala_is_admin()) with check(user_id=auth.uid() or public.tosala_is_admin());
drop policy if exists "direct_messages_delete_admin" on public.direct_messages;
create policy "direct_messages_delete_admin" on public.direct_messages for delete to authenticated using(public.tosala_is_admin());
revoke update on public.direct_messages from authenticated;
grant select,insert,delete on public.direct_messages to authenticated;
grant update(read_at) on public.direct_messages to authenticated;
