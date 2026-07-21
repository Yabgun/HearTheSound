import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/auth_validation.dart';

// Kimlik girdi kontrolleri (saf): geçersiz istek hiç gönderilmemeli.
void main() {
  group('isValidEmail', () {
    test('geçerli adresleri kabul eder', () {
      for (final email in [
        'a@b.co',
        'bugrattumlu@gmail.com',
        'first.last+tag@sub.domain.org',
        '  boslukla@trim.com  ', // trim edilir
      ]) {
        expect(isValidEmail(email), isTrue, reason: email);
      }
    });

    test('geçersizleri reddeder', () {
      for (final email in [
        '',
        '   ',
        'duz-metin',
        '@yok.com',
        'kullanici@',
        'kullanici@alan', // TLD yok
        'bosluk lu@alan.com',
      ]) {
        expect(isValidEmail(email), isFalse, reason: '"$email"');
      }
    });
  });

  group('isAcceptableNewPassword', () {
    test('en az $kMinPasswordLength karakter ister', () {
      expect(isAcceptableNewPassword('1234567'), isFalse);
      expect(isAcceptableNewPassword('12345678'), isTrue);
      expect(isAcceptableNewPassword(''), isFalse);
    });

    test('boşluk içeren uzun şifreyi kabul eder (parola cümlesi)', () {
      expect(isAcceptableNewPassword('kirmizi at kosuyor'), isTrue);
    });
  });

  group('isValidOtpCode', () {
    test('tam $kOtpCodeLength hane kabul edilir', () {
      expect(isValidOtpCode('123456'), isTrue);
      expect(isValidOtpCode(' 123456 '), isTrue);
    });

    test('eksik/fazla/rakam-dışı reddedilir', () {
      for (final code in ['', '12345', '1234567', '12345a', 'abcdef']) {
        expect(isValidOtpCode(code), isFalse, reason: '"$code"');
      }
    });
  });
}
