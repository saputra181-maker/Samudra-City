-- SAMUDRA CITY: sistem akun dan direktori penduduk
-- Jalankan sekali di Supabase Dashboard > SQL Editor > New query.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Penduduk Baru',
  username text,
  avatar_emoji text not null default '🧑🏻‍🚀',
  avatar_color text not null default '#10374b',
  avatar_accessory text not null default 'none',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (username is null or username ~ '^[a-z0-9_.-]{3,20}$')
);

alter table public.profiles add column if not exists display_name text not null default 'Penduduk Baru';
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists avatar_emoji text not null default '🧑🏻‍🚀';
alter table public.profiles add column if not exists avatar_color text not null default '#10374b';
alter table public.profiles add column if not exists avatar_accessory text not null default 'none';
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

create unique index if not exists profiles_username_unique_lower
  on public.profiles (lower(username)) where username is not null;

alter table public.profiles enable row level security;

drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Profiles are publicly readable"
  on public.profiles for select using (true);

drop policy if exists "Residents can insert own profile" on public.profiles;
create policy "Residents can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "Residents can update own profile" on public.profiles;
create policy "Residents can update own profile"
  on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create or replace function public.set_profile_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_profile_updated_at();

create or replace function public.handle_new_resident()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, username)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), 'Penduduk Baru'),
    null
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute procedure public.handle_new_resident();

-- Pastikan API Data dapat membaca tabel profiles di schema public.
grant select on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;
