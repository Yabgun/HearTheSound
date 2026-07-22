import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/version_gate.dart';
import '../data/cloud/app_config_remote.dart';
import 'settings_controller.dart';

// -----------------------------------------------------------------------------
// GÜNCELLEME KAPISI DENETLEYİCİSİ — §20
//
// Açılışta iki aşamalı çalışır:
//   1) SENKRON: önbellekteki son bilinen config ile karar ver → zorlanmış bir
//      sürüm, uçak modunda yeniden açılsa bile KİLİTLİ kalır.
//   2) ASENKRON: sunucudan tazesini çek → önbelleğe yaz → kararı güncelle.
//      Oturum ORTASINDA force gelirse ekran anında kapıya döner (kill-switch).
//
// Fail-open: taze config alınamazsa (çevrimdışı/sunucu kapalı) mevcut karar
// korunur; hiç önbellek yoksa karar "none"dur — kapı kendi hatası yüzünden
// kimseyi kilitlemez.
// -----------------------------------------------------------------------------

/// Çalışan uygulamanın build numarası (pubspec `+N`). main() gerçek değeri
/// `PackageInfo`'dan okuyup override eder. Varsayılan 0 = "bilinmiyor" →
/// evaluateUpdateVerdict fail-open gereği kapıyı hiç açmaz (testler güvende).
final currentBuildProvider = Provider<int>((_) => 0);

/// Sunucudan config çeken işlev — testlerde sahteyle değiştirilebilsin diye
/// provider'da. Gerçek uygulama `fetchAppConfig`'i kullanır (her hatada null).
final appConfigFetcherProvider = Provider<Future<AppConfig?> Function()>(
  (_) => fetchAppConfig,
);

/// Kapının anlık durumu.
class UpdateGateState {
  final UpdateVerdict verdict;
  final AppConfig config;

  /// Kullanıcı bu `latest_build` önerisini kapattı mı? (Zorunluda anlamsız —
  /// zorunlu kapatılamaz.)
  final bool suggestionDismissed;

  const UpdateGateState({
    this.verdict = UpdateVerdict.none,
    this.config = AppConfig.empty,
    this.suggestionDismissed = false,
  });

  /// Bugün ekranındaki öneri kartı görünmeli mi?
  bool get showSuggestion =>
      verdict == UpdateVerdict.suggest && !suggestionDismissed;

  /// Uygulama tamamen engellenmeli mi?
  bool get blocked => verdict == UpdateVerdict.force;
}

class UpdateGateController extends Notifier<UpdateGateState> {
  static const String _cacheKey = 'app_config_cache_v1';
  static const String _dismissedKey = 'update_suggest_dismissed_build';

  @override
  UpdateGateState build() {
    // 1) Senkron başlangıç: önbellekteki son bilinen config.
    // prefs main'de override edilir; edilmemişse (izole testler) önbelleksiz
    // başlarız — kapı kapalı kalır (fail-open ruhu testlerde de geçerli).
    AppConfig cached = AppConfig.empty;
    int dismissed = -1;
    try {
      final prefs = ref.read(prefsProvider);
      cached = AppConfig.tryParse(prefs.getString(_cacheKey)) ?? AppConfig.empty;
      dismissed = prefs.getInt(_dismissedKey) ?? -1;
    } catch (_) {
      // prefsProvider override edilmemiş — önbelleksiz devam.
    }

    // 2) Asenkron tazeleme (açılışı BEKLETMEZ).
    unawaited(Future.microtask(refresh));

    return _stateFor(cached, dismissedBuild: dismissed);
  }

  UpdateGateState _stateFor(AppConfig config, {required int dismissedBuild}) {
    final verdict = evaluateUpdateVerdict(
      currentBuild: ref.read(currentBuildProvider),
      config: config,
    );
    return UpdateGateState(
      verdict: verdict,
      config: config,
      suggestionDismissed:
          config.latestBuild != null && config.latestBuild == dismissedBuild,
    );
  }

  /// Sunucudan taze config çek; gelirse önbelleğe yaz ve kararı güncelle.
  /// Gelmezse (null) mevcut durum KORUNUR — asla "temizleyip" kapıyı gevşetmeyiz;
  /// aksi halde saldırgan/arıza, uçak modu + önbellek silme ile kapıyı atlatırdı.
  Future<void> refresh() async {
    final fresh = await ref.read(appConfigFetcherProvider)();
    if (fresh == null) return;

    int dismissed = -1;
    try {
      final prefs = ref.read(prefsProvider);
      await prefs.setString(_cacheKey, fresh.toJson());
      dismissed = prefs.getInt(_dismissedKey) ?? -1;
    } catch (_) {}

    state = _stateFor(fresh, dismissedBuild: dismissed);
  }

  /// Yumuşak öneriyi bu `latest_build` için kapat (bir sonraki sürümde yeniden
  /// görünür — kalıcı susturma değil, sürüm başına susturma).
  void dismissSuggestion() {
    final latest = state.config.latestBuild;
    if (latest == null) return;
    try {
      unawaited(ref.read(prefsProvider).setInt(_dismissedKey, latest));
    } catch (_) {}
    state = UpdateGateState(
      verdict: state.verdict,
      config: state.config,
      suggestionDismissed: true,
    );
  }
}

final updateGateProvider =
    NotifierProvider<UpdateGateController, UpdateGateState>(
      UpdateGateController.new,
    );
