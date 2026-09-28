import 'package:flutter/material.dart';

import '../garden/daily_progression.dart' show shinySeedChances;
import '../garden/decoration_catalogue.dart';
import '../garden/garden_session.dart';
import '../garden/local_date.dart';

/// Onglet Boutique & Récompenses : achat de graines, engrais et décors
/// (sans placement), suppression de graines excédentaires, inventaire de
/// décors non placés et paliers quotidiens en lecture seule.
class BoutiqueTab extends StatefulWidget {
  const BoutiqueTab({
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
  State<BoutiqueTab> createState() => _BoutiqueTabState();
}

class _BoutiqueTabState extends State<BoutiqueTab> {
  Species _seedSpecies = Species.tomate;

  Future<void> _buy(Future<GardenSnapshot> Function() action) async {
    try {
      final result = await action();
      widget.onChanged(result);
    } on StateError {
      _message('Pas assez de florins pour cet achat.');
    } catch (_) {
      _message('Cet achat est impossible pour le moment.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final today = LocalDate.fromDateTime(widget.now());
    final lots = widget.garden.previewDailyLots(today);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Boutique & Récompenses',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Le solde de florins s’affiche dans l’en-tête, quel que soit l’onglet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _sectionTitle(context, 'Graines'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choisis une espèce, puis achète une graine supplémentaire.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Species>(
                    key: const Key('seed-species'),
                    initialValue: _seedSpecies,
                    decoration: const InputDecoration(
                      labelText: 'Espèce',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final species in Species.values)
                        if (widget.garden.snapshot.discoveredSpecies.contains(
                          species,
                        ))
                          DropdownMenuItem(
                            value: species,
                            child: Text(species.label),
                          ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _seedSpecies = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  _BuyRow(
                    title: 'Graine ${_seedSpecies.label}',
                    subtitle:
                        '${widget.garden.economyRules.seedPriceForSpecies(_seedSpecies)} florins',
                    buttonLabel: 'Acheter graine ${_seedSpecies.label}',
                    onPressed: () =>
                        _buy(() => widget.garden.buySeed(_seedSpecies)),
                  ),
                ],
              ),
            ),
          ),
          _sectionTitle(context, 'Engrais'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final type in FertilizerType.values)
                    _BuyRow(
                      title: 'Engrais ${type.label}',
                      subtitle:
                          '${widget.garden.economyConfig.fertilizerPrices[type]} florins'
                          ' · en stock : ${snapshot.fertilizers[type] ?? 0}',
                      buttonLabel: 'Acheter engrais ${type.label}',
                      onPressed: () =>
                          _buy(() => widget.garden.buyFertilizer(type)),
                    ),
                ],
              ),
            ),
          ),
          _sectionTitle(context, 'Décors'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Achat depuis le catalogue — placement à venir.'),
                  const SizedBox(height: 4),
                  for (final def in const DecorationCatalogue().all)
                    _BuyRow(
                      title: def.label,
                      subtitle:
                          '${widget.garden.economyConfig.decorationPrices[def.id]} florins'
                          ' · en stock : ${snapshot.ownedDecorations[def.id] ?? 0}',
                      buttonLabel: 'Acheter ${def.label}',
                      onPressed: () =>
                          _buy(() => widget.garden.buyDecoration(def.id)),
                    ),
                ],
              ),
            ),
          ),
          _sectionTitle(context, 'Inventaire de décors'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: snapshot.ownedDecorations.entries.isEmpty
                  ? Text(
                      'Aucun décor non placé.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in snapshot.ownedDecorations.entries)
                          if (entry.value > 0)
                            _inventoryRow(entry.key, entry.value),
                      ],
                    ),
            ),
          ),
          _sectionTitle(context, 'Graines en stock'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshot.seeds.entries.every((e) => e.value <= 0) &&
                      snapshot.brilliantSeeds.entries.every(
                        (e) => e.value <= 0,
                      ))
                    Text(
                      'Aucune graine en stock.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else ...[
                    for (final entry in snapshot.seeds.entries)
                      if (entry.value > 0)
                        _seedStockRow(
                          '${entry.key.label} ×${entry.value}',
                          () => _discardSeeds(entry.key),
                        ),
                    for (final entry in snapshot.brilliantSeeds.entries)
                      if (entry.value > 0)
                        _seedStockRow(
                          '${entry.key.label} brillante ×${entry.value}',
                          () => _discardSeeds(entry.key, brilliant: true),
                        ),
                  ],
                ],
              ),
            ),
          ),
          _sectionTitle(context, 'Récompenses quotidiennes'),
          for (var index = 0; index < lots.length; index++)
            _dailyTierCard(
              context,
              lot: lots[index],
              shinyChance: shinySeedChances[index],
              stepsToday: snapshot.creditedSteps,
            ),
          const SizedBox(height: 8),
          const Text(
            'Le crédit est automatique à la synchro des pas : aucun bouton à réclamer.',
            style: TextStyle(fontSize: 12, color: Color(0xFF777E71)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _inventoryRow(String decorationId, int count) {
    final def = const DecorationCatalogue().find(decorationId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '${def?.label ?? decorationId} ×$count',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _seedStockRow(String label, VoidCallback onDiscard) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        TextButton(onPressed: onDiscard, child: const Text('Supprimer')),
      ],
    );
  }

  Future<void> _discardSeeds(Species species, {bool brilliant = false}) async {
    try {
      final result = await widget.garden.discardSeeds(
        species,
        brilliant: brilliant,
      );
      widget.onChanged(result);
    } catch (_) {
      _message('Impossible de supprimer ces graines.');
    }
  }

  Widget _dailyTierCard(
    BuildContext context, {
    required DailyLot lot,
    required double shinyChance,
    required int stepsToday,
  }) {
    final reached = stepsToday >= lot.threshold;
    final content = _lotDescription(lot);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Palier ${lot.threshold} pas',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  reached ? 'Atteint' : 'Non atteint',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: reached
                        ? const Color(0xFF52764F)
                        : const Color(0xFF8A9585),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Lot : $content'),
            Text(
              'Chance de graine brillante : ${(shinyChance * 100).round()} %',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (stepsToday / lot.threshold).clamp(0.0, 1.0),
            ),
            const SizedBox(height: 4),
            Text(
              '$stepsToday / ${lot.threshold} pas',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _lotDescription(DailyLot lot) {
    final parts = <String>[];
    if (lot.seedSpecies != null) {
      parts.add('1 graine ${lot.seedSpecies!.label}');
    }
    if (lot.fertilizerType != null) {
      parts.add('1 engrais ${lot.fertilizerType!.label}');
    }
    if (lot.decorationId != null) {
      final def = const DecorationCatalogue().find(lot.decorationId!);
      parts.add('1 décor ${def?.label ?? lot.decorationId}');
    }
    if (lot.shinySeedSpecies != null) {
      parts.add('graine brillante ${lot.shinySeedSpecies!.label}');
    }
    return parts.isEmpty ? '—' : parts.join(', ');
  }
}

class _BuyRow extends StatelessWidget {
  const _BuyRow({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
