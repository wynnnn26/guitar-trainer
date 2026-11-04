import 'dart:async';

import 'package:flutter/material.dart';

import '../models/click_sound.dart';
import '../models/time_signature.dart';
import '../services/metronome_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/beat_indicator.dart';
import '../widgets/info_banner.dart';
import '../widgets/playback_controls.dart';
import '../widgets/screen_body.dart';
import '../widgets/tempo_card.dart';

class MetronomeScreen extends StatelessWidget {
  const MetronomeScreen({super.key, required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        return ScreenBody(
          title: 'Metronome',
          subtitle: 'Keep steady time while you practise.',
          children: [
            if (service.audioError != null) ...[
              InfoBanner(
                message: service.audioError!,
                icon: Icons.volume_off,
                color: AppColors.bad,
                onDismiss: service.clearAudioError,
              ),
              const SizedBox(height: 16),
            ],
            _ModeSwitcher(service: service),
            const SizedBox(height: 16),
            if (service.mode == MetronomeMode.basic)
              _BasicPanel(service: service)
            else
              _AdvancedPanel(service: service),
          ],
        );
      },
    );
  }
}

/// Segmented control switching between the Basic and Advanced metronome.
/// Switching always stops playback, so the modes can never click together.
class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MetronomeMode>(
      segments: const [
        ButtonSegment(value: MetronomeMode.basic, label: Text('Basic')),
        ButtonSegment(value: MetronomeMode.advanced, label: Text('Advanced')),
      ],
      selected: {service.mode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => service.setMode(selection.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.surfaceHigh,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.black
              : AppColors.textPrimary,
        ),
        side: WidgetStateProperty.all(const BorderSide(color: AppColors.outline)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Simple continuous clicker: pulse, big BPM display, playback controls.
class _BasicPanel extends StatelessWidget {
  const _BasicPanel({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              BeatPulse(service: service, showBeatNumber: false),
              const SizedBox(height: 16),
              _StatusChip(service: service),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TempoCard(service: service),
        const SizedBox(height: 16),
        PlaybackControls(service: service),
      ],
    );
  }
}

/// Running / Paused / Stopped indicator for the Basic panel.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (service.status) {
      MetronomeStatus.running => (AppColors.accent, 'Running'),
      MetronomeStatus.paused => (AppColors.textSecondary, 'Paused'),
      MetronomeStatus.stopped => (AppColors.outline, 'Stopped'),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

/// The full-featured metronome: pulse + beat dots, tempo, time signature,
/// per-beat accents, sound settings and playback controls.
class _AdvancedPanel extends StatelessWidget {
  const _AdvancedPanel({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              BeatPulse(service: service),
              const SizedBox(height: 18),
              BeatDots(service: service),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TempoCard(service: service),
        const SizedBox(height: 16),
        _TimeSignatureCard(service: service),
        const SizedBox(height: 16),
        _BeatCard(service: service),
        const SizedBox(height: 16),
        _SoundCard(service: service),
        const SizedBox(height: 16),
        PlaybackControls(service: service),
      ],
    );
  }
}

class _TimeSignatureCard extends StatelessWidget {
  const _TimeSignatureCard({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    final current = service.timeSignature;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TIME SIGNATURE', style: AppText.overline),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final signature in TimeSignature.presets)
                ChoiceChip(
                  label: Text(signature.label),
                  selected: signature == current,
                  showCheckmark: false,
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceHigh,
                  side: const BorderSide(color: AppColors.outline),
                  labelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: signature == current ? Colors.black : AppColors.textPrimary,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  onSelected: (_) => service.setTimeSignature(signature),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${current.pulsesPerMeasure} ${current.pulseDescription} per measure. '
            'BPM counts every click; accents are customised below.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// Per-beat accent / mute customisation.
class _BeatCard extends StatelessWidget {
  const _BeatCard({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BEATS', style: AppText.overline),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < service.timeSignature.pulsesPerMeasure; i++)
                _BeatChip(service: service, index: i),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap a beat to cycle: accented → normal → muted. '
            'Muted beats keep their place in the measure but stay silent.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// One beat of the measure. Tap cycles accented → normal → muted → accented.
class _BeatChip extends StatelessWidget {
  const _BeatChip({required this.service, required this.index});

  final MetronomeService service;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accents = service.accentBeats;
    final enabledFlags = service.beatEnabled;
    final accent = index < accents.length && accents[index];
    final enabled = index < enabledFlags.length && enabledFlags[index];

    final Color background;
    final Color sideColor;
    final Color labelColor;
    final IconData icon;
    final String state;
    if (!enabled) {
      background = AppColors.surfaceHigh;
      sideColor = AppColors.outline;
      labelColor = AppColors.textSecondary;
      icon = Icons.volume_off_outlined;
      state = 'muted';
    } else if (accent) {
      background = AppColors.accent;
      sideColor = AppColors.accent;
      labelColor = Colors.black;
      icon = Icons.star_rounded;
      state = 'accented';
    } else {
      background = AppColors.beat.withAlpha(35);
      sideColor = AppColors.beat;
      labelColor = AppColors.textPrimary;
      icon = Icons.volume_up_outlined;
      state = 'normal';
    }

    return Tooltip(
      message: 'Beat ${index + 1}: $state — tap to change',
      child: InkWell(
        onTap: _cycle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sideColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 16, color: labelColor),
            ],
          ),
        ),
      ),
    );
  }

  void _cycle() {
    final accents = service.accentBeats;
    final enabledFlags = service.beatEnabled;
    final accent = index < accents.length && accents[index];
    final enabled = index < enabledFlags.length && enabledFlags[index];
    if (!enabled) {
      service.setBeatEnabled(index, true);
      service.setBeatAccent(index, true); // muted → accented
    } else if (accent) {
      service.setBeatAccent(index, false); // accented → normal
    } else {
      service.setBeatEnabled(index, false); // normal → muted
    }
  }
}

/// Sound set picker (Woodblock / Classic / Digital / Soft) + volume slider.
class _SoundCard extends StatelessWidget {
  const _SoundCard({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    final percent = (service.volume * 100).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOUND', style: AppText.overline),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sound in ClickSound.values)
                ChoiceChip(
                  label: Text(sound.label),
                  selected: sound == service.sound,
                  showCheckmark: false,
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceHigh,
                  side: const BorderSide(color: AppColors.outline),
                  labelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: sound == service.sound ? Colors.black : AppColors.textPrimary,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  onSelected: (_) => unawaited(service.setSound(sound)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.volume_up_outlined, size: 20, color: AppColors.textSecondary),
              Expanded(
                child: Slider(
                  value: service.volume,
                  onChanged: service.setVolume,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.right,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
