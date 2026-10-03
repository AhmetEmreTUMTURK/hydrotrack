import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_application/application/hydration_controller.dart';
import 'package:water_application/domain/models.dart';
import 'package:water_application/main.dart';
import 'package:water_application/presentation/water_gauge.dart';

class PreviewController extends HydrationController {
  @override
  Future<HydrationState> build() async {
    final plan = HydrationPlan(id: 1, name: 'Günlük denge', goalMl: 2500);
    return HydrationState(
      plans: [plan],
      activePlan: plan,
      day: '2026-10-03',
      entries: [
        WaterEntry(
          id: 1,
          planId: 1,
          amountMl: 1250,
          recordedAt: DateTime(2026, 10, 3, 10),
          day: '2026-10-03',
        ),
      ],
    );
  }

  @override
  Future<bool> refresh() async => true;
}

void main() {
  testWidgets(
    'phone layout, navigation and plan editor render without overflow',
    (tester) async {
      const previewFont = String.fromEnvironment('PREVIEW_FONT');
      if (previewFont.isNotEmpty) {
        await tester.runAsync(() async {
          final loader = FontLoader('Roboto');
          loader.addFont(
            Future.value(
              ByteData.sublistView(await File(previewFont).readAsBytes()),
            ),
          );
          await loader.load();
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  '${File(previewFont).parent.path}/materialicons-regular.otf',
                ).readAsBytes(),
              ),
            ),
          );
          await icons.load();
        });
      }
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hydrationProvider.overrideWith(PreviewController.new),
            clockProvider.overrideWithValue(() => DateTime(2026, 10, 3, 10)),
          ],
          child: const RepaintBoundary(
            key: Key('preview'),
            child: HydroTrackApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Her yudum, iyi gelir.'), findsOneWidget);
      expect(find.byType(WaterGauge), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('WRITE_PREVIEW')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('docs/home-preview.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Planlar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni plan oluştur'));
      await tester.pumpAndSettle();
      expect(find.text('Kendi ritmini oluştur'), findsOneWidget);
      await tester.tap(find.text('Özel saatler'));
      await tester.pumpAndSettle();
      expect(find.text('Saat ekle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gauge animates up and down to the new progress', (tester) async {
    Widget gauge(double level) => MaterialApp(
      home: Scaffold(body: WaterGauge(progress: level, goalMl: 2500)),
    );
    double level() =>
        (tester
                    .widget<CustomPaint>(find.byKey(const Key('water-gauge')))
                    .painter!
                as WaterGaugePainter)
            .level;
    await tester.pumpWidget(gauge(0));
    await tester.pumpWidget(gauge(.8));
    await tester.pump(const Duration(milliseconds: 400));
    expect(level(), greaterThan(0));
    expect(level(), lessThan(.8));
    await tester.pumpAndSettle();
    expect(level(), .8);
    await tester.pumpWidget(gauge(.2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(level(), lessThan(.8));
    expect(level(), greaterThan(.2));
    await tester.pumpAndSettle();
    expect(level(), closeTo(.2, .0001));
  });
}
