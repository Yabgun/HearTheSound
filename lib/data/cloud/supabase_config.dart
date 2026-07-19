// -----------------------------------------------------------------------------
// SUPABASE YAPILANDIRMASI
//
// Bulut senkronunu açmak için kendi Supabase projenin değerlerini gir:
//   1) https://supabase.com → ücretsiz proje oluştur
//   2) Project Settings → API: "Project URL" ve "anon public" anahtarını kopyala
//   3) Aşağıdaki iki sabite yapıştır
//   4) supabase/schema.sql dosyasını SQL Editor'de çalıştır (tablo + RLS)
//
// İki değer de boşken uygulama TAMAMEN YEREL çalışır (bulut kodu hiç devreye
// girmez) — bugünkü davranış birebir korunur.
//
// Not: "anon" anahtarı istemciye gömülmek İÇİN tasarlanmıştır (gizli değildir);
// veri güvenliğini RLS (satır seviyesi güvenlik) kuralları sağlar.
// -----------------------------------------------------------------------------

const String kSupabaseUrl = '';
const String kSupabaseAnonKey = '';

/// Bulut senkron açık mı? (İki değer de girilmişse)
bool get isCloudConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
