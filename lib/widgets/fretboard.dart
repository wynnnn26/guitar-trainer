import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/guitar_string.dart';
import '../theme/app_theme.dart';

/// Guitar fretboard (nut to 12th fret). The 1st (high E) string is drawn at
/// the top, like a tab. Positions are derived from standard tuning with
/// [GuitarString.fretFor], so they are always correct chromatic theory.
class Fretboard extends StatelessWidget {
  const Fretboard({
    super.key,
    required this.strings,
    this.highlightedString,
    this.markedPitchClass,
  });

  static const int fretCount = 12;

  final List<GuitarString> strings;

  /// String to emphasise (the others are dimmed).
  final GuitarString? highlightedString;

  /// When set (and a string is highlighted), dots mark where this note
  /// (0 = C ... 11 = B) is on the highlighted string.
  final int? markedPitchClass;

  @override
  Widget build(BuildContext context) {
    final highlighted = highlightedString;
    return Semantics(
      label: highlighted == null
          ? 'Guitar fretboard'
          : 'Guitar fretboard, ${highlighted.ordinal} string highlighted',
      child: AspectRatio(
        aspectRatio: 2.2,
        child: CustomPaint(
          painter: _FretboardPainter(
            strings: strings,
            highlightedString: highlightedString,
            markedPitchClass: markedPitchClass,
          ),
        ),
      ),
    );
  }
}

class _FretboardPainter extends CustomPainter {
  _FretboardPainter({
    required this.strings,
    required this.highlightedString,
    required this.markedPitchClass,
  });

  final List<GuitarString> strings;
  final GuitarString? highlightedString;
  final int? markedPitchClass;

  static const double _leftMargin = 46;
  static const double _rightMargin = 10;
  static const double _topPad = 14;
  static const double _bottomPad = 24;

  @override
  void paint(Canvas canvas, Size size) {
    if (strings.isEmpty) return;

    final ordered = [...strings]..sort((a, b) => a.number.compareTo(b.number));
    final boardLeft = _leftMargin;
    final boardRight = size.width - _rightMargin;
    final boardWidth = boardRight - boardLeft;
    final top = _topPad;
    final bottom = size.height - _bottomPad;
    final rowCount = ordered.length;
    final rowGap = rowCount > 1 ? (bottom - top) / (rowCount - 1) : 0.0;

    double fretX(int n) {
      final p = math.pow(2, -n / 12).toDouble();
      return boardLeft + boardWidth * (1 - p) / 0.5; // fret 12 lands on boardRight
    }

    double rowY(int row) => top + row * rowGap;
    double fretCenterX(int n) => (fretX(n - 1) + fretX(n)) / 2;

    // Wood.
    canvas.drawRRect(
      RRect.fromLTRBR(boardLeft, top - 9, boardRight, bottom + 9, const Radius.circular(6)),
      Paint()..color = const Color(0xFF2A2119),
    );

    // Position inlays.
    final inlayPaint = Paint()..color = const Color(0x33FFFFFF);
    final midY = (top + bottom) / 2;
    for (final n in const [3, 5, 7, 9]) {
      canvas.drawCircle(Offset(fretCenterX(n), midY), 5, inlayPaint);
    }
    final x12 = fretCenterX(12);
    canvas.drawCircle(Offset(x12, top + (bottom - top) * 0.28), 5, inlayPaint);
    canvas.drawCircle(Offset(x12, top + (bottom - top) * 0.72), 5, inlayPaint);

    // Frets and nut.
    final fretPaint = Paint()
      ..color = const Color(0xFF8A8F9C)
      ..strokeWidth = 1.4;
    for (var n = 1; n <= Fretboard.fretCount; n++) {
      final x = fretX(n);
      canvas.drawLine(Offset(x, top - 9), Offset(x, bottom + 9), fretPaint);
    }
    canvas.drawLine(
      Offset(boardLeft, top - 9),
      Offset(boardLeft, bottom + 9),
      Paint()
        ..color = const Color(0xFFE2DCCF)
        ..strokeWidth = 5,
    );

    // Fret numbers.
    for (final n in const [3, 5, 7, 9, 12]) {
      _drawText(
        canvas,
        '$n',
        Offset(fretCenterX(n), bottom + 9 + 8),
        const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        center: true,
      );
    }

    // Strings + labels.
    final hasHighlight = highlightedString != null;
    for (var row = 0; row < rowCount; row++) {
      final string = ordered[row];
      final y = rowY(row);
      final isHighlighted = string == highlightedString;
      final thickness = 1.0 + (string.number - 1) * 0.45 + (isHighlighted ? 1.5 : 0);

      if (isHighlighted) {
        canvas.drawLine(
          Offset(boardLeft, y),
          Offset(boardRight, y),
          Paint()
            ..color = AppColors.accent.withAlpha(110)
            ..strokeWidth = thickness + 7
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      final dim = hasHighlight && !isHighlighted;
      canvas.drawLine(
        Offset(boardLeft, y),
        Offset(boardRight, y),
        Paint()
          ..color = isHighlighted
              ? AppColors.accent
              : const Color(0xFFD5D8DF).withAlpha(dim ? 90 : 220)
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round,
      );
      _drawText(
        canvas,
        '${string.number}  ${string.noteName}',
        Offset(4, y),
        TextStyle(
          fontSize: 12,
          fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w500,
          color: isHighlighted ? AppColors.accent : AppColors.textSecondary,
        ),
      );
    }

    // Note markers on the highlighted string.
    final marked = markedPitchClass;
    final target = highlightedString;
    if (marked != null && target != null) {
      final row = ordered.indexOf(target);
      if (row >= 0) {
        final y = rowY(row);
        final fret = target.fretFor(marked);
        final frets = fret == 0 ? const [0, 12] : [fret];
        for (final f in frets) {
          final x = f == 0 ? boardLeft - 14 : fretCenterX(f);
          canvas.drawCircle(Offset(x, y), 10, Paint()..color = AppColors.accent);
          canvas.drawCircle(
            Offset(x, y),
            10,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFF2A2119),
          );
        }
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style,
      {bool center = false}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? position.dx - painter.width / 2 : position.dx;
    painter.paint(canvas, Offset(dx, position.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FretboardPainter old) =>
      old.highlightedString != highlightedString ||
      old.markedPitchClass != markedPitchClass ||
      old.strings != strings;
}
