import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/version_gate.dart';

// -----------------------------------------------------------------------------
// §20 ZORUNLU GÜNCELLEME — karar çekirdeği.
// En kritik sözleşme FAIL-OPEN: kapının kendi hatası (bozuk veri, okunamayan
// sürüm) kullanıcıyı ASLA kilitlememeli.
// -----------------------------------------------------------------------------

void main() {
  UpdateVerdict verdict(int current, {int? min, int? latest}) =>
      evaluateUpdateVerdict(
        currentBuild: current,
        config: AppConfig(minSupportedBuild: min, latestBuild: latest),
      );

  group('karar sınırları', () {
    test('güncel sürüm: hiçbir şey', () {
      expect(verdict(5, min: 3, latest: 5), UpdateVerdict.none);
    });

    test('min ALTINDA: zorunlu', () {
      expect(verdict(2, min: 3, latest: 5), UpdateVerdict.force);
    });

    test('tam min\'DE: zorunlu DEĞİL (eşik dahil desteklenir)', () {
      expect(verdict(3, min: 3, latest: 3), UpdateVerdict.none);
    });

    test('min üstü ama latest altı: öneri', () {
      expect(verdict(4, min: 3, latest: 6), UpdateVerdict.suggest);
    });

    test('force önerinin ÖNÜNE geçer', () {
      expect(verdict(1, min: 3, latest: 9), UpdateVerdict.force);
    });
  });

  group('fail-open', () {
    test('build okunamadı (0/negatif): kapı YOK', () {
      expect(verdict(0, min: 99, latest: 99), UpdateVerdict.none);
      expect(verdict(-1, min: 99, latest: 99), UpdateVerdict.none);
    });

    test('eşikler tanımsız: kapı YOK', () {
      expect(verdict(1), UpdateVerdict.none);
    });

    test('saçma min (0/negatif) yok sayılır', () {
      expect(verdict(5, min: 0), UpdateVerdict.none);
      expect(verdict(5, min: -7), UpdateVerdict.none);
    });

    test('bozuk map alanları null\'a düşer, karar none', () {
      final config = AppConfig.fromMap({
        'min_supported_build': 'sayı-değil',
        'latest_build': null,
      });
      expect(config.minSupportedBuild, isNull);
      expect(
        evaluateUpdateVerdict(currentBuild: 1, config: config),
        UpdateVerdict.none,
      );
    });

    test('bozuk önbellek JSON null döner, çökmez', () {
      expect(AppConfig.tryParse('{bozuk'), isNull);
      expect(AppConfig.tryParse(''), isNull);
      expect(AppConfig.tryParse(null), isNull);
    });
  });

  test('önbellek gidiş-dönüşü kayıpsız', () {
    const config = AppConfig(
      minSupportedBuild: 4,
      latestBuild: 7,
      messageEn: 'Please update',
      messageTr: 'Lütfen güncelle',
    );
    final round = AppConfig.tryParse(config.toJson())!;
    expect(round.minSupportedBuild, 4);
    expect(round.latestBuild, 7);
    expect(round.messageEn, 'Please update');
    expect(round.messageTr, 'Lütfen güncelle');
  });

  test('sunucu satırı biçimi doğru okunur (num -> int)', () {
    // PostgREST sayıları num olarak verebilir.
    final config = AppConfig.fromMap({
      'min_supported_build': 3.0,
      'latest_build': 5,
      'message_en': 'msg',
    });
    expect(config.minSupportedBuild, 3);
    expect(config.latestBuild, 5);
  });
}
