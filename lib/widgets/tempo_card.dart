import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/metronome_service.dart';
import '../theme/app_theme.dart';
import '../utils/music_theory.dart';
import 'app_card.dart';

/// Big BPM display with step buttons, slider and direct input.
/// Shared by the Basic and Advanced metronome panels.
class TempoCard extends StatelessWidget {
  const TempoCard({super.key, required this.service});

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
      builder: (_) => BpmDialog(initial: service.bpm),
    );
    if (value != null) service.setBpm(value);
  }
}

/// Direct BPM entry (30-300). Used from [TempoCard]'s tap-to-type affordance.
class BpmDialog extends StatefulWidget {
  const BpmDialog({super.key, required this.initial});

  final int initial;

  @override
  State<BpmDialog> createState() => _BpmDialogState();
}

class _BpmDialogState extends State<BpmDialog> {
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
