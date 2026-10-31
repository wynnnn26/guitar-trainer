import 'package:flutter/material.dart';

import '../models/tuner_models.dart';
import '../theme/app_theme.dart';
import '../services/tuner_service.dart';

/// Horizontal tuning meter, -50 .. +50 cents, with a smoothly moving needle.
/// Pass `cents: null` when there is no pitch to show.
class TunerMeter extends StatelessWidget {
  const TunerMeter({super.key, required this.cents, required this.direction});

  final double? cents;
  final TuneDirection? direction;

  static const double rangeCents = 50;

  @override
  Widget build(BuildContext context) {
    final value = cents;
    final target = value == null ? 0.0 : value.clamp(-rangeCents, rangeCents).toDouble();
    final color = value == null
        ? AppColors.textSecondary.withAlpha(110)
        : switch (direction) {
            TuneDirection.inTune => AppColors.good,
            _ => value.abs() <= 20 ? AppColors.accent : AppColors.bad,
          };

    return Semantics(
      label: value == null
          ? 'Tuning meter, no signal'
          : 'Tuning meter, ${value.abs().toStringAsFixed(0)} cents ${value < 0 ? 'flat' : 'sharp'}',
      child: SizedBox(
        height: 112,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: target),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          builder: (context, position, _) => CustomPaint(
            painter: _MeterPainter(position: position, needleColor: color, active: value != null),
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({required this.position, required this.needleColor, required this.active});

  final double position;
  final Color needleColor;
  final bool active;

  static const double _sidePad = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final halfWidth = centerX - _sidePad;
    double xFor(double cents) => centerX + cents / TunerMeter.rangeCents * halfWidth;

    const trackTop = 34.0;
    final trackBottom = size.height - 18;

    // In-tune zone.
    final zone = RRect.fromLTRBR(
      xFor(-TunerService.inTuneCents),
      trackTop - 6,
      xFor(TunerService.inTuneCents),
      trackBottom + 6,
      const Radius.circular(8),
    );
    canvas.drawRRect(zone, Paint()..color = AppColors.good.withAlpha(46));

    // Ticks every 5 cents; longer at 0 / +-25 / +-50.
    for (var c = -50; c <= 50; c += 5) {
      final isMajor = c % 25 == 0;
      final isCenter = c == 0;
      final x = xFor(c.toDouble());
      final tickTop = isMajor ? trackTop : trackTop + 14;
      canvas.drawLine(
        Offset(x, tickTop),
        Offset(x, trackBottom),
        Paint()
          ..color = isCenter ? AppColors.good : AppColors.outline.withAlpha(isMajor ? 255 : 200)
          ..strokeWidth = isCenter ? 3 : (isMajor ? 2 : 1.5)
          ..strokeCap = StrokeCap.round,
      );
    }

    _text(canvas, '♭', Offset(xFor(-50), 12), 24, AppColors.textSecondary);
    _text(canvas, '♯', Offset(xFor(50), 12), 24, AppColors.textSecondary);
    _text(canvas, '0', Offset(centerX, 12), 14, AppColors.good);

    // Needle.
    final nx = xFor(position);
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = active ? 5 : 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(nx, trackTop - 8), Offset(nx, trackBottom + 8), needlePaint);
    canvas.drawCircle(Offset(nx, trackBottom + 8), active ? 7 : 5, Paint()..color = needleColor);
  }

  void _text(Canvas canvas, String text, Offset center, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MeterPainter old) =>
      old.position != position || old.needleColor != needleColor || old.active != active;
}
