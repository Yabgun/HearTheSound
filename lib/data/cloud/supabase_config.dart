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

const String kSupabaseUrl = 'https://sjrfnrczypwuquvzycid.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6In'
    'NqcmZucmN6eXB3dXF1dnp5Y2lkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ1NzQ1MzIsIm'
    'V4cCI6MjEwMDE1MDUzMn0.AQ_VY4glslYQkmQW5MpvzVx3Q8gaZ2DnrWE1bVZeICs';

/// Bulut senkron açık mı? (İki değer de girilmişse)
bool get isCloudConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
