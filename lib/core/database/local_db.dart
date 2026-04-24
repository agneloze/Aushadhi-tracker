import 'package:drift/drift.dart';

part 'local_db.g.dart';

// Medicines Table (Master list)
class Medicines extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString())();
  TextColumn get nameEn => text().withLength(min: 1, max: 255)();
  TextColumn get nameHi => text().nullable()();
  TextColumn get category => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// Batches Table (Expiry tracking)
class Batches extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString())();
  TextColumn get medicineId => text().references(Medicines, #id)();
  TextColumn get batchNumber => text().withLength(min: 1, max: 100)();
  DateTimeColumn get expiryDate => dateTime()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Medicines, Batches])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  // FIFO Query: Get batches for a medicine sorted by expiry date
  Future<List<Batch>> getBatchesForMedicine(String medicineId) {
    return (select(batches)
          ..where((t) => t.medicineId.equals(medicineId))
          ..orderBy([(t) => OrderingTerm(expression: t.expiryDate, mode: OrderingMode.asc)]))
        .get();
  }

  // Get all upcoming expiries (within 90 days)
  Future<List<Batch>> getUpcomingExpiries() {
    final threshold = DateTime.now().add(const Duration(days: 90));
    return (select(batches)
          ..where((t) => t.expiryDate.isSmallerOrEqualValue(threshold))
          ..orderBy([(t) => OrderingTerm(expression: t.expiryDate, mode: OrderingMode.asc)]))
        .get();
  }
}
