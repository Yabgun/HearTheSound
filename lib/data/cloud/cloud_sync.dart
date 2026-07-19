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

  /// E-postaya 6 haneli giriş kodu gönderir (hesap yoksa oluşturur).
  Future<void> sendOtp(String email) =>
      _client.auth.signInWithOtp(email: email);

  /// Gönderilen kodu doğrular; başarılıysa oturum açılır.
  Future<void> verifyOtp({required String email, required String code}) =>
      _client.auth.verifyOTP(type: OtpType.email, email: email, token: code);

  Future<void> signOut() => _client.auth.signOut();

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

      final merged = mergeProgress(localProgress, remoteProgress);
      await local.save(merged);
      await _upsert(merged);
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
