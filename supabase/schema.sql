-- ---------------------------------------------------------------------------
-- HearTheSound — Supabase şeması
--
-- Kurulum: Supabase projende SQL Editor'ü aç, bu dosyayı olduğu gibi çalıştır.
-- Tek tablo: kullanıcı başına TEK satır ilerleme (JSON blob). RLS ile herkes
-- yalnızca KENDİ satırını okuyup yazabilir.
-- ---------------------------------------------------------------------------

create table if not exists public.progress (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.progress enable row level security;

-- Herkes yalnızca kendi satırını görür/yazar.
create policy "own row select" on public.progress
  for select using (auth.uid() = user_id);

create policy "own row insert" on public.progress
  for insert with check (auth.uid() = user_id);

create policy "own row update" on public.progress
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
