import 'dart:async';

import 'package:flutter/material.dart';

import '../models/tuner_models.dart';
import '../platform/platform_services.dart';
import '../services/metronome_service.dart';
import '../services/note_trainer_service.dart';
import '../services/tuner_service.dart';
import '../theme/app_theme.dart';
import 'metronome_screen.dart';
import 'note_trainer_screen.dart';
import 'tuner_screen.dart';

/// Hosts the three sections and owns their services.
///
/// Layout adapts to the window: a bottom navigation bar on phones and narrow
/// browser windows, a side navigation rail on tablets / desktop browsers.
///
/// Leaving a section pauses it (metronome, trainer) or switches the
/// microphone off (tuner); the same happens when the app goes to the
/// background or the browser tab is hidden. Nothing keeps running unnoticed.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.metronomeService,
    this.trainerService,
    this.tunerService,
  });

  /// Optional overrides, mainly for tests.
  final MetronomeService? metronomeService;
  final NoteTrainerService? trainerService;
  final TunerService? tunerService;

  /// Width from which the side navigation rail replaces the bottom bar.
  static const double wideLayoutBreakpoint = 840;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Section {
  const _Section(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const int _metronomeTab = 0;
  static const int _trainerTab = 1;
  static const int _tunerTab = 2;

  static const List<_Section> _sections = [
    _Section('Metronome', Icons.speed_outlined, Icons.speed),
    _Section('Note Trainer', Icons.school_outlined, Icons.school),
    _Section('Tuner', Icons.mic_none, Icons.mic),
  ];

  late final MetronomeService _metronome;
  late final NoteTrainerService _trainer;
  late final TunerService _tuner;
  int _index = _metronomeTab;

  /// Keeps the screens' state when the layout switches between bar and rail.
  final GlobalKey _bodyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _metronome = widget.metronomeService ?? MetronomeService(clickPlayer: createClickPlayer());
    _trainer = widget.trainerService ?? NoteTrainerService();
    _tuner = widget.tunerService ??
        TunerService(
          microphone: createMicrophoneService(),
          permission: createMicPermissionService(),
        );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_metronome.init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metronome.dispose();
    _trainer.dispose();
    _tuner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` also fires for system dialogs (e.g. the microphone permission
    // prompt), so only react once the app is really leaving the foreground
    // (or the browser tab became hidden).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _suspend(_metronomeTab);
      _suspend(_trainerTab);
      _suspend(_tunerTab);
    }
  }

  /// Pauses / stops whatever a section is doing.
  void _suspend(int tab) {
    switch (tab) {
      case _metronomeTab:
        _metronome.pauseIfRunning();
      case _trainerTab:
        _trainer.pauseIfRunning();
      case _tunerTab:
        if (_tuner.status != TunerStatus.idle) unawaited(_tuner.stop());
    }
  }

  void _onDestinationSelected(int index) {
    if (index == _index) return;
    _suspend(_index); // Leaving this section.
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      key: _bodyKey,
      index: _index,
      children: [
        MetronomeScreen(service: _metronome),
        NoteTrainerScreen(service: _trainer),
        TunerScreen(service: _tuner),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= HomeShell.wideLayoutBreakpoint) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _onDestinationSelected,
                    backgroundColor: AppColors.surface,
                    indicatorColor: AppColors.accent.withAlpha(70),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final section in _sections)
                        NavigationRailDestination(
                          icon: Icon(section.icon),
                          selectedIcon: Icon(section.selectedIcon),
                          label: Text(section.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.outline),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.accent.withAlpha(70),
            destinations: [
              for (final section in _sections)
                NavigationDestination(
                  icon: Icon(section.icon),
                  selectedIcon: Icon(section.selectedIcon),
                  label: section.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
