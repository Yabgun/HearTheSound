import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/merge_progress.dart';
import '../../core/player_progress.dart';
import '../progress_repository.dart';
import 'supabase_config.dart';

// -----------------------------------------------------------------------------
// CLOUD SYNC — Supabase üstünde hesap + ilerleme eşitleme
//
// Tasarım ilkeleri:
// - YEREL-ÖNCELİK: uygulama her zaman yerel prefs'ten çalışır; bulut sadece
//   arka planda eşitlenir. İnternet yoksa hiçbir şey aksamaz.
// - KAYIPSIZ birleştirme: indirilen veri yerel ile mergeProgress ile birleşir
//   (bkz. core/merge_progress.dart) — hiçbir cihazın emeği silinmez.
// - SESSİZ hata: ağ/RLS hataları kullanıcı akışını asla bozmaz; bir sonraki
//   kayıtta yeniden denenir.
//
// Kimlik: e-posta + 6 haneli tek kullanımlık kod (OTP). Şifre yok, deep-link
// gerektirmez — Ayarlar'daki Hesap bölümü yönetir.
// -----------------------------------------------------------------------------

class CloudSync {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  static const String _table = 'progress';

  /// Bulut yapılandırılmış mı? (supabase_config doluysa)
  bool get isConfigured => isCloudConfigured;

  SupabaseClient get _client => Supabase.instance.client;

  /// Oturumdaki kullanıcı (yoksa null).
  User? get user => isConfigured ? _client.auth.currentUser : null;
  bool get isSignedIn => user != null;

  Timer? _pushDebounce;
  PlayerProgress? _pendingPush;

  /// Buluttaki veri bu uygulamanın anladığından YENİ bir şemadan geldiğinde
  /// true olur (kullanıcının başka bir cihazı güncel, bu cihaz değil).
  ///
  /// Bu durumda buluta **yazmayı tamamen durdururuz**: eski sürüm yeni alanları
  /// okurken düşürdüğü için geri yazmak, güncel cihazın ilerlemesini sessizce
  /// budardı. Yerel kullanım aksamaz; kullanıcı uygulamayı güncelleyince
  /// kendiliğinden düzelir.
  bool _blockedByNewerSchema = false;

  /// Arayüz "uygulamayı güncelle" uyarısı gösterebilsin diye açık (ileride
  /// kullanılacak — şu an senkron sessizce durur).
  bool get isBlockedByNewerSchema => _blockedByNewerSchema;

  /// E-postaya 6 haneli giriş kodu gönderir (hesap yoksa oluşturur).
  Future<void> sendOtp(String email) =>
      _client.auth.signInWithOtp(email: email);

  /// Gönderilen kodu doğrular; başarılıysa oturum açılır.
  Future<void> verifyOtp({required String email, required String code}) =>
      _client.auth.verifyOTP(type: OtpType.email, email: email, token: code);

  Future<void> signOut() async {
    // Sonraki hesap için temiz sayfa: kilit o hesabın verisine göre yeniden kurulur.
    _blockedByNewerSchema = false;
    await _client.auth.signOut();
  }

  /// Hesabı ve TÜM sunucu verisini kalıcı olarak siler (Play Store "veri silme"
  /// zorunluluğu). Sunucuda `delete_account` RPC'si (SECURITY DEFINER) progress
  /// satırını ve auth.users kaydını siler; ardından oturum kapatılır ve YEREL
  /// ilerleme sıfırlanır. Bekleyen buluta-itme iptal edilir (silinmiş hesaba
  /// yazma denemesi olmasın).
  Future<void> deleteAccount(ProgressRepository local) async {
    _pushDebounce?.cancel();
    _pendingPush = null;
    if (!isConfigured) return;
    try {
      await _client.rpc('delete_account');
    } finally {
      // Hesap sunucuda gitti; yerel oturumu ve ilerlemeyi de temizle.
      _blockedByNewerSchema = false;
      await _client.auth.signOut();
      await local.save(PlayerProgress.empty);
    }
  }

  /// Buluttaki ilerlemeyi indirir, yerelle KAYIPSIZ birleştirir, iki tarafı da
  /// günceller. Birleşik ilerlemeyi döndürür (hata/kapalıysa null).
  Future<PlayerProgress?> pullAndMerge(ProgressRepository local) async {
    final uid = user?.id;
    if (uid == null) return null;
    try {
      final row = await _client
          .from(_table)
          .select('data')
          .eq('user_id', uid)
          .maybeSingle();

      final localProgress = local.load();
      final remoteProgress = row == null
          ? PlayerProgress.empty
          : PlayerProgress.fromMap(
              (row['data'] as Map).cast<String, dynamic>(),
            );

      // Buluttaki veri bizden yeniyse yazma yolunu kapat (bkz. alan yorumu).
      // Yerel birleştirme yine de yapılır: anladığımız alanlarla çalışırız.
      _blockedByNewerSchema = remoteProgress.isFromFutureSchema;

      final merged = mergeProgress(localProgress, remoteProgress);
      await local.save(merged);
      await _upsert(merged); // kilitliyse sessizce atlanır
      return merged;
    } catch (_) {
      return null; // sessiz: yerel akış bozulmaz
    }
  }

  /// Kaydetme sonrası buluta itme — art arda kayıtları tek isteğe indirger
  /// (2 sn debounce). Oturum yoksa sessizce atlanır.
  void schedulePush(PlayerProgress progress) {
    if (!isConfigured || !isSignedIn) return;
    _pendingPush = progress;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(seconds: 2), () {
      final p = _pendingPush;
      _pendingPush = null;
      if (p != null) unawaited(_upsert(p).catchError((_) {}));
    });
  }

  Future<void> _upsert(PlayerProgress progress) async {
    final uid = user?.id;
    if (uid == null) return;
    // İLERİ-SÜRÜM KORUMASI — buluta giden TEK kapı burası, kilit de burada.
    // (İki koşul ayrı ayrı gerekli: biri buluttan öğrenilen durum, diğeri
    // yazılacak verinin kendi damgası — ör. yerelde duran yabancı kayıt.)
    if (_blockedByNewerSchema || progress.isFromFutureSchema) return;
    await _client.from(_table).upsert({
      'user_id': uid,
      'data': progress.toMap(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

/// Yerel repo'yu saran dekoratör: her kayıt önce YEREL yazılır (kaynak gerçek),
/// sonra bulut kuyruğuna eklenir. Okuma her zaman yereldendir.
class SyncedProgressRepository implements ProgressRepository {
  SyncedProgressRepository(this._inner);

  final ProgressRepository _inner;

  @override
  PlayerProgress load() => _inner.load();

  @override
  Future<void> save(PlayerProgress progress) async {
    await _inner.save(progress);
    CloudSync.instance.schedulePush(progress);
  }
}
