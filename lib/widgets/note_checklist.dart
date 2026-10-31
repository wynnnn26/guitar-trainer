import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/music_theory.dart';

/// Visual checklist of the 12 chromatic notes.
class NoteChecklist extends StatelessWidget {
  const NoteChecklist({
    super.key,
    required this.isCompleted,
    this.currentPitchClass,
  });

  final bool Function(int pitchClass) isCompleted;

  /// The note currently being searched for (outlined), if any.
  final int? currentPitchClass;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var pc = 0; pc < 12; pc++)
          _NoteChip(
            label: MusicTheory.chromaticLabels[pc],
            done: isCompleted(pc),
            current: pc == currentPitchClass,
          ),
      ],
    );
  }
}

class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.label, required this.done, required this.current});

  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final borderColor = done
        ? AppColors.good
        : current
            ? AppColors.accent
            : AppColors.outline;
    return Semantics(
      label: '$label ${done ? 'completed' : current ? 'current' : 'not completed'}',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: done ? AppColors.good.withAlpha(36) : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: current ? 2 : 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (done) ...[
                const Icon(Icons.check, size: 16, color: AppColors.good),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: done
                      ? AppColors.good
                      : current
                          ? AppColors.accent
                          : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
