// -----------------------------------------------------------------------------
// STREAK REMINDER — seri-tehlikedeki kullanıcılara geri-kazanım bildirimi
//
// Supabase Edge Function (Deno). Cron ile GÜNDE BİR tetiklenir (bkz.
// supabase/functions/README.md). "Dün oynadı ama bugün henüz oynamadı"
// kullanıcılarını bulur ve kayıtlı cihazlarına FCM push gönderir → seri kopmadan
// hatırlatma. Kişisel veriyi DIŞARI çıkarmaz; yalnızca kullanıcının kendi
// cihazına bildirim iter.
//
// GÜVENLİK: service_role anahtarıyla çalışır (RLS'i aşar — tüm kullanıcıları
// tarar) ama bu anahtar YALNIZCA sunucuda (Edge secret) yaşar, istemciye asla
// gitmez. FCM v1 için Firebase service account gerekir (aşağıdaki secret'lar).
//
// Gerekli Edge secret'ları (Supabase → Edge Functions → Manage secrets):
//   FCM_PROJECT_ID          → 'hearthesound'
//   FCM_CLIENT_EMAIL        → service account e-postası
//   FCM_PRIVATE_KEY         → service account özel anahtarı (PEM)
// (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY otomatik enjekte edilir.)
// -----------------------------------------------------------------------------

import { createClient } from "jsr:@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

// --- Zaman yardımcıları (UTC gün anahtarı — istemciyle aynı 'yyyy-mm-dd') ------
function dayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

// --- FCM v1 için OAuth2 erişim token'ı (service account JWT akışı) -------------
async function getFcmAccessToken(
  clientEmail: string,
  privateKeyPem: string,
): Promise<string> {
  // PEM -> CryptoKey (RS256 imzalama için).
  const pem = privateKeyPem.replace(/\\n/g, "\n");
  const der = pemToArrayBuffer(pem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const now = Math.floor(Date.now() / 1000);
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    },
    key,
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await res.json();
  if (!json.access_token) {
    throw new Error(`FCM token alınamadı: ${JSON.stringify(json)}`);
  }
  return json.access_token;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

// --- Bildirim metni, CİHAZIN diline göre (çok dilli uygulama) ------------------
// device_tokens.locale ile eşleşir; bilinmeyen dil İngilizce'ye düşer.
const MESSAGES: Record<string, { title: string; body: string }> = {
  en: {
    title: "Keep your streak! 🔥",
    body: "Do today's lesson and sharpen your ear.",
  },
  tr: {
    title: "Serini koru! 🔥",
    body: "Bugünkü dersini yap, kulağını geliştir.",
  },
};

function messageFor(locale: string): { title: string; body: string } {
  return MESSAGES[locale] ?? MESSAGES.en;
}

// --- Tek bir cihaza FCM v1 bildirimi gönder -----------------------------------
async function sendPush(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
        },
      }),
    },
  );
  return res.ok;
}

// --- Ana akış -----------------------------------------------------------------
Deno.serve(async () => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const now = new Date();
    const today = dayKey(now);
    const yesterday = dayKey(new Date(now.getTime() - 86_400_000));

    // "Dün oynadı, bugün henüz oynamadı" = seri tehlikede.
    // Satırları çekip lastActiveDay'i JS'te süzüyoruz (PostgREST jsonb filtre
    // sözdizimine bağımlı kalmadan — kullanıcı sayısı v1'de küçük). Ölçeklenince
    // sunucu-tarafı filtreye (ör. üretilmiş sütun + index) geçilir.
    const { data: rows, error } = await supabase
      .from("progress")
      .select("user_id, data");
    if (error) throw error;

    const atRisk = (rows ?? []).filter((r) => {
      const lad = r.data?.lastActiveDay ?? "";
      return lad === yesterday && lad !== today;
    });
    if (atRisk.length === 0) {
      return Response.json({ ok: true, sent: 0, reason: "no at-risk users" });
    }

    // FCM erişim token'ı (tek sefer — tüm gönderimlerde paylaşılır).
    const accessToken = await getFcmAccessToken(
      Deno.env.get("FCM_CLIENT_EMAIL")!,
      Deno.env.get("FCM_PRIVATE_KEY")!,
    );
    const projectId = Deno.env.get("FCM_PROJECT_ID")!;

    // Bu kullanıcıların cihaz token'larını (ve her cihazın dilini) topla.
    const userIds = atRisk.map((r) => r.user_id);
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token, locale")
      .in("user_id", userIds);

    let sent = 0;
    for (const t of tokens ?? []) {
      // Her CİHAZ kendi diline göre bildirim alır (çok dilli).
      const msg = messageFor(t.locale ?? "en");
      const ok = await sendPush(
        projectId,
        accessToken,
        t.token,
        msg.title,
        msg.body,
      );
      if (ok) sent++;
    }

    return Response.json({ ok: true, atRisk: atRisk.length, sent });
  } catch (e) {
    // Hata düz metne çevrilir (Supabase hata NESNESİ `[object Object]` verirdi).
    const detail = e instanceof Error
      ? e.message
      : (typeof e === "object" ? JSON.stringify(e) : String(e));
    return Response.json({ ok: false, error: detail }, { status: 500 });
  }
});
