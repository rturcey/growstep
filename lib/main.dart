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
  const GrowstepApp({
    super.key,
    required this.database,
    required this.steps,
    this.initialZone = ZoneType.potager,
  });

  final GardenDatabase database;
  final FakeStepProvider steps;
  final ZoneType initialZone;

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
    ),
  );
}

class GardenPage extends StatefulWidget {
  const GardenPage({
    super.key,
    required this.database,
    required this.steps,
    this.initialZone = ZoneType.potager,
  });

  final GardenDatabase database;
  final FakeStepProvider steps;
  final ZoneType initialZone;

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
  late ZoneType _selectedZone = widget.initialZone;
  int? _selectedSlot;
  bool _showTouchTargets = false;
  final _scrollController = ScrollController();
  final _zoneKeys = {for (final zone in ZoneType.values) zone: GlobalKey()};

  void _openCurrentZone() {
    final target = _zoneKeys[_selectedZone]!.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
    }
  }

  void _tapGarden(TapDownDetails details) {
    final slot = _game.hitTestSlot(details.localPosition);
    setState(() {
      _selectedSlot = slot;
      _game.selectedSlot = slot;
    });
  }

  void _onZoneSelected(ZoneType zone, GardenSnapshot snapshot) {
    if (snapshot.ownedZones.contains(zone)) {
      setState(() {
        _selectedZone = zone;
        _selectedSlot = null;
        _game.moveTo(zone);
      });
    } else {
      _showPurchaseDialog(zone, snapshot);
    }
  }

  void _showPurchaseDialog(ZoneType zone, GardenSnapshot snapshot) {
    final species = Species.values
        .where((species) => species.zone == zone)
        .map((species) => species.label)
        .join(', ');
    final canAfford = snapshot.florins >= zone.purchasePrice;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Acheter ${zone.label} ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prix : ${zone.purchasePrice} florins'),
            Text('Espèces : $species'),
            Text('${zone.initialSlots} emplacements initiaux'),
            const SizedBox(height: 8),
            Text(
              canAfford
                  ? 'Il vous reste ${snapshot.florins - zone.purchasePrice} florins après l’achat.'
                  : 'Solde insuffisant : ${snapshot.florins} florins disponibles.',
              style: TextStyle(
                color: canAfford
                    ? const Color(0xFF52764F)
                    : Colors.orangeAccent,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: canAfford && !_busy
                ? () {
                    Navigator.pop(dialogContext);
                    _perform(() => _garden.buyIsland(zone));
                  }
                : null,
            child: const Text('Acheter'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _game.moveTo(widget.initialZone);
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
    _scrollController.dispose();
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
    final worldHeight = (MediaQuery.sizeOf(context).height - 274.0).clamp(
      430.0,
      570.0,
    );
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCF5),
            border: Border(top: BorderSide(color: Color(0xFFE9E7DB))),
          ),
          child: Row(
            children: [
              for (final zone in GardenGame.zonesInViewOrder)
                Expanded(
                  child: TextButton(
                    onPressed: snapshot != null
                        ? () => _onZoneSelected(zone, snapshot)
                        : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          switch (zone) {
                            ZoneType.jardinFleuri =>
                              Icons.local_florist_outlined,
                            ZoneType.potager => Icons.spa_outlined,
                            ZoneType.verger => Icons.park_outlined,
                          },
                          size: 22,
                          color: zone == _selectedZone
                              ? const Color(0xFF52764F)
                              : const Color(0xFF8A9585),
                        ),
                        Text(
                          zone.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: zone == _selectedZone
                                ? const Color(0xFF385A3C)
                                : const Color(0xFF777E71),
                          ),
                        ),
                        if (snapshot != null &&
                            !snapshot.ownedZones.contains(zone))
                          Text(
                            '${zone.purchasePrice} florins',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF8A9585),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Growstep',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: const Color(0xFF63845B),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            _selectedZone.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2F4633),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F0E1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_walk, size: 18),
                          const SizedBox(width: 4),
                          Text('${widget.steps.currentSteps} pas'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  key: const Key('garden-viewport'),
                  height: worldHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: _tapGarden,
                          child: GameWidget(game: _game),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF5),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedSlot == null
                                  ? 'Votre ${_selectedZone.label.toLowerCase()}'
                                  : 'Emplacement ${_selectedSlot! + 1}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _selectedSlot == null
                                  ? 'Touchez une parcelle pour commencer'
                                  : 'Gérez vos plantes et vos graines',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: snapshot == null ? null : _openCurrentZone,
                        child: const Text('Gérer'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                for (final zone in ZoneType.values)
                  KeyedSubtree(
                    key: _zoneKeys[zone],
                    child: _zoneCard(snapshot, zone),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Cette tranche utilise des pas simulés. La lecture des pas iPhone arrivera ensuite.',
                ),
                ExpansionTile(
                  title: const Text('Outils de contrôle visuel'),
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text('Afficher les cibles tactiles'),
                      value: _showTouchTargets,
                      onChanged: (value) => setState(() {
                        _showTouchTargets = value;
                        _game.showTouchTargets = value;
                      }),
                    ),
                  ],
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
