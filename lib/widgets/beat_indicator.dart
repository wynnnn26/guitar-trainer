import 'package:flutter/material.dart';

import '../services/metronome_service.dart';
import '../theme/app_theme.dart';

/// Big pulsing disc that flashes on every click and shows the beat number.
/// The downbeat (beat 1) flashes amber; other beats flash blue.
class BeatPulse extends StatefulWidget {
  const BeatPulse({super.key, required this.service, this.size = 148});

  final MetronomeService service;
  final double size;

  @override
  State<BeatPulse> createState() => _BeatPulseState();
}

class _BeatPulseState extends State<BeatPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _lastPulse = 0;

  @override
  void initState() {
    super.initState();
    // value: 1.0 == animation finished == no flash while idle.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1.0,
    );
    _lastPulse = widget.service.pulseCount;
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void didUpdateWidget(covariant BeatPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.removeListener(_onServiceChanged);
      _lastPulse = widget.service.pulseCount;
      widget.service.addListener(_onServiceChanged);
    }
  }

  void _onServiceChanged() {
    final pulse = widget.service.pulseCount;
    if (pulse != _lastPulse) {
      _lastPulse = pulse;
      if (widget.service.isRunning) _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, widget.service]),
      builder: (context, _) {
        final service = widget.service;
        final beat = service.currentBeat;
        final isDownbeat = beat == 0;
        final flash = 1 - Curves.easeOut.transform(_controller.value);
        final flashColor = isDownbeat ? AppColors.accent : AppColors.beat;
        final fill = Color.lerp(AppColors.surfaceHigh, flashColor, flash)!;
        final textColor = Color.lerp(AppColors.textPrimary, Colors.black, flash)!;
        final ringColor =
            service.status == MetronomeStatus.stopped ? AppColors.outline : flashColor.withAlpha(150);

        return Semantics(
          label: beat < 0 ? 'Metronome stopped' : 'Beat ${beat + 1}',
          child: Transform.scale(
            scale: 1 + 0.08 * flash,
            child: Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: Border.all(color: ringColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: flashColor.withAlpha((flash * 140).round()),
                    blurRadius: 36 * flash,
                    spreadRadius: 4 * flash,
                  ),
                ],
              ),
              child: Text(
                beat < 0 ? '–' : '${beat + 1}',
                style: AppText.display(widget.size * 0.45, color: textColor),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Row of small dots, one per beat of the measure, highlighting the current one.
class BeatDots extends StatelessWidget {
  const BeatDots({super.key, required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    final signature = service.timeSignature;
    final current = service.currentBeat;
    final isActive = service.status != MetronomeStatus.stopped;

    final dots = <Widget>[];
    for (var i = 0; i < signature.pulsesPerMeasure; i++) {
      if (i > 0 && signature.groupSize > 1 && i % signature.groupSize == 0) {
        dots.add(const SizedBox(width: 12));
      }
      final isCurrent = isActive && i == current;
      final baseColor = i == 0 ? AppColors.accent : AppColors.beat;
      dots.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 20 : 14,
          height: isCurrent ? 20 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent ? baseColor : baseColor.withAlpha(60),
            border: Border.all(color: baseColor.withAlpha(isCurrent ? 255 : 120)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: dots,
      ),
    );
  }
}
