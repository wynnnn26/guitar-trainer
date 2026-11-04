import 'package:flutter/material.dart';

import '../services/metronome_service.dart';
import '../theme/app_theme.dart';

/// Big pulsing disc that flashes on every click.
///
/// Advanced mode shows the beat number and flashes the accent colour on
/// accented beats; with [showBeatNumber] = false (Basic metronome) it is a
/// plain green pulse with a note glyph instead.
class BeatPulse extends StatefulWidget {
  const BeatPulse({
    super.key,
    required this.service,
    this.size = 148,
    this.showBeatNumber = true,
  });

  final MetronomeService service;
  final double size;
  final bool showBeatNumber;

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
        final accents = service.accentBeats;
        final flash = 1 - Curves.easeOut.transform(_controller.value);

        final bool accented;
        if (!widget.showBeatNumber) {
          accented = true; // Basic mode: every click is the same green pulse.
        } else {
          accented = beat >= 0 && beat < accents.length && accents[beat];
        }
        final flashColor = accented ? AppColors.accent : AppColors.beat;
        final fill = Color.lerp(AppColors.surfaceHigh, flashColor, flash)!;
        final textColor = Color.lerp(AppColors.textPrimary, Colors.black, flash)!;
        final ringColor =
            service.status == MetronomeStatus.stopped ? AppColors.outline : flashColor.withAlpha(150);

        final String semantics;
        if (!widget.showBeatNumber) {
          semantics = service.isRunning
              ? 'Metronome running at ${service.bpm} BPM'
              : 'Metronome $statusWord';
        } else {
          semantics = beat < 0 ? 'Metronome stopped' : 'Beat ${beat + 1}';
        }

        return Semantics(
          label: semantics,
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
              child: widget.showBeatNumber
                  ? Text(
                      beat < 0 ? '–' : '${beat + 1}',
                      style: AppText.display(widget.size * 0.45, color: textColor),
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      size: widget.size * 0.36,
                      color: textColor,
                    ),
            ),
          ),
        );
      },
    );
  }

  String get statusWord => switch (widget.service.status) {
        MetronomeStatus.running => 'running',
        MetronomeStatus.paused => 'paused',
        MetronomeStatus.stopped => 'stopped',
      };
}

/// Row of small dots, one per beat of the measure, highlighting the current
/// one. Accented beats are lime, normal beats blue, muted beats dim grey.
class BeatDots extends StatelessWidget {
  const BeatDots({super.key, required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    final signature = service.timeSignature;
    final current = service.currentBeat;
    final isActive = service.status != MetronomeStatus.stopped;
    final accents = service.accentBeats;
    final enabled = service.beatEnabled;

    final dots = <Widget>[];
    for (var i = 0; i < signature.pulsesPerMeasure; i++) {
      if (i > 0 && signature.groupSize > 1 && i % signature.groupSize == 0) {
        dots.add(const SizedBox(width: 12));
      }
      final isCurrent = isActive && i == current;
      final isOn = i < enabled.length && enabled[i];
      final isAccented = i < accents.length && accents[i];
      final baseColor = !isOn
          ? AppColors.outline
          : isAccented
              ? AppColors.accent
              : AppColors.beat;
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
