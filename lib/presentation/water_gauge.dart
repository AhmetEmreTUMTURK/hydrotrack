import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class WaterGauge extends StatelessWidget {
  const WaterGauge({super.key, required this.progress, required this.goalMl});
  final double progress;
  final int goalMl;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Günlük su hedefi',
    value: '%${(progress * 100).round()}',
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 850),
      curve: Curves.easeInOutCubic,
      builder: (context, level, _) => CustomPaint(
        key: const Key('water-gauge'),
        size: const Size(160, 270),
        painter: WaterGaugePainter(level, goalMl),
      ),
    ),
  );
}

class WaterGaugePainter extends CustomPainter {
  WaterGaugePainter(this.level, this.goalMl);
  final double level;
  final int goalMl;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, 68, size.height - 20);
    final capsule = RRect.fromRectAndRadius(rect, const Radius.circular(34));
    canvas.drawRRect(capsule, Paint()..color = const Color(0xFFEAF3F4));
    canvas.save();
    canvas.clipRRect(capsule);
    if (level > 0) {
      final top = rect.bottom - rect.height * level;
      final wave = Path()..moveTo(rect.left, top);
      for (var x = 0.0; x <= rect.width; x++) {
        final y = top + math.sin(x / rect.width * math.pi * 2) * 3;
        wave.lineTo(rect.left + x, y);
      }
      wave
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      canvas.drawPath(
        wave,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF62CFD9), Color(0xFF138C9B)],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            20,
            math.max(top + 14, 24),
            5,
            math.max(0, rect.bottom - math.max(top + 14, 24) - 24),
          ),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: .24),
      );
    }
    for (var i = 1; i < 20; i++) {
      final y = rect.bottom - rect.height * i / 20;
      canvas.drawLine(
        Offset(51, y),
        Offset(i % 5 == 0 ? 72 : 64, y),
        Paint()
          ..color = const Color(0xFF719EA5).withValues(alpha: .45)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      capsule,
      Paint()
        ..color = const Color(0xFFD9E9EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (var i = 0; i <= 4; i++) {
      final text = TextPainter(
        text: TextSpan(
          text: '${(goalMl * i / 4).round()} ml',
          style: const TextStyle(color: muted, fontSize: 11, fontFamily: 'Roboto'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final y = rect.bottom - rect.height * i / 4;
      canvas.drawLine(
        Offset(88, y),
        Offset(94, y),
        Paint()..color = const Color(0xFFBDD3D7),
      );
      text.paint(canvas, Offset(101, y - text.height / 2));
    }
  }

  @override
  bool shouldRepaint(WaterGaugePainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.goalMl != goalMl;
}
