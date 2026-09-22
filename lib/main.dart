import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'garden/garden_database.dart';
import 'garden/garden_game.dart';
import 'garden/garden_session.dart';
import 'garden/garden_state.dart' show brilliantSeedChance, localDayKey;
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
      widget.steps.restoreCreditedSteps(saved.creditedSteps);
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

  Future<void> _confirmRemoval(ZoneType zone, int slot) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette plante ?'),
        content: const Text('La graine utilisée ne sera pas rendue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (remove == true) {
      await _perform(() => _garden.removePlant(zone, slot));
    }
  }

  Future<void> _confirmGroupHarvest() async {
    final preview = _garden.previewReadyHarvests();
    if (preview.count < 2) return;
    final ordinary = _formatSeeds(preview.ordinarySeeds);
    final brilliant = _formatSeeds(preview.brilliantSeeds, brilliant: true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Récolter ${preview.count} plantes ?'),
        content: Text(
          'Gain confirmé : +${preview.florins} florins\n'
          'Graines ordinaires : $ordinary'
          '${brilliant.isEmpty ? '' : '\nGraines brillantes : $brilliant'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer la récolte'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _perform(() => _garden.harvestAll(preview.locations));
    }
  }

  String _formatSeeds(
    Map<Species, int> seeds, {
    bool brilliant = false,
  }) => seeds.entries
      .where((entry) => entry.value > 0)
      .map(
        (entry) =>
            '${entry.key.label}${brilliant ? ' brillante' : ''} ×${entry.value}',
      )
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final readyHarvests = snapshot == null
        ? 0
        : _garden.previewReadyHarvests().count;
    final fertilizerStock = snapshot == null
        ? ''
        : FertilizerType.values
              .where((type) => (snapshot.fertilizers[type] ?? 0) > 0)
              .map((type) => '${type.label} ×${snapshot.fertilizers[type]}')
              .join(', ');
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
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(height: 230, child: GameWidget(game: _game)),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_walk),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${widget.steps.currentSteps} pas simulés aujourd’hui',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  widget.steps.addSteps(100);
                                  _perform(_garden.refreshSteps);
                                },
                          child: const Text('+100'),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Florins : ${snapshot.florins}'),
                        Text(
                          'Récoltes aujourd’hui : ${_garden.harvestFlorinsToday}/${_garden.harvestFlorinLimit} florins',
                        ),
                        Text(
                          'Engrais en stock : ${fertilizerStock.isEmpty ? 'aucun' : fertilizerStock}',
                        ),
                      ],
                    ),
                  ),
                ),
                if (readyHarvests > 1) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _confirmGroupHarvest,
                    icon: const Icon(Icons.grass),
                    label: Text('Récolter $readyHarvests plantes'),
                  ),
                ],
                if (snapshot.needsFirstPlanting) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Choisis une graine offerte, puis plante-la dans un emplacement.',
                  ),
                ],
                for (final zone in ZoneType.values) _zoneCard(snapshot, zone),
                const SizedBox(height: 12),
                const Text(
                  'Cette tranche utilise des pas simulés. La lecture des pas iPhone arrivera ensuite.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneCard(GardenSnapshot snapshot, ZoneType zone) {
    final zoneSpecies = Species.values.where((species) => species.zone == zone);
    final inventory = [
      _formatSeeds({
        for (final species in zoneSpecies)
          if ((snapshot.seeds[species] ?? 0) > 0)
            species: snapshot.seeds[species]!,
      }),
      _formatSeeds({
        for (final species in zoneSpecies)
          if ((snapshot.brilliantSeeds[species] ?? 0) > 0)
            species: snapshot.brilliantSeeds[species]!,
      }, brilliant: true),
    ].where((label) => label.isNotEmpty).join(', ');
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zone.label, style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${snapshot.zones[zone]!.length}/${zone.maxSlots} emplacements',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (inventory.isNotEmpty) Text('Graines : $inventory'),
            if (!snapshot.starterChoices.contains(zone)) ...[
              const SizedBox(height: 10),
              const Text('Choisis ta graine offerte :'),
              Wrap(
                spacing: 8,
                children: [
                  for (final species in zoneSpecies)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => _garden.chooseStarterSeed(species),
                            ),
                      child: Text(species.label),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            for (var slot = 0; slot < snapshot.zones[zone]!.length; slot++)
              _slotRow(snapshot, zone, slot),
          ],
        ),
      ),
    );
  }

  Widget _slotRow(GardenSnapshot snapshot, ZoneType zone, int slot) {
    final plant = snapshot.zones[zone]![slot];
    if (plant == null) {
      final available = Species.values
          .where(
            (species) =>
                species.zone == zone && (snapshot.seeds[species] ?? 0) > 0,
          )
          .toList();
      final brilliantAvailable = Species.values
          .where(
            (species) =>
                species.zone == zone &&
                (snapshot.brilliantSeeds[species] ?? 0) > 0,
          )
          .toList();
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.add_circle_outline),
        title: Text('Emplacement ${slot + 1} · libre'),
        subtitle: available.isEmpty && brilliantAvailable.isEmpty
            ? const Text('Aucune graine disponible')
            : Wrap(
                spacing: 8,
                children: [
                  for (final species in available)
                    ActionChip(
                      label: Text('Planter ${species.label}'),
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => _garden.plantSeed(zone, slot, species),
                            ),
                    ),
                  for (final species in brilliantAvailable)
                    ActionChip(
                      label: Text('Planter ${species.label} brillante'),
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => _garden.plantSeed(
                                zone,
                                slot,
                                species,
                                brilliant: true,
                              ),
                            ),
                    ),
                ],
              ),
      );
    }

    final stage = switch (plant.stage) {
      PlantStage.graineGermee => 'Graine germée',
      PlantStage.jeunePlant => 'Jeune plant',
      PlantStage.presqueMature => 'Presque mature',
      PlantStage.mature => 'Mature',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${plant.species.label}${plant.tier == GrowthTier.brillante ? ' brillante' : ''} · $stage',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${plant.progressSteps}/${plant.nextThreshold} pas'),
          LinearProgressIndicator(
            value: plant.progressSteps / plant.nextThreshold,
          ),
          Text(
            'Graine ordinaire garantie · bonus ${(plant.tier.extraOrdinarySeedChance * 100).round()} %'
            '${plant.tier == GrowthTier.brillante ? ' · graine brillante ${(brilliantSeedChance * 100).round()} %' : ''}',
          ),
          if (plant.activeFertilizer != null)
            Text(
              'Engrais actif : ${plant.activeFertilizer!.label} ${plant.activeFertilizer!.multiplierLabel}',
            )
          else if (!plant.isReadyToHarvest)
            Wrap(
              spacing: 8,
              children: [
                for (final type in FertilizerType.values)
                  if ((snapshot.fertilizers[type] ?? 0) > 0)
                    ActionChip(
                      label: Text(
                        'Engrais ${type.name} ×${snapshot.fertilizers[type]}',
                      ),
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => _garden.applyFertilizer(zone, slot, type),
                            ),
                    ),
              ],
            ),
          if (plant.isReadyToHarvest)
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _perform(() => _garden.harvestPlant(zone, slot)),
              icon: const Icon(Icons.spa),
              label: const Text('Récolter'),
            ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Supprimer ${plant.species.label}',
        onPressed: _busy ? null : () => _confirmRemoval(zone, slot),
        icon: const Icon(Icons.close),
      ),
    );
  }
}
