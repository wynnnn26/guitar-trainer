import 'package:flutter/material.dart';

import '../models/guitar_string.dart';
import '../models/training.dart';
import '../services/note_trainer_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/fretboard.dart';
import '../widgets/note_checklist.dart';
import '../widgets/screen_body.dart';

class NoteTrainerScreen extends StatefulWidget {
  const NoteTrainerScreen({super.key, required this.service});

  final NoteTrainerService service;

  @override
  State<NoteTrainerScreen> createState() => _NoteTrainerScreenState();
}

class _NoteTrainerScreenState extends State<NoteTrainerScreen> {
  /// Whether to mark the answer on the fretboard (off by default, because
  /// showing it defeats the point of memorising).
  bool _showPositions = false;

  NoteTrainerService get service => widget.service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final List<Widget> children;
        switch (service.status) {
          case TrainerStatus.idle:
            children = _idle();
          case TrainerStatus.running:
          case TrainerStatus.paused:
            children = _session();
          case TrainerStatus.completed:
            children = _completed();
        }
        return ScreenBody(
          title: 'Note Trainer',
          subtitle: 'Find all 12 notes on random strings, as fast as you can.',
          children: children,
        );
      },
    );
  }

  // ----------------------------------------------------------------- idle

  List<Widget> _idle() {
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school, color: AppColors.accent),
                SizedBox(width: 10),
                Text(
                  'How it works',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final line in const [
              'You get a note and a string, e.g. "Find C♯ on the 3rd string".',
              'Play it on your guitar, then tap "Found It / Next Note".',
              'Each of the 12 notes comes up once. The clock stops after the last one.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7, right: 10),
                      child: Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
                    ),
                    Expanded(child: Text(line, style: const TextStyle(fontSize: 15, height: 1.4))),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: service.start,
        icon: const Icon(Icons.play_arrow_rounded, size: 28),
        label: const Text('Start Training'),
      ),
    ];
  }

  // -------------------------------------------------------------- session

  List<Widget> _session() {
    final target = service.current;
    final isPaused = service.status == TrainerStatus.paused;
    final isLast = service.completedCount == NoteTrainerService.noteCount - 1;

    return [
      _StopwatchRow(service: service, isPaused: isPaused),
      const SizedBox(height: 12),
      if (target != null) _TargetCard(target: target, isPaused: isPaused),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: isPaused ? null : service.confirmFound,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(isLast ? 'Found It / Finish' : 'Found It / Next Note'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isPaused ? service.resume : service.pause,
              icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              label: Text(isPaused ? 'Resume' : 'Pause'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: service.reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ProgressCard(service: service),
      const SizedBox(height: 16),
      if (target != null)
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Fretboard',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Text('Show answer', style: AppText.caption),
                  const SizedBox(width: 4),
                  Switch(
                    value: _showPositions,
                    onChanged: (value) => setState(() => _showPositions = value),
                  ),
                ],
              ),
              Fretboard(
                strings: GuitarTuning.standard,
                highlightedString: target.string,
                markedPitchClass: _showPositions ? target.pitchClass : null,
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NOTES', style: AppText.overline),
            const SizedBox(height: 12),
            NoteChecklist(
              isCompleted: service.isNoteCompleted,
              currentPitchClass: target?.pitchClass,
            ),
          ],
        ),
      ),
    ];
  }

  // ------------------------------------------------------------ completed

  List<Widget> _completed() {
    final results = service.completed;
    return [
      AppCard(
        borderColor: AppColors.good,
        child: Column(
          children: [
            const Icon(Icons.emoji_events, size: 48, color: AppColors.good),
            const SizedBox(height: 8),
            const Text(
              'All 12 notes found!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const Text('TOTAL TIME', style: AppText.overline),
            const SizedBox(height: 6),
            ValueListenableBuilder<Duration>(
              valueListenable: service.elapsedListenable,
              builder: (context, elapsed, _) => Text(
                formatStopwatch(elapsed),
                style: AppText.display(56, color: AppColors.good),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nice work! Try again and beat your time.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: service.startNewSession,
        icon: const Icon(Icons.replay),
        label: const Text('Start New Session'),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('YOUR RESULTS', style: AppText.overline),
            const SizedBox(height: 12),
            for (final result in results) _ResultRow(result: result),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: NoteChecklist(isCompleted: service.isNoteCompleted),
      ),
    ];
  }
}

class _StopwatchRow extends StatelessWidget {
  const _StopwatchRow({required this.service, required this.isPaused});

  final NoteTrainerService service;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ValueListenableBuilder<Duration>(
          valueListenable: service.elapsedListenable,
          builder: (context, elapsed, _) => Semantics(
            label: 'Elapsed time ${formatStopwatch(elapsed)}',
            child: ExcludeSemantics(
              child: Text(
                formatStopwatch(elapsed),
                style: AppText.display(40, color: isPaused ? AppColors.textSecondary : AppColors.textPrimary),
              ),
            ),
          ),
        ),
        if (isPaused)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'PAUSED',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target, required this.isPaused});

  final TrainingTarget target;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: target.instruction,
      child: ExcludeSemantics(
        child: AppCard(
          borderColor: isPaused ? AppColors.outline : AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Opacity(
            opacity: isPaused ? 0.35 : 1,
            child: Column(
              children: [
                const Text('FIND', style: AppText.overline),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(target.noteLabel, style: AppText.display(84, color: AppColors.accent)),
                ),
                const SizedBox(height: 12),
                Text(
                  'on the ${target.string.ordinal} string (${target.string.noteName})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.service});

  final NoteTrainerService service;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${service.completedCount}/${NoteTrainerService.noteCount} notes completed',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: service.progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.accent,
            backgroundColor: AppColors.outline,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final CompletedTarget result;

  @override
  Widget build(BuildContext context) {
    final target = result.target;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              target.noteLabel,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          Expanded(
            child: Text(
              '${target.string.ordinal} string (${target.string.noteName})',
              style: AppText.caption,
            ),
          ),
          Text(
            formatLap(result.lapTime),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: AppText.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
