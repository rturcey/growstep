import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'garden_state.dart';

part 'garden_database.g.dart';

class GardenRecords extends Table {
  IntColumn get id => integer()();
  TextColumn get plantStage => text().nullable()();
  IntColumn get waterDoses => integer()();
  IntColumn get waterProgress => integer()();
  IntColumn get creditedWaterUnits => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [GardenRecords])
class GardenDatabase extends _$GardenDatabase implements GardenStore {
  GardenDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'growstep'));

  @override
  int get schemaVersion => 1;

  @override
  Future<GardenSnapshot> load() async {
    final row = await (select(
      gardenRecords,
    )..where((record) => record.id.equals(1))).getSingleOrNull();
    if (row == null) return GardenSnapshot.empty;
    return GardenSnapshot(
      plantStage: row.plantStage == null
          ? null
          : PlantStage.values.byName(row.plantStage!),
      waterDoses: row.waterDoses,
      waterProgress: row.waterProgress,
      creditedWaterUnits: row.creditedWaterUnits,
    );
  }

  @override
  Future<void> save(GardenSnapshot snapshot) async {
    await into(gardenRecords).insertOnConflictUpdate(
      GardenRecordsCompanion.insert(
        id: const Value(1),
        plantStage: Value(snapshot.plantStage?.name),
        waterDoses: snapshot.waterDoses,
        waterProgress: snapshot.waterProgress,
        creditedWaterUnits: snapshot.creditedWaterUnits,
      ),
    );
  }
}
