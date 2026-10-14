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

-- ---------------------------------------------------------------------------
-- Huishouden: uitnodigen via een link en elkaars likes zien
-- ---------------------------------------------------------------------------

-- What people in your household may see of you: only your name and likes.
create table if not exists public.shared_profile (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  name       text not null default '',
  liked      jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.household_invites (
  code         text primary key,
  inviter      uuid not null references auth.users (id) on delete cascade,
  inviter_name text not null default '',
  email        text,
  accepted_by  uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  accepted_at  timestamptz
);

create table if not exists public.household_links (
  a          uuid not null references auth.users (id) on delete cascade,
  b          uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (a, b),
  check (a < b)
);

alter table public.shared_profile    enable row level security;
alter table public.household_invites enable row level security;
alter table public.household_links   enable row level security;

drop policy if exists "profiel lezen" on public.shared_profile;
create policy "profiel lezen" on public.shared_profile for select to authenticated using (
  user_id = (select auth.uid())
  or exists (select 1 from public.household_links l
             where (l.a = (select auth.uid()) and l.b = shared_profile.user_id)
                or (l.b = (select auth.uid()) and l.a = shared_profile.user_id))
);
drop policy if exists "profiel toevoegen" on public.shared_profile;
create policy "profiel toevoegen" on public.shared_profile for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "profiel wijzigen" on public.shared_profile;
create policy "profiel wijzigen" on public.shared_profile for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "eigen uitnodigingen lezen" on public.household_invites;
create policy "eigen uitnodigingen lezen" on public.household_invites for select to authenticated using (inviter = (select auth.uid()));
drop policy if exists "uitnodiging maken" on public.household_invites;
create policy "uitnodiging maken" on public.household_invites for insert to authenticated with check (inviter = (select auth.uid()));
drop policy if exists "uitnodiging intrekken" on public.household_invites;
create policy "uitnodiging intrekken" on public.household_invites for delete to authenticated using (inviter = (select auth.uid()));

drop policy if exists "eigen koppelingen lezen" on public.household_links;
create policy "eigen koppelingen lezen" on public.household_links for select to authenticated using (a = (select auth.uid()) or b = (select auth.uid()));
drop policy if exists "koppeling verbreken" on public.household_links;
create policy "koppeling verbreken" on public.household_links for delete to authenticated using (a = (select auth.uid()) or b = (select auth.uid()));

-- Who invited me? (also before logging in, so the welcome screen can say it)
create or replace function public.get_invite(p_code text)
returns table (inviter_name text, email text)
language sql security definer set search_path = '' stable
as $$
  select i.inviter_name, i.email from public.household_invites i
  where i.code = p_code and i.accepted_by is null;
$$;

-- Open invites sent to my e-mail address
create or replace function public.my_invites()
returns table (code text, inviter_name text, email text)
language sql security definer set search_path = '' stable
as $$
  select i.code, i.inviter_name, i.email from public.household_invites i
  where i.accepted_by is null
    and lower(i.email) = lower(auth.jwt() ->> 'email')
    and i.inviter <> auth.uid()
    and not exists (select 1 from public.household_links l
                    where l.a = least(i.inviter, auth.uid()) and l.b = greatest(i.inviter, auth.uid()));
$$;

create or replace function public.accept_invite(p_code text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare inv public.household_invites;
begin
  if auth.uid() is null then raise exception 'Log eerst in.'; end if;
  select * into inv from public.household_invites where code = p_code for update;
  if not found or inv.accepted_by is not null then raise exception 'Deze uitnodiging is niet meer geldig. Vraag om een nieuwe link.'; end if;
  if inv.inviter = auth.uid() then raise exception 'Dit is je eigen uitnodiging. Stuur de link naar iemand anders.'; end if;
  insert into public.household_links (a, b) values (least(inv.inviter, auth.uid()), greatest(inv.inviter, auth.uid()))
    on conflict do nothing;
  update public.household_invites set accepted_by = auth.uid(), accepted_at = now() where code = p_code;
end;
$$;

create or replace function public.decline_invite(p_code text)
returns void
language sql security definer set search_path = ''
as $$
  delete from public.household_invites
  where code = p_code and accepted_by is null and lower(email) = lower(auth.jwt() ->> 'email');
$$;

revoke all on function public.get_invite(text) from public;
revoke all on function public.my_invites() from public, anon;
revoke all on function public.accept_invite(text) from public, anon;
revoke all on function public.decline_invite(text) from public, anon;
grant execute on function public.get_invite(text) to anon, authenticated;
grant execute on function public.my_invites() to authenticated;
grant execute on function public.accept_invite(text) to authenticated;
grant execute on function public.decline_invite(text) to authenticated;
