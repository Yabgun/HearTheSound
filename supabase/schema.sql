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
-- Edge Function (streak-reminder, §21) service_role ile TÜM kullanıcıları tarar;
-- yalnızca OKUR → minimal SELECT yetkisi. (Bu projede grant'ler açıkça verilir,
-- service_role otomatik geniş yetki almaz.)
grant select on public.progress to service_role;

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

-- ---------------------------------------------------------------------------
-- ZORUNLU GÜNCELLEME KAPISI (uygulama §20)
--
-- Tek satırlık, HERKESE-AÇIK OKUNUR yayın yapılandırması. Kişisel veri yok;
-- yalnızca sürüm eşikleri + isteğe bağlı duyuru mesajı. anon SELECT bilerek
-- açık: misafir kullanıcı da güncelleme kapısından geçmeli.
--
-- Kullanım (yayın panelinden, kod değişikliği YOK):
--   min_supported_build'i büyüt -> altındaki sürümler Play Store'a zorlanır
--   latest_build'i büyüt        -> altındakilere kapatılabilir öneri görünür
-- Karşılaştırma pubspec `+N` build numarasıyladır (monotonik tamsayı).
--
-- Yazma yolu YOK (insert/update grant edilmez): değerler yalnızca Supabase
-- panelinden (service role) değiştirilir.
-- ---------------------------------------------------------------------------
create table if not exists public.app_config (
  id int primary key check (id = 1), -- tek satır garantisi
  min_supported_build int not null default 1,
  latest_build int not null default 1,
  message_en text,
  message_tr text,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

drop policy if exists "config is public read" on public.app_config;
create policy "config is public read" on public.app_config
  for select using (true);

grant select on public.app_config to anon, authenticated;

-- Başlangıç satırı (varsa dokunma) — mevcut tek yayın build'i 1.
insert into public.app_config (id, min_supported_build, latest_build)
values (1, 1, 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- SUNUCU PUSH (⑥ / FCM) — cihaz token kayıtları
--
-- Her giriş yapmış kullanıcı, bildirim alacak cihazlarının FCM token'larını
-- buraya yazar (istemci: uygulama açılışı + token yenilenmesi). Edge Function
-- (cron) bu tabloyu okuyup seri-tehlike/geri-kazanım bildirimlerini gönderir.
--
-- RLS: herkes YALNIZCA kendi satırlarını görür/yönetir. anon'a hiçbir yetki
-- yok — misafirin hesabı olmadığından sunucu push'u da olamaz (yerel bildirim
-- zaten var). DELETE bilerek verildi: çıkış yapınca cihaz token'ı silinmeli
-- (yoksa eski cihaza yabancı hesabın bildirimi gider).
-- ---------------------------------------------------------------------------
create table if not exists public.device_tokens (
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  -- Bu CİHAZIN dil tercihi ('en'|'tr'). Push metni sunucuda buna göre seçilir
  -- (çok dilli uygulama → kullanıcı hangi dildeyse o dilde bildirim alır).
  -- Cihaz başına: aynı hesabın farklı cihazları farklı dilde olabilir.
  locale text not null default 'en',
  updated_at timestamptz not null default now(),
  primary key (user_id, token) -- aynı cihaz iki kez kaydolmaz; çok cihaz serbest
);

-- Mevcut tabloya (bu blok tekrar çalıştırılırsa) locale sütununu ekle.
alter table public.device_tokens
  add column if not exists locale text not null default 'en';

alter table public.device_tokens enable row level security;

drop policy if exists "own tokens select" on public.device_tokens;
create policy "own tokens select" on public.device_tokens
  for select using (auth.uid() = user_id);

drop policy if exists "own tokens insert" on public.device_tokens;
create policy "own tokens insert" on public.device_tokens
  for insert with check (auth.uid() = user_id);

drop policy if exists "own tokens update" on public.device_tokens;
create policy "own tokens update" on public.device_tokens
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own tokens delete" on public.device_tokens;
create policy "own tokens delete" on public.device_tokens
  for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.device_tokens to authenticated;
-- Edge Function push token'larını okur (yalnızca SELECT).
grant select on public.device_tokens to service_role;
