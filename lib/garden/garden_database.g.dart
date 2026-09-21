// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'garden_database.dart';

// ignore_for_file: type=lint
class $GardenRecordsTable extends GardenRecords
    with TableInfo<$GardenRecordsTable, GardenRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GardenRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plantStageMeta = const VerificationMeta(
    'plantStage',
  );
  @override
  late final GeneratedColumn<String> plantStage = GeneratedColumn<String>(
    'plant_stage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waterDosesMeta = const VerificationMeta(
    'waterDoses',
  );
  @override
  late final GeneratedColumn<int> waterDoses = GeneratedColumn<int>(
    'water_doses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _waterProgressMeta = const VerificationMeta(
    'waterProgress',
  );
  @override
  late final GeneratedColumn<int> waterProgress = GeneratedColumn<int>(
    'water_progress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditedStepWaterDosesMeta =
      const VerificationMeta('creditedStepWaterDoses');
  @override
  late final GeneratedColumn<int> creditedStepWaterDoses = GeneratedColumn<int>(
    'credited_step_water_doses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditedDayMeta = const VerificationMeta(
    'creditedDay',
  );
  @override
  late final GeneratedColumn<String> creditedDay = GeneratedColumn<String>(
    'credited_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    plantStage,
    waterDoses,
    waterProgress,
    creditedStepWaterDoses,
    creditedDay,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'garden_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<GardenRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('plant_stage')) {
      context.handle(
        _plantStageMeta,
        plantStage.isAcceptableOrUnknown(data['plant_stage']!, _plantStageMeta),
      );
    }
    if (data.containsKey('water_doses')) {
      context.handle(
        _waterDosesMeta,
        waterDoses.isAcceptableOrUnknown(data['water_doses']!, _waterDosesMeta),
      );
    } else if (isInserting) {
      context.missing(_waterDosesMeta);
    }
    if (data.containsKey('water_progress')) {
      context.handle(
        _waterProgressMeta,
        waterProgress.isAcceptableOrUnknown(
          data['water_progress']!,
          _waterProgressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_waterProgressMeta);
    }
    if (data.containsKey('credited_step_water_doses')) {
      context.handle(
        _creditedStepWaterDosesMeta,
        creditedStepWaterDoses.isAcceptableOrUnknown(
          data['credited_step_water_doses']!,
          _creditedStepWaterDosesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creditedStepWaterDosesMeta);
    }
    if (data.containsKey('credited_day')) {
      context.handle(
        _creditedDayMeta,
        creditedDay.isAcceptableOrUnknown(
          data['credited_day']!,
          _creditedDayMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GardenRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GardenRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      plantStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_stage'],
      ),
      waterDoses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}water_doses'],
      )!,
      waterProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}water_progress'],
      )!,
      creditedStepWaterDoses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credited_step_water_doses'],
      )!,
      creditedDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credited_day'],
      ),
    );
  }

  @override
  $GardenRecordsTable createAlias(String alias) {
    return $GardenRecordsTable(attachedDatabase, alias);
  }
}

class GardenRecord extends DataClass implements Insertable<GardenRecord> {
  final int id;
  final String? plantStage;
  final int waterDoses;
  final int waterProgress;
  final int creditedStepWaterDoses;
  final String? creditedDay;
  const GardenRecord({
    required this.id,
    this.plantStage,
    required this.waterDoses,
    required this.waterProgress,
    required this.creditedStepWaterDoses,
    this.creditedDay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || plantStage != null) {
      map['plant_stage'] = Variable<String>(plantStage);
    }
    map['water_doses'] = Variable<int>(waterDoses);
    map['water_progress'] = Variable<int>(waterProgress);
    map['credited_step_water_doses'] = Variable<int>(creditedStepWaterDoses);
    if (!nullToAbsent || creditedDay != null) {
      map['credited_day'] = Variable<String>(creditedDay);
    }
    return map;
  }

  GardenRecordsCompanion toCompanion(bool nullToAbsent) {
    return GardenRecordsCompanion(
      id: Value(id),
      plantStage: plantStage == null && nullToAbsent
          ? const Value.absent()
          : Value(plantStage),
      waterDoses: Value(waterDoses),
      waterProgress: Value(waterProgress),
      creditedStepWaterDoses: Value(creditedStepWaterDoses),
      creditedDay: creditedDay == null && nullToAbsent
          ? const Value.absent()
          : Value(creditedDay),
    );
  }

  factory GardenRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GardenRecord(
      id: serializer.fromJson<int>(json['id']),
      plantStage: serializer.fromJson<String?>(json['plantStage']),
      waterDoses: serializer.fromJson<int>(json['waterDoses']),
      waterProgress: serializer.fromJson<int>(json['waterProgress']),
      creditedStepWaterDoses: serializer.fromJson<int>(
        json['creditedStepWaterDoses'],
      ),
      creditedDay: serializer.fromJson<String?>(json['creditedDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'plantStage': serializer.toJson<String?>(plantStage),
      'waterDoses': serializer.toJson<int>(waterDoses),
      'waterProgress': serializer.toJson<int>(waterProgress),
      'creditedStepWaterDoses': serializer.toJson<int>(creditedStepWaterDoses),
      'creditedDay': serializer.toJson<String?>(creditedDay),
    };
  }

  GardenRecord copyWith({
    int? id,
    Value<String?> plantStage = const Value.absent(),
    int? waterDoses,
    int? waterProgress,
    int? creditedStepWaterDoses,
    Value<String?> creditedDay = const Value.absent(),
  }) => GardenRecord(
    id: id ?? this.id,
    plantStage: plantStage.present ? plantStage.value : this.plantStage,
    waterDoses: waterDoses ?? this.waterDoses,
    waterProgress: waterProgress ?? this.waterProgress,
    creditedStepWaterDoses:
        creditedStepWaterDoses ?? this.creditedStepWaterDoses,
    creditedDay: creditedDay.present ? creditedDay.value : this.creditedDay,
  );
  GardenRecord copyWithCompanion(GardenRecordsCompanion data) {
    return GardenRecord(
      id: data.id.present ? data.id.value : this.id,
      plantStage: data.plantStage.present
          ? data.plantStage.value
          : this.plantStage,
      waterDoses: data.waterDoses.present
          ? data.waterDoses.value
          : this.waterDoses,
      waterProgress: data.waterProgress.present
          ? data.waterProgress.value
          : this.waterProgress,
      creditedStepWaterDoses: data.creditedStepWaterDoses.present
          ? data.creditedStepWaterDoses.value
          : this.creditedStepWaterDoses,
      creditedDay: data.creditedDay.present
          ? data.creditedDay.value
          : this.creditedDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GardenRecord(')
          ..write('id: $id, ')
          ..write('plantStage: $plantStage, ')
          ..write('waterDoses: $waterDoses, ')
          ..write('waterProgress: $waterProgress, ')
          ..write('creditedStepWaterDoses: $creditedStepWaterDoses, ')
          ..write('creditedDay: $creditedDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    plantStage,
    waterDoses,
    waterProgress,
    creditedStepWaterDoses,
    creditedDay,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GardenRecord &&
          other.id == this.id &&
          other.plantStage == this.plantStage &&
          other.waterDoses == this.waterDoses &&
          other.waterProgress == this.waterProgress &&
          other.creditedStepWaterDoses == this.creditedStepWaterDoses &&
          other.creditedDay == this.creditedDay);
}

class GardenRecordsCompanion extends UpdateCompanion<GardenRecord> {
  final Value<int> id;
  final Value<String?> plantStage;
  final Value<int> waterDoses;
  final Value<int> waterProgress;
  final Value<int> creditedStepWaterDoses;
  final Value<String?> creditedDay;
  const GardenRecordsCompanion({
    this.id = const Value.absent(),
    this.plantStage = const Value.absent(),
    this.waterDoses = const Value.absent(),
    this.waterProgress = const Value.absent(),
    this.creditedStepWaterDoses = const Value.absent(),
    this.creditedDay = const Value.absent(),
  });
  GardenRecordsCompanion.insert({
    this.id = const Value.absent(),
    this.plantStage = const Value.absent(),
    required int waterDoses,
    required int waterProgress,
    required int creditedStepWaterDoses,
    this.creditedDay = const Value.absent(),
  }) : waterDoses = Value(waterDoses),
       waterProgress = Value(waterProgress),
       creditedStepWaterDoses = Value(creditedStepWaterDoses);
  static Insertable<GardenRecord> custom({
    Expression<int>? id,
    Expression<String>? plantStage,
    Expression<int>? waterDoses,
    Expression<int>? waterProgress,
    Expression<int>? creditedStepWaterDoses,
    Expression<String>? creditedDay,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (plantStage != null) 'plant_stage': plantStage,
      if (waterDoses != null) 'water_doses': waterDoses,
      if (waterProgress != null) 'water_progress': waterProgress,
      if (creditedStepWaterDoses != null)
        'credited_step_water_doses': creditedStepWaterDoses,
      if (creditedDay != null) 'credited_day': creditedDay,
    });
  }

  GardenRecordsCompanion copyWith({
    Value<int>? id,
    Value<String?>? plantStage,
    Value<int>? waterDoses,
    Value<int>? waterProgress,
    Value<int>? creditedStepWaterDoses,
    Value<String?>? creditedDay,
  }) {
    return GardenRecordsCompanion(
      id: id ?? this.id,
      plantStage: plantStage ?? this.plantStage,
      waterDoses: waterDoses ?? this.waterDoses,
      waterProgress: waterProgress ?? this.waterProgress,
      creditedStepWaterDoses:
          creditedStepWaterDoses ?? this.creditedStepWaterDoses,
      creditedDay: creditedDay ?? this.creditedDay,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (plantStage.present) {
      map['plant_stage'] = Variable<String>(plantStage.value);
    }
    if (waterDoses.present) {
      map['water_doses'] = Variable<int>(waterDoses.value);
    }
    if (waterProgress.present) {
      map['water_progress'] = Variable<int>(waterProgress.value);
    }
    if (creditedStepWaterDoses.present) {
      map['credited_step_water_doses'] = Variable<int>(
        creditedStepWaterDoses.value,
      );
    }
    if (creditedDay.present) {
      map['credited_day'] = Variable<String>(creditedDay.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GardenRecordsCompanion(')
          ..write('id: $id, ')
          ..write('plantStage: $plantStage, ')
          ..write('waterDoses: $waterDoses, ')
          ..write('waterProgress: $waterProgress, ')
          ..write('creditedStepWaterDoses: $creditedStepWaterDoses, ')
          ..write('creditedDay: $creditedDay')
          ..write(')'))
        .toString();
  }
}

abstract class _$GardenDatabase extends GeneratedDatabase {
  _$GardenDatabase(QueryExecutor e) : super(e);
  $GardenDatabaseManager get managers => $GardenDatabaseManager(this);
  late final $GardenRecordsTable gardenRecords = $GardenRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [gardenRecords];
}

typedef $$GardenRecordsTableCreateCompanionBuilder =
    GardenRecordsCompanion Function({
      Value<int> id,
      Value<String?> plantStage,
      required int waterDoses,
      required int waterProgress,
      required int creditedStepWaterDoses,
      Value<String?> creditedDay,
    });
typedef $$GardenRecordsTableUpdateCompanionBuilder =
    GardenRecordsCompanion Function({
      Value<int> id,
      Value<String?> plantStage,
      Value<int> waterDoses,
      Value<int> waterProgress,
      Value<int> creditedStepWaterDoses,
      Value<String?> creditedDay,
    });

class $$GardenRecordsTableFilterComposer
    extends Composer<_$GardenDatabase, $GardenRecordsTable> {
  $$GardenRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plantStage => $composableBuilder(
    column: $table.plantStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get waterDoses => $composableBuilder(
    column: $table.waterDoses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get waterProgress => $composableBuilder(
    column: $table.waterProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditedStepWaterDoses => $composableBuilder(
    column: $table.creditedStepWaterDoses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creditedDay => $composableBuilder(
    column: $table.creditedDay,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GardenRecordsTableOrderingComposer
    extends Composer<_$GardenDatabase, $GardenRecordsTable> {
  $$GardenRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plantStage => $composableBuilder(
    column: $table.plantStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get waterDoses => $composableBuilder(
    column: $table.waterDoses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get waterProgress => $composableBuilder(
    column: $table.waterProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditedStepWaterDoses => $composableBuilder(
    column: $table.creditedStepWaterDoses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creditedDay => $composableBuilder(
    column: $table.creditedDay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GardenRecordsTableAnnotationComposer
    extends Composer<_$GardenDatabase, $GardenRecordsTable> {
  $$GardenRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get plantStage => $composableBuilder(
    column: $table.plantStage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get waterDoses => $composableBuilder(
    column: $table.waterDoses,
    builder: (column) => column,
  );

  GeneratedColumn<int> get waterProgress => $composableBuilder(
    column: $table.waterProgress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditedStepWaterDoses => $composableBuilder(
    column: $table.creditedStepWaterDoses,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creditedDay => $composableBuilder(
    column: $table.creditedDay,
    builder: (column) => column,
  );
}

class $$GardenRecordsTableTableManager
    extends
        RootTableManager<
          _$GardenDatabase,
          $GardenRecordsTable,
          GardenRecord,
          $$GardenRecordsTableFilterComposer,
          $$GardenRecordsTableOrderingComposer,
          $$GardenRecordsTableAnnotationComposer,
          $$GardenRecordsTableCreateCompanionBuilder,
          $$GardenRecordsTableUpdateCompanionBuilder,
          (
            GardenRecord,
            BaseReferences<_$GardenDatabase, $GardenRecordsTable, GardenRecord>,
          ),
          GardenRecord,
          PrefetchHooks Function()
        > {
  $$GardenRecordsTableTableManager(
    _$GardenDatabase db,
    $GardenRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GardenRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GardenRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GardenRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> plantStage = const Value.absent(),
                Value<int> waterDoses = const Value.absent(),
                Value<int> waterProgress = const Value.absent(),
                Value<int> creditedStepWaterDoses = const Value.absent(),
                Value<String?> creditedDay = const Value.absent(),
              }) => GardenRecordsCompanion(
                id: id,
                plantStage: plantStage,
                waterDoses: waterDoses,
                waterProgress: waterProgress,
                creditedStepWaterDoses: creditedStepWaterDoses,
                creditedDay: creditedDay,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> plantStage = const Value.absent(),
                required int waterDoses,
                required int waterProgress,
                required int creditedStepWaterDoses,
                Value<String?> creditedDay = const Value.absent(),
              }) => GardenRecordsCompanion.insert(
                id: id,
                plantStage: plantStage,
                waterDoses: waterDoses,
                waterProgress: waterProgress,
                creditedStepWaterDoses: creditedStepWaterDoses,
                creditedDay: creditedDay,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GardenRecordsTable, GardenRecord>(table),
                  BaseReferences<
                    _$GardenDatabase,
                    $GardenRecordsTable,
                    GardenRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GardenRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$GardenDatabase,
      $GardenRecordsTable,
      GardenRecord,
      $$GardenRecordsTableFilterComposer,
      $$GardenRecordsTableOrderingComposer,
      $$GardenRecordsTableAnnotationComposer,
      $$GardenRecordsTableCreateCompanionBuilder,
      $$GardenRecordsTableUpdateCompanionBuilder,
      (
        GardenRecord,
        BaseReferences<_$GardenDatabase, $GardenRecordsTable, GardenRecord>,
      ),
      GardenRecord,
      PrefetchHooks Function()
    >;

class $GardenDatabaseManager {
  final _$GardenDatabase _db;
  $GardenDatabaseManager(this._db);
  $$GardenRecordsTableTableManager get gardenRecords =>
      $$GardenRecordsTableTableManager(_db, _db.gardenRecords);
}
