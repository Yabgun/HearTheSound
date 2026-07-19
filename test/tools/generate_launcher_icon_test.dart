import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/features/mascot/eko_mascot.dart';
import 'package:hear_the_sound/ui/app_theme.dart';

// -----------------------------------------------------------------------------
// LAUNCHER İKON ÜRETİCİ (araç — varsayılan atlanır)
//
// Eko maskotunu marka gradyanı üstünde 1024px PNG'ye render eder:
//   assets/icon/app_icon.png            → klasik ikon (tam kare)
//   assets/icon/app_icon_foreground.png → adaptif ön plan (şeffaf zemin,
//                                         güvenli bölge için ~%62 ölçek)
// Sonra `dart run flutter_launcher_icons` mipmap'leri üretir.
//
// Çalıştırmak için:
//   flutter test test/tools/generate_launcher_icon_test.dart --run-skipped
// -----------------------------------------------------------------------------

Future<void> _renderToPng(
  WidgetTester tester,
  Widget widget,
  String path,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: key, child: widget),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('Eko launcher ikonlarını üret', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1024));
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });

    // 1) Klasik ikon: marka gradyanı + büyük Eko.
    await _renderToPng(
      tester,
      Container(
        width: 1024,
        height: 1024,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.grape, AppColors.coral],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const EkoMascot(size: 720),
      ),
      'assets/icon/app_icon.png',
    );

    // 2) Adaptif ön plan: şeffaf zemin + güvenli bölgeye sığan Eko
    //    (Android maskesi kenarlardan ~%25 kırpabilir).
    await _renderToPng(
      tester,
      Container(
        width: 1024,
        height: 1024,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: const EkoMascot(size: 640),
      ),
      'assets/icon/app_icon_foreground.png',
    );

    expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
    expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);
    // Araç testi — normal koşuda atlanır; üretmek için --run-skipped kullan.
  }, skip: true);
}
