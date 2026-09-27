import 'dart:async';

import 'package:flutter/material.dart';

import '../garden/garden_session.dart';

/// Onglet Pauses : lancement et suivi d'une pause marche, compteur de
/// récompenses du jour, indicateur d'inactivité et réglage des heures
/// d'invitation.
class PausesTab extends StatefulWidget {
  const PausesTab({
    super.key,
    required this.garden,
    required this.snapshot,
    required this.now,
    required this.onChanged,
  });

  final GardenSession garden;
  final GardenSnapshot snapshot;
  final DateTime Function() now;
  final ValueChanged<GardenSnapshot> onChanged;

  @override
  State<PausesTab> createState() => _PausesTabState();
}

class _PausesTabState extends State<PausesTab> {
  Timer? _timer;
  int? _pauseSteps;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _refreshPauseSteps();
  }

  @override
  void didUpdateWidget(PausesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPause = oldWidget.snapshot.activePause;
    final newPause = widget.snapshot.activePause;
    if (oldPause?.startTime != newPause?.startTime ||
        oldPause?.rewarded != newPause?.rewarded) {
      _pauseSteps = null;
      _refreshPauseSteps();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    await _refreshPauseSteps();
    if (mounted) setState(() {});
  }

  Future<void> _refreshPauseSteps() async {
    final pause = widget.snapshot.activePause;
    if (pause == null || pause.rewarded) {
      if (_pauseSteps != null) setState(() => _pauseSteps = null);
      return;
    }
    final steps = await widget.garden.stepProvider.stepsBetween(
      pause.startTime,
      pause.deadline,
    );
    if (mounted) setState(() => _pauseSteps = steps);
  }

  Future<void> _perform(Future<GardenSnapshot> Function() action) async {
    try {
      final result = await action();
      widget.onChanged(result);
      _refreshPauseSteps();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cette action est impossible pour le moment.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pause marche',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (snapshot.activePause == null)
            _startPauseCard(context)
          else
            _activePauseCard(context),
          const SizedBox(height: 12),
          _rewardCounterCard(context),
          const SizedBox(height: 12),
          _inactivityCard(context),
          const SizedBox(height: 12),
          _invitationHoursCard(context),
        ],
      ),
    );
  }

  Widget _startPauseCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commencer une pause',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Objectif : ${widget.garden.pauseObjective} pas en '
              '${widget.garden.pauseDurationMinutes} minutes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _perform(widget.garden.startPause),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Commencer une pause'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activePauseCard(BuildContext context) {
    final pause = widget.snapshot.activePause!;
    final steps = _pauseSteps ?? 0;
    final progress = (steps / pause.objective).clamp(0.0, 1.0);
    final remaining = pause.deadline.difference(widget.now());
    final remainingLabel = remaining.isNegative
        ? 'Temps écoulé'
        : _formatDuration(remaining);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pause en cours',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('$steps / ${pause.objective} pas'),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text('Temps restant : $remainingLabel'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _perform(widget.garden.cancelPause),
              icon: const Icon(Icons.stop),
              label: const Text('Abandonner'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardCounterCard(BuildContext context) {
    final count = widget.snapshot.pauseRewardsCount;
    final max = widget.garden.maxPauseRewardsPerDay;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.spa_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Récompenses du jour : $count/$max engrais basiques.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inactivityCard(BuildContext context) {
    final lastActivity = widget.snapshot.lastActivityTime;
    final label = lastActivity == null
        ? 'Aucune marche enregistrée pour le moment.'
        : 'Dernière activité : il y a ${widget.now().difference(DateTime.parse(lastActivity)).inMinutes} minutes';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.directions_walk_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }

  Widget _invitationHoursCard(BuildContext context) {
    final hours = widget.snapshot.invitationHours;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heures d’invitation',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (hours.isEmpty)
              Text(
                'Aucune invitation programmée.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hour in hours)
                    InputChip(
                      label: Text(_formatHour(hour)),
                      onDeleted: () => _perform(
                        () => widget.garden.setInvitationHours(
                          hours.where((h) => h != hour).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            _HourAdder(
              existing: hours.toSet(),
              onAdd: (hour) => _perform(
                () => widget.garden.setInvitationHours([...hours, hour]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes min $seconds s';
  }
}

class _HourAdder extends StatefulWidget {
  const _HourAdder({required this.existing, required this.onAdd});

  final Set<int> existing;
  final ValueChanged<int> onAdd;

  @override
  State<_HourAdder> createState() => _HourAdderState();
}

class _HourAdderState extends State<_HourAdder> {
  int _hour = 8;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: const Key('invitation-hour'),
            initialValue: _hour,
            decoration: const InputDecoration(
              labelText: 'Heure',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var hour = 0; hour < 24; hour++)
                DropdownMenuItem(
                  value: hour,
                  child: Text(_formatHourLabel(hour)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _hour = value);
            },
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: widget.existing.contains(_hour)
              ? null
              : () => widget.onAdd(_hour),
          child: const Text('Ajouter une heure'),
        ),
      ],
    );
  }

  String _formatHourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';
}
