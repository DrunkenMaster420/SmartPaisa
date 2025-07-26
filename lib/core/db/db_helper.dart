import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'smartpaisa.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            smsId INTEGER,
            body TEXT NOT NULL,
            amount REAL NOT NULL,
            isDebit INTEGER NOT NULL,
            date INTEGER NOT NULL,
            UNIQUE(smsId) ON CONFLICT IGNORE
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> insertTransaction({
    required int? smsId,
    required String body,
    required double amount,
    required bool isDebit,
    required int date,
  }) async {
    final db = await database;
    await db.insert(
      'transactions',
      {
        'smsId': smsId,
        'body': body,
        'amount': amount,
        'isDebit': isDebit ? 1 : 0,
        'date': date,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Txn>> fetchAllTransactions() async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );
    return maps.map((m) => Txn(
      smsId: m['smsId'] as int?,
      body: m['body'] as String,
      amount: m['amount'] as double,
      isDebit: (m['isDebit'] as int) == 1,
      date: m['date'] as int,
    )).toList();
  }
}

class Txn {
  final int? smsId;
  final String body;
  final double amount;
  final bool isDebit;
  final int date;
  Txn({
    required this.smsId,
    required this.body,
    required this.amount,
    required this.isDebit,
    required this.date,
  });
}
