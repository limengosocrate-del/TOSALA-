-- Notifications persistantes en temps réel pour les comptes TOSALA.
create table if not exists public.user_notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (char_length(trim(title)) between 1 and 120),
 body text not null check (char_length(trim(body)) between 1 and 2000),
 type text not null default 'announcement' check (type in ('announcement','publication','direct_message','system')),
 link text,
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index if not exists user_notifications_user_created_idx on public.user_notifications(user_id,created_at desc);
create index if not exists user_notifications_unread_idx on public.user_notifications(user_id,created_at desc) where read_at is null;
alter table public.user_notifications enable row level security;
revoke all on public.user_notifications from anon,authenticated;
grant select,insert on public.user_notifications to authenticated;
grant update(read_at) on public.user_notifications to authenticated;
drop policy if exists "user_notifications_read_own" on public.user_notifications;
create policy "user_notifications_read_own" on public.user_notifications for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists "user_notifications_update_own" on public.user_notifications;
create policy "user_notifications_update_own" on public.user_notifications for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
drop policy if exists "user_notifications_admin_insert" on public.user_notifications;
create policy "user_notifications_admin_insert" on public.user_notifications for insert to authenticated with check ((select public.is_admin()));
create or replace function public.tosala_notify_direct_message()
returns trigger language plpgsql security definer set search_path=public,pg_temp
as $$
begin
 if auth.uid() is not null and auth.uid() <> new.sender_id then return new; end if;
 if public.is_admin() then
   insert into public.user_notifications(user_id,title,body,type,link)
   values(new.user_id,'Nouveau message de l’administration',left(new.body,2000),'direct_message','./?open=messages');
 else
   insert into public.user_notifications(user_id,title,body,type,link)
   select p.user_id,'Nouveau message citoyen','Un membre a envoyé un message privé à l’administration.','direct_message','./?open=direct-messages'
   from public.profiles p
   where p.approuve=true and p.role in ('admin','super_admin');
 end if;
 return new;
end;
$$;
revoke all on function public.tosala_notify_direct_message() from public,anon,authenticated;
drop trigger if exists tosala_direct_message_notification on public.direct_messages;
create trigger tosala_direct_message_notification after insert on public.direct_messages
for each row execute function public.tosala_notify_direct_message();
create or replace function public.tosala_notify_published_planning()
returns trigger language plpgsql security definer set search_path=public,pg_temp
as $$
begin
 if new.statut <> 'published' then return new; end if;
 if tg_op='UPDATE' and old.statut='published' then return new; end if;
 if not public.is_admin() then return new; end if;
 insert into public.user_notifications(user_id,title,body,type,link)
 select p.user_id,'Nouveau programme de Salongo',left(new.titre||' · '||coalesce(new.lieu,'')||' · '||to_char(new.date_salongo,'DD/MM/YYYY'),2000),'publication','./?open=planning'
 from public.profiles p
 where p.approuve=true and p.role in ('ambassador','volunteer') and p.commune_id=new.commune_id;
 return new;
end;
$$;
revoke all on function public.tosala_notify_published_planning() from public,anon,authenticated;
drop trigger if exists tosala_planning_notification on public.salongo_plannings;
create trigger tosala_planning_notification after insert or update of statut on public.salongo_plannings
for each row execute function public.tosala_notify_published_planning();
do $$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime')
 and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='user_notifications') then
  alter publication supabase_realtime add table public.user_notifications;
 end if;
end $$;