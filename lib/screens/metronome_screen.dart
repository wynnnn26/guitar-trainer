import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/time_signature.dart';
import '../services/metronome_service.dart';
import '../theme/app_theme.dart';
import '../utils/music_theory.dart';
import '../widgets/app_card.dart';
import '../widgets/beat_indicator.dart';
import '../widgets/info_banner.dart';
import '../widgets/screen_body.dart';

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
              ),
              const SizedBox(height: 16),
            ],
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
            _TempoCard(service: service),
            const SizedBox(height: 16),
            _TimeSignatureCard(service: service),
            const SizedBox(height: 16),
            _Controls(service: service),
          ],
        );
      },
    );
  }
}

class _TempoCard extends StatelessWidget {
  const _TempoCard({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    final bpm = service.bpm;
    return AppCard(
      child: Column(
        children: [
          Text(MusicTheory.tempoName(bpm).toUpperCase(), style: AppText.overline),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: 'Tempo $bpm beats per minute. Double tap to type a value.',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _editBpm(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$bpm', style: AppText.display(88)),
                      const SizedBox(width: 8),
                      const Text(
                        'BPM',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final step in const [-5, -1, 1, 5])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: (step > 0 ? bpm < MetronomeService.maxBpm : bpm > MetronomeService.minBpm)
                          ? () => service.setBpm(bpm + step)
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(step > 0 ? '+$step' : '−${step.abs()}'),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: bpm.toDouble(),
            min: MetronomeService.minBpm.toDouble(),
            max: MetronomeService.maxBpm.toDouble(),
            divisions: MetronomeService.maxBpm - MetronomeService.minBpm,
            label: '$bpm',
            semanticFormatterCallback: (v) => '${v.round()} beats per minute',
            onChanged: (v) => service.setBpm(v.round()),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${MetronomeService.minBpm}', style: AppText.caption),
                Text('${MetronomeService.maxBpm}', style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBpm(BuildContext context) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _BpmDialog(initial: service.bpm),
    );
    if (value != null) service.setBpm(value);
  }
}

class _BpmDialog extends StatefulWidget {
  const _BpmDialog({required this.initial});

  final int initial;

  @override
  State<_BpmDialog> createState() => _BpmDialogState();
}

class _BpmDialogState extends State<_BpmDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initial}');
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < MetronomeService.minBpm || value > MetronomeService.maxBpm) {
      setState(() {
        _error = 'Enter a number from ${MetronomeService.minBpm} to ${MetronomeService.maxBpm}';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: const Text('Set tempo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(suffixText: 'BPM', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Set')),
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
            'BPM counts every click; the first click of each measure is higher.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.service});

  final MetronomeService service;

  @override
  Widget build(BuildContext context) {
    final status = service.status;
    final String label;
    final IconData icon;
    final VoidCallback action;
    switch (status) {
      case MetronomeStatus.stopped:
        label = 'Start';
        icon = Icons.play_arrow_rounded;
        action = service.start;
      case MetronomeStatus.running:
        label = 'Pause';
        icon = Icons.pause_rounded;
        action = service.pause;
      case MetronomeStatus.paused:
        label = 'Resume';
        icon = Icons.play_arrow_rounded;
        action = service.resume;
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: action,
            icon: Icon(icon, size: 28),
            label: Text(label),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: service.reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}
