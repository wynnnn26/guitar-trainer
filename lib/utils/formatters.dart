/// Formats a duration as `mm:ss.t` (minutes, seconds, tenths).
String formatStopwatch(Duration duration) {
  final totalTenths = duration.inMilliseconds ~/ 100;
  final minutes = totalTenths ~/ 600;
  final seconds = (totalTenths ~/ 10) % 60;
  final tenths = totalTenths % 10;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.$tenths';
}

/// Formats a short lap time such as `4.2 s`.
String formatLap(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';

/// Formats cents with an explicit sign, e.g. `+3.2` / `-12.0`.
String formatCents(double cents) {
  final rounded = cents.abs() < 0.05 ? 0.0 : cents;
  final sign = rounded > 0 ? '+' : (rounded < 0 ? '-' : '±');
  return '$sign${rounded.abs().toStringAsFixed(1)}';
}
