import 'package:flutter/material.dart';

import '../core/content_locale.dart';
import '../core/note.dart';
import 'app_theme.dart';

// -----------------------------------------------------------------------------
// NOTA ADLARI — BAŞVURU KARTI ("C = Do")
//
// NEDEN VAR: uygulama notaları HARFLE gösterir (C-D-E), ama Türkiye'de ve
// birçok ülkede müzik Do-Re-Mi ile öğretilir. Harfleri hiç görmemiş bir
// kullanıcı ekrandaki "C" tuşuna bakıp ne olduğunu bilemiyor — ders zor değil,
// ALFABE yabancı. Bu kart o tek boşluğu kapatır.
//
// NEDEN YENİDEN ADLANDIRMA DEĞİL: harf isimleri BİRİNCİL kalır (ürün kararı).
// Bu bir sözlük; ekranların dili değişmiyor. (Tüm uygulamayı Do-Re-Mi'ye çeviren
// bir anahtar ileride tartışılabilir; tuzağı, karıştırma istatistiği
// anahtarlarının nota adlarını kullanması — onlar harf kalmalı.)
//
// NEREDEN AÇILIR: Ayarlar'da bir satır + nota adı GÖSTEREN oyun ekranlarının
// başlığındaki [NoteNamesButton] (Notalar dersleri · Eko Oyunu · Armoni bas
// bulma · Akor kurma). Akor sembolü gösteren ekranlarda yok — orada okunan şey
// nota adı değil akor adı.
// -----------------------------------------------------------------------------

/// Kartı alttan açar. Her yerden aynı çağrı — içerik tek yerde yaşar.
Future<void> showNoteNamesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _NoteNamesSheet(),
  );
}

/// Nota adı gösteren ekranların başlığına konan küçük ℹ️ düğmesi.
///
/// Sözsüz düğme → `tooltip` hem uzun basışta yazıyı gösterir hem Semantics
/// etiketini kurar (ekran okuyucu "düğme" değil "nota adları" demeli).
class NoteNamesButton extends StatelessWidget {
  const NoteNamesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showNoteNamesSheet(context),
      tooltip: t(en: 'Note names', tr: 'Nota adları'),
      icon: const Icon(Icons.info_outline_rounded),
    );
  }
}

class _NoteNamesSheet extends StatelessWidget {
  const _NoteNamesSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(en: 'Note names', tr: 'Nota adları'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  en: 'This app names notes with letters. If you learned '
                      'Do-Re-Mi, they are the same seven notes:',
                  tr: 'Bu uygulama notaları harflerle adlandırır. Sen '
                      'Do-Re-Mi öğrendiysen, bunlar aynı yedi nota:',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 16),
              // İKİ SÜTUN: yedi satır alt alta dizilince kart telefonda
              // kaydırma gerektiriyordu — bir SÖZLÜĞE bakmak için kaydırmak
              // gerekmemeli, göz tek bakışta eşleşmeyi bulmalı.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        for (final (:letter, :solfege)
                            in noteNameBridge.take(4))
                          _BridgeRow(letter: letter, solfege: solfege),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        for (final (:letter, :solfege)
                            in noteNameBridge.skip(4))
                          _BridgeRow(letter: letter, solfege: solfege),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Note(
                heading: t(en: 'What is C#?', tr: 'C# nedir?'),
                body: t(
                  en: 'The # sign means "sharp": one tiny step up. C# sits '
                      'right between C and D — on a piano it is the black key '
                      'just to the right of C.',
                  tr: '# işareti "diyez" demek: bir minik basamak yukarı. C#, '
                      'C ile D\'nin tam arasındadır — piyanoda C\'nin hemen '
                      'sağındaki siyah tuştur.',
                ),
              ),
              const SizedBox(height: 14),
              _Note(
                heading: t(
                  en: 'What is the number in "C4"?',
                  tr: '"C4"taki sayı ne?',
                ),
                body: t(
                  en: 'It tells you how high the note is. C4 and C5 are the '
                      'same note name — C5 is just one octave higher, so it '
                      'sounds thinner. The bigger the number, the higher.',
                  tr: 'Notanın ne kadar tiz olduğunu söyler. C4 ile C5 aynı '
                      'notadır — C5 bir oktav yukarıdadır, yani daha ince '
                      'duyulur. Sayı büyüdükçe ses tizleşir.',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t(en: 'Got it', tr: 'Anladım')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek satır: harf rozeti = solfej adı.
///
/// Harf ROZETTE (ekrandaki tuşlarla aynı görünüm), solfej yanında düz metin —
/// hangisinin birincil olduğu bakışta belli olsun.
class _BridgeRow extends StatelessWidget {
  final String letter;
  final String solfege;

  const _BridgeRow({required this.letter, required this.solfege});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.grapeSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              letter,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.grape,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '=',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.faint,
            ),
          ),
          const SizedBox(width: 10),
          // Uzun ad (Sol) büyük metin ölçeğinde taşmasın diye esner.
          Expanded(
            child: Text(
              solfege,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Başlıklı küçük açıklama bloğu (diyez / oktav sayısı).
class _Note extends StatelessWidget {
  final String heading;
  final String body;

  const _Note({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
      ],
    );
  }
}
