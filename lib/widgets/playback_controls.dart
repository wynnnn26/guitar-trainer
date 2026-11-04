import 'package:flutter/material.dart';

import '../services/metronome_service.dart';

/// Start / Pause / Resume + Reset row. Shared by the Basic and Advanced
/// metronome panels.
class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key, required this.service});

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
