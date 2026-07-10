import 'package:shared_preferences/shared_preferences.dart';

import '../core/player_progress.dart';

/// İlerlemeyi kalıcı saklayan katman (arayüz).
///
/// Bugün [PrefsProgressRepository] (shared_preferences) ile; veri ilişkiselleşince
/// (aralıklı tekrar geçmişi, oturum kayıtları vb.) aynı arayüz ardında
/// Drift/SQLite'a geçebiliriz — çağıranlar değişmez.
abstract class ProgressRepository {
  /// Kaydedilmiş ilerlemeyi getirir; yoksa boş ilerleme döner.
  PlayerProgress load();

  /// İlerlemeyi kalıcı olarak yazar.
  Future<void> save(PlayerProgress progress);
}

/// shared_preferences tabanlı basit, güvenilir uygulama.
/// [SharedPreferences] örneği uygulama açılışında (main) hazırlanıp verilir,
/// böylece [load] senkron çalışır ve arayüzde yükleme durumu gerekmez.
class PrefsProgressRepository implements ProgressRepository {
  PrefsProgressRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String _key = 'player_progress_v1';

  @override
  PlayerProgress load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return PlayerProgress.empty;
    try {
      return PlayerProgress.fromJson(raw);
    } catch (_) {
      // Bozuk/eski veri — sıfırdan başla.
      return PlayerProgress.empty;
    }
  }

  @override
  Future<void> save(PlayerProgress progress) =>
      _prefs.setString(_key, progress.toJson());
}
