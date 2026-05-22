import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/health_record_model.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';

class HealthProvider with ChangeNotifier {
  final DBHelper _db = DBHelper();
  final _uuid = const Uuid();

  List<HealthRecordModel> _bloodPressureRecords = [];
  List<HealthRecordModel> _bloodSugarRecords = [];
  List<HealthRecordModel> _heartRateRecords = [];
  List<HealthRecordModel> _weightRecords = [];
  
  Map<String, HealthRecordModel?> _latestVitals = {};
  
  final List<Map<String, String>> _chatMessages = [
    {
      'role': 'model',
      'content': 'Hello! I am your AI Health Assistant. 🩺 Ask me anything about your medicine schedules, symptoms, vital ranges, or side effects!'
    }
  ];

  bool _isLoading = false;
  bool _isChatLoading = false;

  List<HealthRecordModel> get bloodPressureRecords => _bloodPressureRecords;
  List<HealthRecordModel> get bloodSugarRecords => _bloodSugarRecords;
  List<HealthRecordModel> get heartRateRecords => _heartRateRecords;
  List<HealthRecordModel> get weightRecords => _weightRecords;
  
  Map<String, HealthRecordModel?> get latestVitals => _latestVitals;
  List<Map<String, String>> get chatMessages => _chatMessages;
  
  bool get isLoading => _isLoading;
  bool get isChatLoading => _isChatLoading;

  // --- 1. Vitals Log CRUD ---

  Future<void> fetchVitals(String type, {String? familyMemberId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final fMemberPart = familyMemberId != null ? '&familyMemberId=$familyMemberId' : '&familyMemberId=null';
      final res = await ApiService.get('/health-records?type=$type$fMemberPart');
      if (res['success'] == true) {
        final List data = res['data'];
        final records = data.map((json) => HealthRecordModel.fromJson(json)).toList();

        _updateRecordsList(type, records);
        
        // Cache locally
        for (var rec in records) {
          await _db.insert('health_records', rec.toSqlMap());
        }
      }
    } catch (e) {
      print('Offline: Loading vitals from SQLite. $e');
      final local = await _db.queryAll(
        'health_records',
        where: 'type = ?${familyMemberId != null ? " AND familyMemberId = ?" : " AND familyMemberId IS NULL"}',
        whereArgs: familyMemberId != null ? [type, familyMemberId] : [type],
        orderBy: 'timestamp DESC'
      );
      final records = local.map((j) => HealthRecordModel.fromJson(j)).toList();
      _updateRecordsList(type, records.reversed.toList());
    }

    _isLoading = false;
    notifyListeners();
  }

  void _updateRecordsList(String type, List<HealthRecordModel> records) {
    if (type == 'blood_pressure') {
      _bloodPressureRecords = records;
    } else if (type == 'blood_sugar') {
      _bloodSugarRecords = records;
    } else if (type == 'heart_rate') {
      _heartRateRecords = records;
    } else if (type == 'weight') {
      _weightRecords = records;
    }
  }

  Future<void> fetchVitalsSummary({String? familyMemberId}) async {
    try {
      final fMemberPart = familyMemberId != null ? '?familyMemberId=$familyMemberId' : '?familyMemberId=null';
      final res = await ApiService.get('/health-records/summary$fMemberPart');
      if (res['success'] == true) {
        final Map<String, dynamic> data = res['data'];
        _latestVitals = {};
        data.forEach((key, val) {
          _latestVitals[key] = val != null ? HealthRecordModel.fromJson(val) : null;
        });
        notifyListeners();
      }
    } catch (_) {
      // Local fallback summary
      _latestVitals = {};
      final types = ['blood_pressure', 'blood_sugar', 'weight', 'heart_rate'];
      for (var type in types) {
        final local = await _db.queryAll(
          'health_records',
          where: 'type = ?${familyMemberId != null ? " AND familyMemberId = ?" : " AND familyMemberId IS NULL"}',
          whereArgs: familyMemberId != null ? [type, familyMemberId] : [type],
          orderBy: 'timestamp DESC',
          
        );
        _latestVitals[type] = local.isNotEmpty ? HealthRecordModel.fromJson(local.first) : null;
      }
      notifyListeners();
    }
  }

  Future<void> addVitalsRecord(String type, Map<String, dynamic> value, {String? familyMemberId}) async {
    final localId = _uuid.v4();
    final localRec = HealthRecordModel(
      id: localId,
      userId: '',
      familyMemberId: familyMemberId,
      type: type,
      value: value,
      timestamp: DateTime.now(),
      isSynced: false
    );

    // Update list dynamically
    final currentList = _getListForType(type);
    currentList.add(localRec);
    _updateRecordsList(type, currentList);
    _latestVitals[type] = localRec;
    notifyListeners();

    await _db.insert('health_records', localRec.toSqlMap());

    final payload = {
      'type': type,
      'value': value,
      'familyMemberId': familyMemberId ?? '',
      'timestamp': localRec.timestamp.toIso8601String()
    };

    try {
      await ApiService.post('/health-records', payload);
      await fetchVitals(type, familyMemberId: familyMemberId);
      await fetchVitalsSummary(familyMemberId: familyMemberId);
    } catch (e) {
      print('Offline: Vitals saved locally and sync task queued.');
      await _db.addToSyncQueue('health_records', localId, 'create', payload);
    }
  }

  List<HealthRecordModel> _getListForType(String type) {
    if (type == 'blood_pressure') return _bloodPressureRecords;
    if (type == 'blood_sugar') return _bloodSugarRecords;
    if (type == 'heart_rate') return _heartRateRecords;
    if (type == 'weight') return _weightRecords;
    return [];
  }

  // --- 2. AI Health Assistant Chatbot ---

  Future<void> sendChatMessage(String message) async {
    if (message.trim().isEmpty) return;

    _chatMessages.add({'role': 'user', 'content': message});
    _isChatLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.post('/chat/message', {
        'history': _chatMessages.sublist(1, _chatMessages.length - 1),
        'message': message
      });

      if (res['success'] == true) {
        _chatMessages.add({
          'role': 'model',
          'content': res['data']['response']
        });
      }
    } catch (e) {
      _chatMessages.add({
        'role': 'model',
        'content': 'Sorry, I couldn\'t process that message. Check your connection or retry. $e'
      });
    }

    _isChatLoading = false;
    notifyListeners();
  }

  void clearChatHistory() {
    _chatMessages.clear();
    _chatMessages.add({
      'role': 'model',
      'content': 'Chat history cleared. How can I help you manage your health routines today?'
    });
    notifyListeners();
  }

  // --- 3. OCR Prescription Scan Trigger ---

  Future<Map<String, dynamic>?> scanPrescription(
    String filePath, {
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.uploadMultipart(
        '/ocr/scan',
        filePath,
        {},
        fileBytes: fileBytes,
        fileName: fileName,
      );
      _isLoading = false;
      notifyListeners();

      if (res['success'] == true) {
        return res['data']; // Returns rawText and extracted medicines array!
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }
}
