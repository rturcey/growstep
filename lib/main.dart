import 'dart:async';

import 'package:flutter/material.dart';

import 'garden/garden_database.dart';
import 'garden/garden_session.dart';
import 'garden/garden_state.dart' show localDayKey;
import 'steps/fake_step_provider.dart';
import 'steps/step_provider.dart';
import 'ui/boutique_tab.dart';
import 'ui/jardin_tab.dart';
import 'ui/pauses_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = GardenDatabase();
  final steps = FakeStepProvider();
  runApp(GrowstepApp(database: database, steps: steps));
}

class GrowstepApp extends StatelessWidget {
  const GrowstepApp({
    super.key,
    required this.database,
    required this.steps,
    this.initialZone = ZoneType.potager,
    this.now,
    this.checkInterval = const Duration(seconds: 60),
  });

  final GardenDatabase database;
  final StepProvider steps;
  final ZoneType initialZone;
  final DateTime Function()? now;
  final Duration checkInterval;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Growstep',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF63845B),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFBF8F0),
    ),
    home: GardenPage(
      database: database,
      steps: steps,
      initialZone: initialZone,
      now: now,
      checkInterval: checkInterval,
    ),
  );
}

class GardenPage extends StatefulWidget {
  const GardenPage({
    super.key,
    required this.database,
    required this.steps,
    this.initialZone = ZoneType.potager,
    this.now,
    this.checkInterval = const Duration(seconds: 60),
  });

  final GardenDatabase database;
  final StepProvider steps;
  final ZoneType initialZone;
  final DateTime Function()? now;
  final Duration checkInterval;

  @override
  State<GardenPage> createState() => _GardenPageState();
}

enum _InactivityStage { none, propose, remind }

class _GardenPageState extends State<GardenPage> {
  late final GardenSession _garden = GardenSession(
    database: widget.database,
    stepProvider: widget.steps,
    now: widget.now,
  );
  GardenSnapshot? _snapshot;
  String? _error;
  int _selectedTab = 0;
  Timer? _timer;
  _InactivityStage _inactivityStage = _InactivityStage.none;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.checkInterval, (_) => _periodicCheck());
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.database.close();
    super.dispose();
  }

  DateTime _now() => widget.now != null ? widget.now!() : DateTime.now();

  Future<void> _load() async {
    try {
      final saved = await _garden.load();
      if (saved.creditedDay == localDayKey(_now())) {
        final steps = widget.steps;
        if (steps is FakeStepProvider) {
          steps.restoreCreditedSteps(saved.creditedSteps);
        }
      }
      final result = await _garden.refreshSteps();
      if (!mounted) return;
      setState(() {
        _snapshot = result;
        _error = null;
      });
      _periodicCheck();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Le jardin ne peut pas être chargé. Réessaie.');
    }
  }

  void _onChanged(GardenSnapshot snapshot) {
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  void _refresh() {
    _garden.refreshSteps().then((result) {
      if (mounted) setState(() => _snapshot = result);
    });
  }

  void _addDevSteps() {
    if (widget.steps is! FakeStepProvider) return;
    (widget.steps as FakeStepProvider).addSteps(100);
    _refresh();
  }

  void _periodicCheck() {
    _garden.evaluateInactivity();
    _checkPauseCompletion();
    _evaluateInactivityOverlay();
  }

  Future<void> _checkPauseCompletion() async {
    final snapshot = _garden.snapshot;
    final pause = snapshot.activePause;
    if (pause == null || pause.rewarded) return;
    final beforeCount = snapshot.pauseRewardsCount;
    try {
      final result = await _garden.checkActivePause();
      final after = result.activePause;
      if (after != null &&
          after.rewarded &&
          result.pauseRewardsCount > beforeCount) {
        _showMessage('Engrais basique gagné !');
      }
      if (mounted) setState(() => _snapshot = result);
    } catch (_) {
      // A periodic check must never crash the app.
    }
  }

  void _evaluateInactivityOverlay() {
    final lastActivity = _garden.snapshot.lastActivityTime;
    var stage = _InactivityStage.none;
    if (lastActivity != null) {
      final minutes =
          _now().difference(DateTime.parse(lastActivity)).inMinutes;
      if (minutes >= _garden.inactivityReminderMinutes) {
        stage = _InactivityStage.remind;
      } else if (minutes >= _garden.inactivityProposeMinutes) {
        stage = _InactivityStage.propose;
      }
    }
    if (stage == _inactivityStage) return;
    _inactivityStage = stage;
    if (!mounted || stage == _InactivityStage.none) return;
    switch (stage) {
      case _InactivityStage.propose:
        _showMessage(
          'Une marche est proposée pour garder ton jardin en forme.',
          actionLabel: 'Marcher',
          onAction: () => setState(() => _selectedTab = 2),
        );
      case _InactivityStage.remind:
        _showMessage(
          'Rappel : une marche de 10 minutes ferait du bien à ton jardin.',
        );
      case _InactivityStage.none:
        break;
    }
  }

  void _showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel != null
              ? SnackBarAction(label: actionLabel, onPressed: onAction ?? () {})
              : null,
        ),
      );
  }

  bool get _showStepCounter => _selectedTab != 1;

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final isDev = widget.steps is FakeStepProvider;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(snapshot),
            Expanded(
              child: snapshot == null
                  ? (_error != null ? _buildError() : const _LoadingView())
                  : IndexedStack(
                      index: _selectedTab,
                      children: [
                        JardinTab(
                          garden: _garden,
                          snapshot: snapshot,
                          initialZone: widget.initialZone,
                          onChanged: _onChanged,
                        ),
                        BoutiqueTab(
                          garden: _garden,
                          snapshot: snapshot,
                          now: _now,
                          onChanged: _onChanged,
                        ),
                        PausesTab(
                          garden: _garden,
                          snapshot: snapshot,
                          now: _now,
                          onChanged: _onChanged,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDev) _buildDevPanel(snapshot),
          NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) {
              setState(() => _selectedTab = index);
              _periodicCheck();
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.spa_outlined),
                selectedIcon: Icon(Icons.spa),
                label: 'Jardin',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Boutique',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_walk),
                label: 'Pauses',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(GardenSnapshot? snapshot) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Growstep',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    color: const Color(0xFF63845B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (_showStepCounter) ...[
            _HeaderChip(
              icon: Icons.directions_walk,
              label: '${snapshot?.creditedSteps ?? 0} pas',
            ),
            const SizedBox(width: 8),
          ],
          _HeaderChip(
            icon: Icons.monetization_on_outlined,
            label: '${snapshot?.florins ?? 0} florins',
          ),
        ],
      ),
    );
  }

  Widget _buildDevPanel(GardenSnapshot? snapshot) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFFCF5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Pas simulés',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A9585)),
            ),
          ),
          FilledButton.tonal(
            onPressed: snapshot == null ? null : _addDevSteps,
            child: const Text('+100'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _load(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F0E1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
