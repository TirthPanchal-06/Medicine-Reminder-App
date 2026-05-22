import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite Database is not supported on Web. Use DBHelper CRUD methods directly.');
    }
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'medicine_reminder.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Medicine Schedules
    await db.execute('''
      CREATE TABLE medicine_schedules (
        id TEXT PRIMARY KEY,
        userId TEXT,
        familyMemberId TEXT,
        name TEXT,
        dosage TEXT,
        frequency TEXT,
        specificDays TEXT,
        interval INTEGER,
        times TEXT,
        startDate TEXT,
        endDate TEXT,
        instructions TEXT,
        imageUrl TEXT,
        isActive INTEGER,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 2. Dose Logs
    await db.execute('''
      CREATE TABLE dose_logs (
        id TEXT PRIMARY KEY,
        scheduleId TEXT,
        userId TEXT,
        familyMemberId TEXT,
        dueTime TEXT,
        takenTime TEXT,
        status TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 3. Health Records
    await db.execute('''
      CREATE TABLE health_records (
        id TEXT PRIMARY KEY,
        userId TEXT,
        familyMemberId TEXT,
        type TEXT,
        value TEXT,
        timestamp TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 4. Appointments
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        userId TEXT,
        doctorName TEXT,
        specialty TEXT,
        dateTime TEXT,
        venue TEXT,
        notes TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 5. Family Members
    await db.execute('''
      CREATE TABLE family_members (
        id TEXT PRIMARY KEY,
        userId TEXT,
        name TEXT,
        relationship TEXT,
        age INTEGER,
        gender TEXT,
        medicalHistory TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 6. SOS Contacts
    await db.execute('''
      CREATE TABLE sos_contacts (
        id TEXT PRIMARY KEY,
        userId TEXT,
        name TEXT,
        phone TEXT,
        relationship TEXT,
        isEmergency INTEGER,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 7. Sync Queue Table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tableName TEXT,
        rowId TEXT,
        operationType TEXT,
        payload TEXT,
        timestamp TEXT
      )
    ''');
  }

  // --- Web Hybrid Persistence Layer ---

  Future<List<Map<String, dynamic>>> _getWebTable(String table) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('web_db_table_$table');
    if (data == null) return [];
    try {
      final decoded = jsonDecode(data);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveWebTable(String table, List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('web_db_table_$table', jsonEncode(list));
  }

  // --- Generic Helpers ---

  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (kIsWeb) {
      final list = await _getWebTable(table);
      list.removeWhere((item) => item['id'] == data['id']);
      list.add(data);
      await _saveWebTable(table, list);
      return 1;
    }
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table, {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    if (kIsWeb) {
      var list = await _getWebTable(table);

      if (where != null && whereArgs != null) {
        if (where.contains('isActive = ?')) {
          final activeVal = whereArgs[0];
          list = list.where((item) {
            final val = item['isActive'];
            return val == activeVal || (activeVal == 1 && val == true) || (activeVal == 0 && val == false);
          }).toList();
        }
        if (where.contains('type = ?')) {
          final typeVal = whereArgs[0];
          list = list.where((item) => item['type'] == typeVal).toList();
        }
        if (where.contains('familyMemberId = ?')) {
          final fmId = whereArgs.last;
          list = list.where((item) => item['familyMemberId'] == fmId).toList();
        } else if (where.contains('familyMemberId IS NULL')) {
          list = list.where((item) => item['familyMemberId'] == null || item['familyMemberId'] == '').toList();
        }
      }

      if (orderBy != null) {
        if (orderBy.contains('timestamp DESC')) {
          list.sort((a, b) {
            final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        } else if (orderBy.contains('id ASC')) {
          list.sort((a, b) {
            final aId = a['id']?.toString() ?? '';
            final bId = b['id']?.toString() ?? '';
            return aId.compareTo(bId);
          });
        }
      }

      return list;
    }
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    if (kIsWeb) {
      final list = await _getWebTable(table);
      int updatedCount = 0;
      for (var i = 0; i < list.length; i++) {
        if (list[i]['id'] == id) {
          list[i] = {...list[i], ...data};
          updatedCount++;
        }
      }
      await _saveWebTable(table, list);
      return updatedCount;
    }
    final db = await database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, String id) async {
    if (kIsWeb) {
      final list = await _getWebTable(table);
      final initialLength = list.length;
      list.removeWhere((item) => item['id'] == id);
      await _saveWebTable(table, list);
      return initialLength - list.length;
    }
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSynced(String table) async {
    if (kIsWeb) {
      final list = await _getWebTable(table);
      final initialLength = list.length;
      list.removeWhere((item) => item['isSynced'] == 1 || item['isSynced'] == true || item['isSynced'] == null);
      await _saveWebTable(table, list);
      return initialLength - list.length;
    }
    final db = await database;
    return await db.delete(table, where: 'isSynced = 1');
  }

  // --- Offline Synchronization Queue Helpers ---

  Future<void> addToSyncQueue(String tableName, String rowId, String operationType, Map<String, dynamic> payload) async {
    if (kIsWeb) {
      final list = await _getWebTable('sync_queue');
      int maxId = 0;
      for (var item in list) {
        final currentId = item['id'] as int? ?? 0;
        if (currentId > maxId) maxId = currentId;
      }
      final newId = maxId + 1;
      final newItem = {
        'id': newId,
        'tableName': tableName,
        'rowId': rowId,
        'operationType': operationType,
        'payload': jsonEncode(payload),
        'timestamp': DateTime.now().toIso8601String()
      };
      list.add(newItem);
      await _saveWebTable('sync_queue', list);
      return;
    }
    final db = await database;
    await db.insert('sync_queue', {
      'tableName': tableName,
      'rowId': rowId,
      'operationType': operationType,
      'payload': jsonEncode(payload),
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    if (kIsWeb) {
      final list = await _getWebTable('sync_queue');
      list.sort((a, b) {
        final aId = a['id'] as int? ?? 0;
        final bId = b['id'] as int? ?? 0;
        return aId.compareTo(bId);
      });
      return list;
    }
    final db = await database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  Future<void> removeFromSyncQueue(int syncId) async {
    if (kIsWeb) {
      final list = await _getWebTable('sync_queue');
      list.removeWhere((item) => item['id'] == syncId);
      await _saveWebTable('sync_queue', list);
      return;
    }
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [syncId]);
  }

  Future<void> updateSyncQueueRowId(String tableName, String oldRowId, String newRowId) async {
    if (kIsWeb) {
      final list = await _getWebTable('sync_queue');
      bool modified = false;
      for (var i = 0; i < list.length; i++) {
        if (list[i]['tableName'] == tableName && list[i]['rowId'] == oldRowId) {
          list[i]['rowId'] = newRowId;
          try {
            final Map<String, dynamic> payload = jsonDecode(list[i]['payload']);
            if (payload['id'] == oldRowId) {
              payload['id'] = newRowId;
            }
            if (payload['doseLogId'] == oldRowId) {
              payload['doseLogId'] = newRowId;
            }
            list[i]['payload'] = jsonEncode(payload);
          } catch (_) {}
          modified = true;
        }
      }
      if (modified) {
        await _saveWebTable('sync_queue', list);
      }
      return;
    }
    final db = await database;
    final list = await db.query('sync_queue', where: 'tableName = ? AND rowId = ?', whereArgs: [tableName, oldRowId]);
    for (var row in list) {
      final int syncId = row['id'] as int;
      try {
        final Map<String, dynamic> payload = jsonDecode(row['payload'] as String);
        if (payload['id'] == oldRowId) {
          payload['id'] = newRowId;
        }
        if (payload['doseLogId'] == oldRowId) {
          payload['doseLogId'] = newRowId;
        }
        await db.update('sync_queue', {
          'rowId': newRowId,
          'payload': jsonEncode(payload),
        }, where: 'id = ?', whereArgs: [syncId]);
      } catch (_) {}
    }
  }

  Future<void> updateRecordId(String table, String oldId, String newId) async {
    if (kIsWeb) {
      final list = await _getWebTable(table);
      for (var i = 0; i < list.length; i++) {
        if (list[i]['id'] == oldId) {
          list[i]['id'] = newId;
          list[i]['isSynced'] = 1;
        }
      }
      await _saveWebTable(table, list);
      return;
    }
    final db = await database;
    await db.update(table, {'id': newId, 'isSynced': 1}, where: 'id = ?', whereArgs: [oldId]);
  }

  Future<void> clearDatabase() async {
    if (kIsWeb) {
      await _saveWebTable('medicine_schedules', []);
      await _saveWebTable('dose_logs', []);
      await _saveWebTable('health_records', []);
      await _saveWebTable('appointments', []);
      await _saveWebTable('family_members', []);
      await _saveWebTable('sos_contacts', []);
      await _saveWebTable('sync_queue', []);
      return;
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('medicine_schedules');
      await txn.delete('dose_logs');
      await txn.delete('health_records');
      await txn.delete('appointments');
      await txn.delete('family_members');
      await txn.delete('sos_contacts');
      await txn.delete('sync_queue');
    });
  }
}
