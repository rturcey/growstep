import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'garden/garden_database.dart';
import 'garden/garden_game.dart';
import 'garden/garden_session.dart';
import 'garden/garden_state.dart' show localDayKey, stepsPerWaterDose;
import 'steps/fake_step_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = GardenDatabase();
  final steps = FakeStepProvider();
  runApp(GrowstepApp(database: database, steps: steps));
}

class GrowstepApp extends StatelessWidget {
  const GrowstepApp({super.key, required this.database, required this.steps});

  final GardenDatabase database;
  final FakeStepProvider steps;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Growstep',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF79B68A),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF10221A),
    ),
    home: GardenPage(database: database, steps: steps),
  );
}

class GardenPage extends StatefulWidget {
  const GardenPage({super.key, required this.database, required this.steps});

  final GardenDatabase database;
  final FakeStepProvider steps;

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> {
  late final GardenSession _garden = GardenSession(
    database: widget.database,
    stepProvider: widget.steps,
  );
  late final GardenGame _game = GardenGame();
  GardenSnapshot? _snapshot;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _perform(_loadGarden);
  }

  Future<GardenSnapshot> _loadGarden() async {
    final saved = await _garden.load();
    if (saved.creditedDay == localDayKey(DateTime.now())) {
      widget.steps.restoreCreditedSteps(saved.creditedStepWaterDoses);
    }
    return _garden.refreshSteps();
  }

  Future<void> _perform(Future<GardenSnapshot> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      _game.snapshot = result;
      setState(() => _snapshot = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Le jardin ne peut pas être chargé. Réessaie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    widget.database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Growstep',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              const Text('Un pas après l’autre, ton jardin prend vie.'),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(height: 300, child: GameWidget(game: _game)),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              if (snapshot == null && _error != null)
                OutlinedButton(
                  onPressed: _busy ? null : () => _perform(_loadGarden),
                  child: const Text('Réessayer'),
                )
              else if (snapshot == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        title: 'Eau disponible',
                        value: '${snapshot.waterDoses}',
                        icon: Icons.water_drop_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        title: 'Pas simulés',
                        value: '${widget.steps.currentSteps}',
                        icon: Icons.directions_walk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  snapshot.plantStage == null
                      ? 'La parcelle attend sa première graine.'
                      : snapshot.plantStage == PlantStage.pousse
                      ? 'Tournesol · pousse · ${snapshot.waterProgress}/3 doses'
                      : 'Tournesol · jeune plante',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (snapshot.plantStage == null)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _perform(_garden.plantSeed),
                    icon: const Icon(Icons.spa_outlined),
                    label: const Text('Semer un tournesol'),
                  ),
                if (snapshot.plantStage == PlantStage.pousse)
                  FilledButton.icon(
                    onPressed: _busy || snapshot.waterDoses == 0
                        ? null
                        : () => _perform(_garden.waterPlant),
                    icon: const Icon(Icons.water_drop),
                    label: const Text('Arroser la pousse'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          widget.steps.addSteps(stepsPerWaterDose);
                          _perform(_garden.refreshSteps);
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter $stepsPerWaterDose pas simulés'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cette première tranche utilise des pas simulés. Les vrais pas arriveront avec le fournisseur iOS.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1B3526),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF9AD6A2)),
        const SizedBox(height: 10),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
