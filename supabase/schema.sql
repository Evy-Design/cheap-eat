-- Cheap-eat: run this once in Supabase → SQL Editor.
-- One row per user with all app data (recipes, likes, notes, week plan, settings).

create table if not exists public.user_data (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_data enable row level security;

-- Everyone can only see and change their own row.
drop policy if exists "eigen gegevens lezen" on public.user_data;
create policy "eigen gegevens lezen" on public.user_data
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "eigen gegevens toevoegen" on public.user_data;
create policy "eigen gegevens toevoegen" on public.user_data
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "eigen gegevens wijzigen" on public.user_data;
create policy "eigen gegevens wijzigen" on public.user_data
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "eigen gegevens verwijderen" on public.user_data;
create policy "eigen gegevens verwijderen" on public.user_data
  for delete to authenticated using ((select auth.uid()) = user_id);

-- "Account verwijderen" in the app: deletes the logged-in user (and, via cascade, their data).
create or replace function public.delete_my_account()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
