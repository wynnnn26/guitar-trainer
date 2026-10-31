import 'package:flutter/material.dart';

import '../models/guitar_string.dart';
import '../models/tuner_models.dart';
import '../services/tuner_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/info_banner.dart';
import '../widgets/screen_body.dart';
import '../widgets/tuner_meter.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key, required this.service});

  final TunerService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final List<Widget> children;
        switch (service.status) {
          case TunerStatus.idle:
            children = _idle();
          case TunerStatus.starting:
            children = _starting();
          case TunerStatus.listening:
            children = _listening();
          case TunerStatus.permissionDenied:
            children = _permissionDenied();
          case TunerStatus.error:
            children = _error();
        }
        return ScreenBody(
          title: 'Guitar Tuner',
          subtitle: 'Pluck a string and match the pitch.',
          children: children,
        );
      },
    );
  }

  // ----------------------------------------------------------------- idle

  List<Widget> _idle() {
    return [
      AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceHigh),
              child: const Icon(Icons.mic, size: 42, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tune your guitar',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap Start, then pluck one string at a time. The tuner listens '
              'through your microphone only while it is switched on and you '
              'are on this screen.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: service.start,
        icon: const Icon(Icons.mic),
        label: const Text('Start Tuner'),
      ),
    ];
  }

  List<Widget> _starting() {
    return const [
      AppCard(
        padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Starting microphone…',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'If asked, allow microphone access.',
              style: AppText.caption,
            ),
          ],
        ),
      ),
    ];
  }

  // ---------------------------------------------------------- problem states

  List<Widget> _permissionDenied() {
    return [
      InfoBanner(
        message: service.message ?? 'Microphone permission is required.',
        icon: Icons.mic_off,
        color: AppColors.bad,
      ),
      const SizedBox(height: 16),
      if (service.permissionPermanentlyDenied) ...[
        FilledButton.icon(
          onPressed: service.openSystemSettings,
          icon: const Icon(Icons.settings),
          label: const Text('Open Settings'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: service.start,
          icon: const Icon(Icons.refresh),
          label: const Text('Check Again'),
        ),
      ] else
        FilledButton.icon(
          onPressed: service.start,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
        ),
    ];
  }

  List<Widget> _error() {
    return [
      InfoBanner(
        message: service.message ?? 'Something went wrong with the tuner.',
        icon: Icons.error_outline,
        color: AppColors.bad,
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: service.start,
        icon: const Icon(Icons.refresh),
        label: const Text('Try Again'),
      ),
    ];
  }

  // -------------------------------------------------------------- listening

  List<Widget> _listening() {
    final reading = service.reading;
    return [
      _StringSelector(service: service),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          children: [
            _NoteReadout(reading: reading),
            const SizedBox(height: 12),
            TunerMeter(cents: reading?.cents, direction: reading?.direction),
            const SizedBox(height: 12),
            _DirectionBanner(reading: reading, signal: service.signal),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _TargetInfo(service: service, reading: reading),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: service.stop,
        icon: const Icon(Icons.mic_off),
        label: const Text('Stop Tuner'),
      ),
    ];
  }
}

class _StringSelector extends StatelessWidget {
  const _StringSelector({required this.service});

  final TunerService service;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STRING', style: AppText.overline),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(label: 'Auto', selected: service.isAutoMode, onTap: () => service.selectString(null)),
              for (final string in service.strings)
                _chip(
                  label: '${string.number} · ${string.label}',
                  selected: service.selectedString == string,
                  onTap: () => service.selectString(string),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surfaceHigh,
      side: const BorderSide(color: AppColors.outline),
      labelStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.black : AppColors.textPrimary,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _NoteReadout extends StatelessWidget {
  const _NoteReadout({required this.reading});

  final TunerReading? reading;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final color = r == null
        ? AppColors.textSecondary
        : switch (r.direction) {
            TuneDirection.inTune => AppColors.good,
            _ => AppColors.textPrimary,
          };

    // Not a live region: the reading updates ~20x per second.
    return Semantics(
      label: r == null
          ? 'No note detected'
          : 'Detected ${r.noteLabel}, ${r.frequency.toStringAsFixed(1)} hertz, '
              '${formatCents(r.cents)} cents',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: r?.noteName ?? '–', style: AppText.display(92, color: color)),
                  if (r != null)
                    TextSpan(text: '${r.octave}', style: AppText.display(36, color: color)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  r == null ? '— Hz' : '${r.frequency.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppText.tabularFigures,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  r == null ? '— cents' : '${formatCents(r.cents)} cents',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontFeatures: AppText.tabularFigures,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionBanner extends StatelessWidget {
  const _DirectionBanner({required this.reading, required this.signal});

  final TunerReading? reading;
  final SignalQuality signal;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final String title;
    final String detail;
    final IconData icon;
    final Color color;

    if (r == null) {
      icon = Icons.hearing;
      color = AppColors.textSecondary;
      switch (signal) {
        case SignalQuality.weak:
          title = 'Listening…';
          detail = 'Too quiet. Pluck a string closer to the microphone.';
        case SignalQuality.unclear:
          title = 'No clear note';
          detail = 'Let one string ring, mute the others and reduce background noise.';
        case SignalQuality.none:
        case SignalQuality.good:
          title = 'Pluck a string';
          detail = 'Play one open string and let it ring.';
      }
    } else {
      switch (r.direction) {
        case TuneDirection.inTune:
          title = 'In Tune';
          detail = 'Perfect. Move on to the next string.';
          icon = Icons.check_circle;
          color = AppColors.good;
        case TuneDirection.tuneUp:
          title = 'Tune Up';
          detail = 'Flat. Tighten the string slightly.';
          icon = Icons.arrow_upward;
          color = r.cents.abs() <= 20 ? AppColors.accent : AppColors.bad;
        case TuneDirection.tuneDown:
          title = 'Tune Down';
          detail = 'Sharp. Loosen the string slightly.';
          icon = Icons.arrow_downward;
          color = r.cents.abs() <= 20 ? AppColors.accent : AppColors.bad;
      }
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withAlpha(32),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(140)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(detail, style: AppText.caption, textAlign: TextAlign.center),
        if (r != null && r.farFromTarget) ...[
          const SizedBox(height: 8),
          Text(
            'That is far from ${r.targetString.label}. Check the selected string or switch to Auto.',
            style: const TextStyle(fontSize: 13, color: AppColors.accent, height: 1.35),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _TargetInfo extends StatelessWidget {
  const _TargetInfo({required this.service, required this.reading});

  final TunerService service;
  final TunerReading? reading;

  @override
  Widget build(BuildContext context) {
    final GuitarString? target = service.selectedString ?? reading?.targetString;
    final String text;
    if (target == null) {
      text = 'Auto mode: the tuner picks the closest string to what you play.';
    } else {
      final prefix = service.isAutoMode ? 'Detected string' : 'Target';
      text = '$prefix: ${target.ordinal} string · ${target.label} · '
          '${target.frequency.toStringAsFixed(2)} Hz';
    }
    return Center(
      child: Text(text, style: AppText.caption, textAlign: TextAlign.center),
    );
  }
}
