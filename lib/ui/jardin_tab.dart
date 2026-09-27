import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../garden/garden_game.dart';
import '../garden/garden_session.dart';
import '../garden/garden_state.dart' show brilliantSeedChance;

/// Onglet Jardin : segmented control des zones, viewport Flame, gestion des
/// emplacements (planter, engrais, récolter, supprimer) et récolte groupée.
///
/// Aucune logique métier ici : toutes les mutations passent par [garden] et
/// remontent à la page via [onChanged].
class JardinTab extends StatefulWidget {
  const JardinTab({
    super.key,
    required this.garden,
    required this.snapshot,
    required this.onChanged,
    this.initialZone = ZoneType.potager,
  });

  final GardenSession garden;
  final GardenSnapshot snapshot;
  final ValueChanged<GardenSnapshot> onChanged;
  final ZoneType initialZone;

  @override
  State<JardinTab> createState() => _JardinTabState();
}

class _JardinTabState extends State<JardinTab> {
  late final GardenGame _game = GardenGame();
  late ZoneType _selectedZone = widget.initialZone;
  int? _selectedSlot;
  bool _showTouchTargets = false;
  final _scrollController = ScrollController();
  final _zoneKeys = {for (final zone in ZoneType.values) zone: GlobalKey()};

  static const _zoneOrder = [
    ZoneType.potager,
    ZoneType.jardinFleuri,
    ZoneType.verger,
  ];

  @override
  void initState() {
    super.initState();
    _game.moveTo(_selectedZone);
    _game.snapshot = widget.snapshot;
  }

  @override
  void didUpdateWidget(JardinTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      _game.snapshot = widget.snapshot;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<GardenSnapshot> Function() action) async {
    try {
      final result = await action();
      widget.onChanged(result);
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

  void _tapGarden(TapDownDetails details) {
    final slot = _game.hitTestSlot(details.localPosition);
    setState(() {
      _selectedSlot = slot;
      _game.selectedSlot = slot;
    });
  }

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
            onPressed: canAfford
                ? () {
                    Navigator.pop(dialogContext);
                    _perform(() => widget.garden.buyIsland(zone));
                  }
                : null,
            child: const Text('Acheter'),
          ),
        ],
      ),
    );
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
      await _perform(() => widget.garden.removePlant(zone, slot));
    }
  }

  Future<void> _confirmGroupHarvest() async {
    final preview = widget.garden.previewReadyHarvests();
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
      await _perform(() => widget.garden.harvestAll(preview.locations));
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
    final snapshot = widget.snapshot;
    return LayoutBuilder(
      builder: (context, constraints) {
        final worldHeight = (constraints.maxHeight - 76.0).clamp(
          430.0,
          570.0,
        );
        return _buildScrollView(snapshot, worldHeight);
      },
    );
  }

  Widget _buildScrollView(GardenSnapshot snapshot, double worldHeight) {
    final readyHarvests = widget.garden.previewReadyHarvests().count;
    final fertilizerStock = FertilizerType.values
        .where((type) => (snapshot.fertilizers[type] ?? 0) > 0)
        .map((type) => '${type.label} ×${snapshot.fertilizers[type]}')
        .join(', ');
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ZoneSelector(
              snapshot: snapshot,
              selectedZone: _selectedZone,
              onSelected: (zone) => _onZoneSelected(zone, snapshot),
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
                    onPressed: _openCurrentZone,
                    child: const Text('Gérer'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Florins : ${snapshot.florins}'),
                  Text(
                    'Récoltes aujourd’hui : ${widget.garden.harvestFlorinsToday}/${widget.garden.harvestFlorinLimit} florins',
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
              onPressed: _confirmGroupHarvest,
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
            Text(
              '${zone.label} · ${snapshot.zones[zone]!.length}/${zone.maxSlots} emplacements',
              style: Theme.of(context).textTheme.titleLarge,
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
                      onPressed: () => _perform(
                        () => widget.garden.chooseStarterSeed(species),
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
                      onPressed: () => _perform(
                        () => widget.garden.plantSeed(zone, slot, species),
                      ),
                    ),
                  for (final species in brilliantAvailable)
                    ActionChip(
                      label: Text('Planter ${species.label} brillante'),
                      onPressed: () => _perform(
                        () => widget.garden.plantSeed(
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
                      onPressed: () => _perform(
                        () => widget.garden.applyFertilizer(zone, slot, type),
                      ),
                    ),
              ],
            ),
          if (plant.isReadyToHarvest)
            TextButton.icon(
              onPressed: () => _perform(
                () => widget.garden.harvestPlant(zone, slot),
              ),
              icon: const Icon(Icons.spa),
              label: const Text('Récolter'),
            ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Supprimer ${plant.species.label}',
        onPressed: () => _confirmRemoval(zone, slot),
        icon: const Icon(Icons.close),
      ),
    );
  }
}

class _ZoneSelector extends StatelessWidget {
  const _ZoneSelector({
    required this.snapshot,
    required this.selectedZone,
    required this.onSelected,
  });

  final GardenSnapshot snapshot;
  final ZoneType selectedZone;
  final ValueChanged<ZoneType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final zone in _JardinTabState._zoneOrder)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _zoneSegment(
                context,
                zone,
                owned: snapshot.ownedZones.contains(zone),
                selected: zone == selectedZone,
              ),
            ),
          ),
      ],
    );
  }

  Widget _zoneSegment(
    BuildContext context,
    ZoneType zone, {
    required bool owned,
    required bool selected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : const Color(0xFFFFFCF5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? colorScheme.primary
              : const Color(0xFFE9E7DB),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onSelected(zone),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            children: [
              Text(
                zone.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : const Color(0xFF385A3C),
                ),
              ),
              if (!owned)
                Text(
                  '${zone.purchasePrice} florins',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8A9585),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
