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

-- Data API (PostgREST) tablo ayrıcalıkları — AÇIKÇA verilir ki projede
-- "Automatically expose new tables" KAPALI olsa da uygulama çalışsın.
-- Not: bu yalnızca "tabloya dokunabilme" iznidir; HANGİ satırı görebileceğine
-- yukarıdaki RLS politikaları karar verir. anon'a bilerek hiçbir yetki verilmez
-- (ilerleme yalnızca giriş yapmış kullanıcınındır). DELETE de verilmez —
-- silme yalnızca delete_account() RPC'si / auth.users cascade ile olur.
grant select, insert, update on public.progress to authenticated;

-- ---------------------------------------------------------------------------
-- HESAP SİLME (Play Store "veri silme" zorunluluğu)
--
-- İstemci, authenticated olarak delete_account() RPC'sini çağırır. SECURITY
-- DEFINER sayesinde fonksiyon SAHİBİNİN (yükseltilmiş) yetkisiyle çalışır:
-- çağıranın progress satırını ve auth.users kaydını siler. (auth.users silinince
-- progress zaten "on delete cascade" ile gider; net olsun diye açıkça da sileriz.)
-- auth.uid() JWT'den çağıranın kimliğini verir → yalnızca KENDİ hesabını siler.
-- ---------------------------------------------------------------------------
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.progress where user_id = auth.uid();
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
