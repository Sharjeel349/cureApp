import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cure.dart';
import '../models/disease.dart';
import '../models/log_entry.dart';
import '../models/surah_info.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  // The uploaded database file
  static const String databaseName = 'CompleteQuran new_1.db';
  static const String databaseAssetPath = 'lib/assets/CompleteQuran new_1.db';

  // Actual table names in the uploaded database
  static const String diseaseTable = 'Disease';
  static const String categoryTable = 'Category';
  static const String cureTable = 'Cure';
  static const String cureDetailTable = 'CureDetail';
  static const String quranTable = 'Quran';
  static const String surahTable = 'surahs';
  static const String logsTable = 'Logs';

  Database? _database;
  Future<Database>? _databaseFuture;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _databaseFuture ??= _openDatabase();

    try {
      _database = await _databaseFuture!;
      return _database!;
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  // ---------------------------------------------------------
  // DATABASE CONNECTION
  // ---------------------------------------------------------

  Future<Database> _openDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$databaseName';
    final file = File(path);

    // Copy the original database only when it does not exist.
    if (!await file.exists() || await file.length() == 0) {
      final data = await rootBundle.load(databaseAssetPath);

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await file.writeAsBytes(bytes, flush: true);
    }

    final db = await openDatabase(
      path,
      onOpen: (database) async {
        await _createLogsTable(database);
        await _ensureDiseaseColumns(database);
      },
    );

    // Check that the expected original tables exist.
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    final tableNames = tables
        .map((row) => row['name'].toString().toLowerCase())
        .toSet();

    const requiredTables = [
      'category',
      'disease',
      'cure',
      'curedetail',
      'quran',
      'surahs',
    ];

    for (final table in requiredTables) {
      if (!tableNames.contains(table.toLowerCase())) {
        await db.close();
        throw Exception('Required database table not found: $table');
      }
    }

    return db;
  }

  // The uploaded database does not contain a Logs table.
  // This creates only the table needed by your existing Logs screen.
  Future<void> _createLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $logsTable (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        DiseaseId INTEGER,
        CureId INTEGER,
        DiseaseName TEXT,
        SurahName TEXT,
        TargetCount INTEGER DEFAULT 0,
        CurrentCount INTEGER DEFAULT 0,
        Status TEXT DEFAULT 'PENDING',
        DateStart TEXT,
        DateEnd TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_logs_status
      ON $logsTable(Status)
    ''');
  }

  Future<void> _ensureDiseaseColumns(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($diseaseTable)');
      final hasDescription = columns.any(
        (c) => (c['name']?.toString().toLowerCase() ?? '') == 'description',
      );
      if (!hasDescription) {
        await db.execute('ALTER TABLE $diseaseTable ADD COLUMN Description TEXT');
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------
  // DISEASE QUERIES
  // ---------------------------------------------------------

  Future<List<Disease>> fetchDiseases() async {
    final db = await database;

    final columns = await db.rawQuery('PRAGMA table_info($diseaseTable)');
    final hasDescription = columns.any(
      (c) => (c['name']?.toString().toLowerCase() ?? '') == 'description',
    );
    final descCol = hasDescription ? 'd.Description AS Description,' : 'NULL AS Description,';

    final rows = await db.rawQuery('''
      SELECT
        d.Id AS Id,
        d.Name AS DiseaseName,
        $descCol
        c.ImagePath AS ImageName
      FROM $diseaseTable d
      LEFT JOIN $categoryTable c
        ON c.Id = d.CId
      ORDER BY d.Name COLLATE NOCASE ASC
    ''');

    return rows.map((row) => Disease.fromMap(row)).toList();
  }

  Future<Disease?> fetchDiseaseById(int id) async {
    final db = await database;

    final columns = await db.rawQuery('PRAGMA table_info($diseaseTable)');
    final hasDescription = columns.any(
      (c) => (c['name']?.toString().toLowerCase() ?? '') == 'description',
    );
    final descCol = hasDescription ? 'd.Description AS Description,' : 'NULL AS Description,';

    final rows = await db.rawQuery(
      '''
      SELECT
        d.Id AS Id,
        d.Name AS DiseaseName,
        $descCol
        c.ImagePath AS ImageName
      FROM $diseaseTable d
      LEFT JOIN $categoryTable c
        ON c.Id = d.CId
      WHERE d.Id = ?
      LIMIT 1
      ''',
      [id],
    );

    if (rows.isEmpty) return null;

    return Disease.fromMap(rows.first);
  }

  Future<int> insertDisease(Disease disease) async {
    final db = await database;

    return db.transaction((txn) async {
      // Category contains the image path in this database.
      final categoryId = await txn.insert(categoryTable, {
        'Name': disease.diseaseName,
        'ImagePath': disease.imageName,
      });

      final diseaseMap = <String, dynamic>{
        'CId': categoryId,
        'Name': disease.diseaseName,
      };

      try {
        final columns = await txn.rawQuery('PRAGMA table_info($diseaseTable)');
        final hasDescription = columns.any(
          (c) => (c['name']?.toString().toLowerCase() ?? '') == 'description',
        );
        if (hasDescription && disease.description != null) {
          diseaseMap['Description'] = disease.description;
        }
      } catch (_) {}

      // Disease contains its name, optional description, and category ID.
      final diseaseId = await txn.insert(diseaseTable, diseaseMap);

      return diseaseId;
    });
  }

  Future<int> updateDisease(Disease disease) async {
    final db = await database;

    if (disease.id == null) return 0;

    return db.transaction((txn) async {
      final diseaseMap = <String, dynamic>{
        'Name': disease.diseaseName,
      };

      try {
        final columns = await txn.rawQuery('PRAGMA table_info($diseaseTable)');
        final hasDescription = columns.any(
          (c) => (c['name']?.toString().toLowerCase() ?? '') == 'description',
        );
        if (hasDescription && disease.description != null) {
          diseaseMap['Description'] = disease.description;
        }
      } catch (_) {}

      final result = await txn.update(
        diseaseTable,
        diseaseMap,
        where: 'Id = ?',
        whereArgs: [disease.id],
      );

      if (disease.imageName != null) {
        final rows = await txn.query(
          diseaseTable,
          columns: ['CId'],
          where: 'Id = ?',
          whereArgs: [disease.id],
          limit: 1,
        );

        if (rows.isNotEmpty && rows.first['CId'] != null) {
          await txn.update(
            categoryTable,
            {'Name': disease.diseaseName, 'ImagePath': disease.imageName},
            where: 'Id = ?',
            whereArgs: [rows.first['CId']],
          );
        }
      }

      return result;
    });
  }

  Future<int> deleteDisease(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      final cureRows = await txn.query(
        cureTable,
        columns: ['Id'],
        where: 'DiseaseId = ?',
        whereArgs: [id],
      );

      for (final row in cureRows) {
        await txn.delete(
          cureDetailTable,
          where: 'CuId = ?',
          whereArgs: [row['Id']],
        );
      }

      await txn.delete(cureTable, where: 'DiseaseId = ?', whereArgs: [id]);

      return txn.delete(diseaseTable, where: 'Id = ?', whereArgs: [id]);
    });
  }

  // ---------------------------------------------------------
  // SURAH QUERIES
  // ---------------------------------------------------------

  Future<List<String>> fetchSurahNames() async {
    final db = await database;

    final rows = await db.query(
      surahTable,
      columns: ['surah_names'],
      orderBy: 'Id ASC',
    );

    return rows
        .map((row) => row['surah_names']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<List<SurahInfo>> fetchSurahInfoList() async {
    final db = await database;

    final rows = await db.rawQuery('''
      SELECT
        s.Id AS SurahId,
        s.surah_names AS SurahName,
        COUNT(q.ID) AS AyahCount
      FROM $surahTable s
      LEFT JOIN $quranTable q
        ON q.SuraID = s.Id
        AND q.VerseID > 0
        AND q.DatabaseID = 1
      GROUP BY s.Id, s.surah_names
      ORDER BY s.Id ASC
    ''');

    return rows.map((row) {
      return SurahInfo(
        surahId: (row['SurahId'] as num).toInt(),
        surahName: row['SurahName']?.toString() ?? '',
        ayahCount: (row['AyahCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  String _cleanSurahName(String name) {
    return name
        .replaceFirst(RegExp(r'^surah\s+', caseSensitive: false), '')
        .split('(')
        .first
        .trim();
  }

  Future<int?> _getSurahId(DatabaseExecutor db, String surahName) async {
    final cleanName = _cleanSurahName(surahName);

    final number = int.tryParse(cleanName);
    if (number != null && number >= 1 && number <= 114) {
      final rows = await db.query(
        surahTable,
        columns: ['Id'],
        where: 'Id = ?',
        whereArgs: [number],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return (rows.first['Id'] as num).toInt();
      }
    }

    var rows = await db.query(
      surahTable,
      columns: ['Id'],
      where: 'LOWER(surah_names) = LOWER(?)',
      whereArgs: [cleanName],
      limit: 1,
    );

    if (rows.isEmpty) {
      rows = await db.query(
        surahTable,
        columns: ['Id'],
        where: 'LOWER(surah_names) LIKE LOWER(?)',
        whereArgs: ['%$cleanName%'],
        limit: 1,
      );
    }

    if (rows.isEmpty) return null;

    return (rows.first['Id'] as num).toInt();
  }

  // ---------------------------------------------------------
  // QURAN QUERIES
  // ---------------------------------------------------------

  Future<String> fetchQuranAyahText({
    required String surahName,
    required int ayatFrom,
    required int ayatTo,
  }) async {
    final db = await database;

    final surahId = await _getSurahId(db, surahName);
    if (surahId == null) return '';

    final start = ayatFrom <= ayatTo ? ayatFrom : ayatTo;
    final end = ayatFrom <= ayatTo ? ayatTo : ayatFrom;

    final rows = await db.query(
      quranTable,
      columns: ['AyahText'],
      where: '''
        DatabaseID = ?
        AND SuraID = ?
        AND VerseID BETWEEN ? AND ?
        AND VerseID > 0
      ''',
      whereArgs: [1, surahId, start, end],
      orderBy: 'VerseID ASC',
    );

    return rows
        .map((row) => row['AyahText']?.toString() ?? '')
        .where((text) => text.isNotEmpty)
        .join(' ');
  }

  // ---------------------------------------------------------
  // CURE QUERIES
  // ---------------------------------------------------------

  Future<List<Cure>> fetchCuresByDiseaseId(int diseaseId) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT
        c.Id AS CureId,
        c.DiseaseId AS DiseaseId,
        COALESCE(NULLIF(c.Title, ''), s.surah_names, '') AS SurahName,
        COALESCE(qFrom.VerseID, 0) AS AyatFrom,
        COALESCE(qTo.VerseID, 0) AS AyatTo,
        '' AS RecommendedTime,
        COALESCE(cd.Count, 0) AS TargetCount,
        COALESCE(c.Description, '') AS Instructions
      FROM $cureTable c
      LEFT JOIN $cureDetailTable cd
        ON cd.CuId = c.Id
      LEFT JOIN $quranTable qFrom
        ON qFrom.ID = cd.QIdFrom
      LEFT JOIN $quranTable qTo
        ON qTo.ID = cd.QIdTo
      LEFT JOIN $surahTable s
        ON s.Id = qFrom.SuraID
      WHERE c.DiseaseId = ?
      GROUP BY c.Id
      ORDER BY c.Id DESC
      ''',
      [diseaseId],
    );

    final rawCures = rows.map((row) => Cure.fromMap(row)).toList();

    // Consolidate any legacy split cures that share the same custom title prefix (e.g. "test1 · ...")
    final List<Cure> consolidated = [];
    final Map<String, List<Cure>> groupedByTitle = {};

    for (final c in rawCures) {
      if (c.items.length == 1 && c.instructions.contains(' · ')) {
        final prefix = c.instructions.split(' · ').first.trim();
        if (prefix.isNotEmpty && !prefix.startsWith('[')) {
          groupedByTitle.putIfAbsent(prefix, () => []).add(c);
          continue;
        }
      }
      consolidated.add(c);
    }

    for (final entry in groupedByTitle.entries) {
      final title = entry.key;
      final group = entry.value;

      if (group.length > 1) {
        // Consolidate into 1 Cure
        final combinedItems = <RecitationItem>[];
        for (final itemCure in group) {
          combinedItems.addAll(itemCure.items);
        }
        final first = group.first;
        final mergedCure = Cure(
          cureId: first.cureId,
          diseaseId: first.diseaseId,
          surahName: title,
          ayatFrom: first.ayatFrom,
          ayatTo: first.ayatTo,
          recommendedTime: first.recommendedTime,
          targetCount: combinedItems.fold(0, (sum, i) => sum + i.count),
          instructions:
              jsonEncode(combinedItems.map((i) => i.toMap()).toList()),
          items: combinedItems,
        );
        consolidated.insert(0, mergedCure);

        // Update database so duplicate rows are removed and primary row has JSON chain
        try {
          db.update(
            cureTable,
            {
              'Title': title,
              'Description': mergedCure.instructions,
            },
            where: 'Id = ?',
            whereArgs: [first.cureId],
          );
          for (int i = 1; i < group.length; i++) {
            if (group[i].cureId != null) {
              db.delete(cureTable, where: 'Id = ?', whereArgs: [group[i].cureId]);
              db.delete(
                cureDetailTable,
                where: 'CuId = ?',
                whereArgs: [group[i].cureId],
              );
            }
          }
        } catch (_) {}
      } else {
        consolidated.addAll(group);
      }
    }

    return consolidated;
  }

  Future<Cure?> fetchCureById(int cureId) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT
        c.Id AS CureId,
        c.DiseaseId AS DiseaseId,
        COALESCE(NULLIF(c.Title, ''), s.surah_names, '') AS SurahName,
        COALESCE(qFrom.VerseID, 0) AS AyatFrom,
        COALESCE(qTo.VerseID, 0) AS AyatTo,
        '' AS RecommendedTime,
        COALESCE(cd.Count, 0) AS TargetCount,
        COALESCE(c.Description, '') AS Instructions
      FROM $cureTable c
      LEFT JOIN $cureDetailTable cd
        ON cd.CuId = c.Id
      LEFT JOIN $quranTable qFrom
        ON qFrom.ID = cd.QIdFrom
      LEFT JOIN $quranTable qTo
        ON qTo.ID = cd.QIdTo
      LEFT JOIN $surahTable s
        ON s.Id = qFrom.SuraID
      WHERE c.Id = ?
      LIMIT 1
      ''',
      [cureId],
    );

    if (rows.isEmpty) return null;

    return Cure.fromMap(rows.first);
  }

  Future<int> insertCure(Cure cure) async {
    final db = await database;

    return db.transaction((txn) async {
      int? qIdFrom;
      int? qIdTo;

      try {
        final surahId = await _getSurahId(txn, cure.surahName);

        if (surahId != null) {
          final start =
              cure.ayatFrom <= cure.ayatTo ? cure.ayatFrom : cure.ayatTo;
          final end =
              cure.ayatFrom <= cure.ayatTo ? cure.ayatTo : cure.ayatFrom;

          final fromRows = await txn.query(
            quranTable,
            columns: ['ID'],
            where: 'DatabaseID = ? AND SuraID = ? AND VerseID = ?',
            whereArgs: [1, surahId, start],
            limit: 1,
          );

          final toRows = await txn.query(
            quranTable,
            columns: ['ID'],
            where: 'DatabaseID = ? AND SuraID = ? AND VerseID = ?',
            whereArgs: [1, surahId, end],
            limit: 1,
          );

          if (fromRows.isNotEmpty && toRows.isNotEmpty) {
            qIdFrom = fromRows.first['ID'] as int?;
            qIdTo = toRows.first['ID'] as int?;
          }
        }
      } catch (_) {}

      final instructionsToSave = cure.items.isNotEmpty
          ? jsonEncode(cure.items.map((i) => i.toMap()).toList())
          : cure.instructions;

      // Insert into the actual Cure table.
      final cureId = await txn.insert(cureTable, {
        'DiseaseId': cure.diseaseId,
        'Description': instructionsToSave,
        'Title': cure.surahName,
        'Score': 0,
      });

      // Link the cure to Quran.ID values using CureDetail.
      await txn.insert(cureDetailTable, {
        'CuId': cureId,
        'Count': cure.targetCount,
        'QIdFrom': qIdFrom,
        'QIdTo': qIdTo,
      });

      return cureId;
    });
  }

  Future<int> updateCure(Cure cure) async {
    final db = await database;

    if (cure.cureId == null) return 0;

    return db.transaction((txn) async {
      int? qIdFrom;
      int? qIdTo;

      try {
        final surahId = await _getSurahId(txn, cure.surahName);

        if (surahId != null) {
          final start =
              cure.ayatFrom <= cure.ayatTo ? cure.ayatFrom : cure.ayatTo;
          final end =
              cure.ayatFrom <= cure.ayatTo ? cure.ayatTo : cure.ayatFrom;

          final fromRows = await txn.query(
            quranTable,
            columns: ['ID'],
            where: 'DatabaseID = ? AND SuraID = ? AND VerseID = ?',
            whereArgs: [1, surahId, start],
            limit: 1,
          );

          final toRows = await txn.query(
            quranTable,
            columns: ['ID'],
            where: 'DatabaseID = ? AND SuraID = ? AND VerseID = ?',
            whereArgs: [1, surahId, end],
            limit: 1,
          );

          if (fromRows.isNotEmpty && toRows.isNotEmpty) {
            qIdFrom = fromRows.first['ID'] as int?;
            qIdTo = toRows.first['ID'] as int?;
          }
        }
      } catch (_) {}

      final instructionsToSave = cure.items.isNotEmpty
          ? jsonEncode(cure.items.map((i) => i.toMap()).toList())
          : cure.instructions;

      await txn.update(
        cureTable,
        {
          'DiseaseId': cure.diseaseId,
          'Description': instructionsToSave,
          'Title': cure.surahName,
        },
        where: 'Id = ?',
        whereArgs: [cure.cureId],
      );

      final details = await txn.query(
        cureDetailTable,
        columns: ['Id'],
        where: 'CuId = ?',
        whereArgs: [cure.cureId],
        limit: 1,
      );

      final detailValues = {
        'CuId': cure.cureId,
        'Count': cure.targetCount,
        'QIdFrom': qIdFrom,
        'QIdTo': qIdTo,
      };

      if (details.isEmpty) {
        await txn.insert(cureDetailTable, detailValues);
      } else {
        await txn.update(
          cureDetailTable,
          detailValues,
          where: 'CuId = ?',
          whereArgs: [cure.cureId],
        );
      }

      return 1;
    });
  }

  Future<int> deleteCure(int cureId) async {
    final db = await database;

    return db.transaction((txn) async {
      await txn.delete(cureDetailTable, where: 'CuId = ?', whereArgs: [cureId]);

      return txn.delete(cureTable, where: 'Id = ?', whereArgs: [cureId]);
    });
  }

  // ---------------------------------------------------------
  // LOG QUERIES
  // ---------------------------------------------------------

  Future<int> insertLog(LogEntry log) async {
    final db = await database;
    return db.insert(logsTable, log.toMap());
  }

  Future<List<LogEntry>> fetchLogs() async {
    final db = await database;

    final rows = await db.query(logsTable, orderBy: 'Id DESC');

    return rows.map((row) => LogEntry.fromMap(row)).toList();
  }

  Future<LogEntry?> fetchLogById(int id) async {
    final db = await database;

    final rows = await db.query(
      logsTable,
      where: 'Id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return LogEntry.fromMap(rows.first);
  }

  Future<int> updateLog(LogEntry log) async {
    final db = await database;

    return db.update(
      logsTable,
      log.toMap(),
      where: 'Id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteLog(int id) async {
    final db = await database;

    return db.delete(logsTable, where: 'Id = ?', whereArgs: [id]);
  }

  Future<int> startLog({
    required int diseaseId,
    required int cureId,
    required String diseaseName,
    required String surahName,
    required int targetCount,
  }) {
    final log = LogEntry(
      diseaseId: diseaseId,
      cureId: cureId,
      diseaseName: diseaseName,
      surahName: surahName,
      targetCount: targetCount,
      currentCount: 0,
      status: 'PENDING',
      dateStart: DateTime.now().toIso8601String(),
    );

    return insertLog(log);
  }

  Future<void> updateLogProgress({
    required int logId,
    required int currentCount,
    required int targetCount,
  }) async {
    final db = await database;

    final completed = currentCount >= targetCount;

    await db.update(
      logsTable,
      {
        'CurrentCount': currentCount,
        'Status': completed ? 'COMPLETED' : 'PENDING',
        'DateEnd': completed ? DateTime.now().toIso8601String() : null,
      },
      where: 'Id = ?',
      whereArgs: [logId],
    );
  }

  // ---------------------------------------------------------
  // CLOSE DATABASE
  // ---------------------------------------------------------

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    _databaseFuture = null;
  }
}
