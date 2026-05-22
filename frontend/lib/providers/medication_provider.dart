import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine_schedule_model.dart';
import '../models/dose_log_model.dart';
import '../models/family_member_model.dart';
import '../models/appointment_model.dart';
import '../models/sos_contact_model.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';

class MedicationProvider with ChangeNotifier {
  final DBHelper _db = DBHelper();
  final _uuid = const Uuid();

  List<MedicineScheduleModel> _schedules = [];
  List<DoseLogModel> _todayDoses = [];
  List<FamilyMemberModel> _familyMembers = [];
  List<AppointmentModel> _appointments = [];
  List<SOSContactModel> _sosContacts = [];
  
  Map<String, dynamic>? _complianceStats;
  bool _isLoading = false;
  String? _selectedFamilyMemberId; // null represents main user

  List<MedicineScheduleModel> get schedules => _schedules;
  List<DoseLogModel> get todayDoses => _todayDoses;
  List<FamilyMemberModel> get familyMembers => _familyMembers;
  List<AppointmentModel> get appointments => _appointments;
  List<SOSContactModel> get sosContacts => _sosContacts;
  
  Map<String, dynamic>? get complianceStats => _complianceStats;
  bool get isLoading => _isLoading;
  String? get selectedFamilyMemberId => _selectedFamilyMemberId;

  void selectFamilyMember(String? id) {
    _selectedFamilyMemberId = id;
    notifyListeners();
    fetchTodayDoses();
    fetchSchedules();
    fetchComplianceStats();
  }

  // --- 1. Offline Synchronization Engine ---

  Future<void> syncOfflineData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final queue = await _db.getSyncQueue();
      print('Syncing offline data. Items in queue: ${queue.length}');

      for (var task in queue) {
        final int syncId = task['id'];
        final String table = task['tableName'];
        final String rowId = task['rowId'];
        final String op = task['operationType'];
        final Map<String, dynamic> payload = jsonDecode(task['payload']);

        try {
          if (table == 'medicine_schedules') {
            if (op == 'create') {
              await ApiService.post('/medicines', payload);
            } else if (op == 'update') {
              await ApiService.put('/medicines/$rowId', payload);
            } else if (op == 'delete') {
              await ApiService.delete('/medicines/$rowId');
            }
          } else if (table == 'dose_logs') {
            if (op == 'log') {
              await ApiService.post('/doses/log', payload);
            }
          } else if (table == 'health_records') {
            if (op == 'create') {
              await ApiService.post('/health-records', payload);
            }
          } else if (table == 'family_members') {
            if (op == 'create') {
              await ApiService.post('/family', payload);
            } else if (op == 'update') {
              await ApiService.put('/family/$rowId', payload);
            } else if (op == 'delete') {
              await ApiService.delete('/family/$rowId');
            }
          } else if (table == 'appointments') {
            if (op == 'create') {
              await ApiService.post('/appointments', payload);
            } else if (op == 'update') {
              await ApiService.put('/appointments/$rowId', payload);
            } else if (op == 'delete') {
              await ApiService.delete('/appointments/$rowId');
            }
          } else if (table == 'sos_contacts') {
            if (op == 'create') {
              await ApiService.post('/sos', payload);
            } else if (op == 'update') {
              await ApiService.put('/sos/$rowId', payload);
            } else if (op == 'delete') {
              await ApiService.delete('/sos/$rowId');
            }
          }

          // Successfully synced, remove task from queue
          await _db.removeFromSyncQueue(syncId);
          // Mark local record as synced
          await _db.update(table, {'isSynced': 1}, rowId);
        } catch (e) {
          print('Failed to sync task $syncId: $e. Retrying later.');
          break; // Stop sync loop if a task fails due to network
        }
      }
    } catch (e) {
      print('Sync failed: $e');
    }

    // Refresh data from server to align schemas
    await refreshAllData();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAllData() async {
    try {
      await Future.wait([
        _refreshFamilyMembers(),
        _refreshSchedules(),
        _refreshTodayDoses(),
        _refreshAppointments(),
        _refreshSOSContacts(),
        fetchComplianceStats()
      ]);
    } catch (e) {
      print('Failed to refresh data from API: $e. Utilizing local SQLite database.');
      // Load everything from local SQLite if network is offline
      await loadAllFromLocal();
    }
  }

  Future<void> loadAllFromLocal() async {
    // 1. Load family members
    final fmList = await _db.queryAll('family_members');
    final fetchedFm = fmList.map((j) => FamilyMemberModel.fromJson(j)).toList();

    // 2. Load schedules
    final scheds = await _db.queryAll(
      'medicine_schedules',
      where: 'isActive = ?${_selectedFamilyMemberId != null ? " AND familyMemberId = ?" : " AND familyMemberId IS NULL"}',
      whereArgs: _selectedFamilyMemberId != null ? [1, _selectedFamilyMemberId] : [1],
    );
    final fetchedSchedules = scheds.map((j) => MedicineScheduleModel.fromJson(j)).toList();

    for (var sched in fetchedSchedules) {
      await NotificationService.scheduleMedicineNotifications(sched);
    }

    // 3. Load today doses
    final dlList = await _db.queryAll('dose_logs');
    final fetchedTodayDoses = dlList.map((j) => DoseLogModel.fromJson(j)).toList();

    // 4. Load appointments
    final apptList = await _db.queryAll('appointments');
    final fetchedAppointments = apptList.map((j) => AppointmentModel.fromJson(j)).toList();

    // 5. Load SOS contacts
    final sosList = await _db.queryAll('sos_contacts');
    final fetchedSos = sosList.map((j) => SOSContactModel.fromJson(j)).toList();

    _familyMembers = fetchedFm;
    _schedules = fetchedSchedules;
    _todayDoses = fetchedTodayDoses;
    _appointments = fetchedAppointments;
    _sosContacts = fetchedSos;

    notifyListeners();
  }

  // --- 2. Medicine Schedules CRUD ---

  Future<void> fetchSchedules() async {
    await _refreshSchedules().catchError((_) => loadAllFromLocal());
  }

  Future<void> _refreshSchedules() async {
    final queryParam = _selectedFamilyMemberId != null ? '?familyMemberId=$_selectedFamilyMemberId' : '?familyMemberId=null';
    final res = await ApiService.get('/medicines$queryParam');
    if (res['success'] == true) {
      final List data = res['data'];
      final fetched = data.map((json) => MedicineScheduleModel.fromJson(json)).toList();

      // Overwrite local DB values with remote
      for (var sched in fetched) {
        await _db.insert('medicine_schedules', sched.toSqlMap());
        await NotificationService.scheduleMedicineNotifications(sched);
      }

      _schedules = fetched;
      notifyListeners();
    }
  }

  Future<void> addSchedule({
    required String name,
    required String dosage,
    required String frequency,
    required List<String> specificDays,
    required int interval,
    required List<String> times,
    required DateTime startDate,
    DateTime? endDate,
    required String instructions,
    String? filePath, // optional OCR image attachment
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final localId = _uuid.v4();
    final Map<String, String> payload = {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'specificDays': jsonEncode(specificDays),
      'interval': interval.toString(),
      'times': jsonEncode(times),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String() ?? '',
      'instructions': instructions,
      'familyMemberId': _selectedFamilyMemberId ?? '',
    };

    // 1. Create a local schedule representation
    final localSched = MedicineScheduleModel(
      id: localId,
      userId: '',
      familyMemberId: _selectedFamilyMemberId,
      name: name,
      dosage: dosage,
      frequency: frequency,
      specificDays: specificDays,
      interval: interval,
      times: times,
      startDate: startDate,
      endDate: endDate,
      instructions: instructions,
      imageUrl: filePath ?? '',
      isActive: true,
      isSynced: false
    );

    // Save locally
    _schedules.insert(0, localSched);
    notifyListeners();
    await _db.insert('medicine_schedules', localSched.toSqlMap());
    await NotificationService.scheduleMedicineNotifications(localSched);

    // 2. Queue for upload
    try {
      if (filePath != null && filePath.isNotEmpty) {
        await ApiService.uploadMultipart(
          '/medicines',
          filePath,
          payload,
          fileBytes: fileBytes,
          fileName: fileName,
        );
      } else {
        await ApiService.post('/medicines', payload);
      }
      
      // Successfully updated remote server, refresh to pull full database schemas
      await _refreshSchedules();
      await fetchTodayDoses();
    } catch (e) {
      print('Offline: Schedule creation queued. $e');
      await _db.addToSyncQueue('medicine_schedules', localId, 'create', payload);
    }
  }

  Future<void> updateSchedule({
    required String id,
    required String name,
    required String dosage,
    required String frequency,
    required List<String> specificDays,
    required int interval,
    required List<String> times,
    required DateTime startDate,
    DateTime? endDate,
    required String instructions,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final Map<String, String> payload = {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'specificDays': jsonEncode(specificDays),
      'interval': interval.toString(),
      'times': jsonEncode(times),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String() ?? '',
      'instructions': instructions,
      'familyMemberId': _selectedFamilyMemberId ?? '',
    };

    // 1. Update locally in memory and cache
    final index = _schedules.indexWhere((s) => s.id == id);
    if (index != -1) {
      final oldSched = _schedules[index];
      final updatedSched = MedicineScheduleModel(
        id: id,
        userId: oldSched.userId,
        familyMemberId: _selectedFamilyMemberId,
        name: name,
        dosage: dosage,
        frequency: frequency,
        specificDays: specificDays,
        interval: interval,
        times: times,
        startDate: startDate,
        endDate: endDate,
        instructions: instructions,
        imageUrl: filePath ?? oldSched.imageUrl,
        isActive: true,
        isSynced: false,
      );
      _schedules[index] = updatedSched;
      notifyListeners();
      await _db.insert('medicine_schedules', updatedSched.toSqlMap());
      await NotificationService.scheduleMedicineNotifications(updatedSched);
    }

    // 2. Transmit to remote server
    try {
      if (filePath != null && filePath.isNotEmpty) {
        await ApiService.uploadMultipart(
          '/medicines/$id',
          filePath,
          payload,
          fileBytes: fileBytes,
          fileName: fileName,
          method: 'PUT',
        );
      } else {
        await ApiService.put('/medicines/$id', payload);
      }

      await _refreshSchedules();
      await fetchTodayDoses();
    } catch (e) {
      print('Offline: Schedule update queued. $e');
      await _db.addToSyncQueue('medicine_schedules', id, 'update', payload);
    }
  }

  Future<void> deleteSchedule(String id) async {
    _schedules.removeWhere((s) => s.id == id);
    notifyListeners();
    
    // Set inactive locally
    await _db.update('medicine_schedules', {'isActive': 0, 'isSynced': 0}, id);
    await NotificationService.cancelMedicineNotifications(id);

    try {
      await ApiService.delete('/medicines/$id');
      await _refreshSchedules();
      await fetchTodayDoses();
    } catch (e) {
      print('Offline: Schedule deletion queued.');
      await _db.addToSyncQueue('medicine_schedules', id, 'delete', {'id': id});
    }
  }

  // --- 3. Dose Logging compliance CRUD ---

  Future<void> fetchTodayDoses() async {
    await _refreshTodayDoses().catchError((_) => loadAllFromLocal());
  }

  Future<void> _refreshTodayDoses() async {
    final queryParam = _selectedFamilyMemberId != null ? '?familyMemberId=$_selectedFamilyMemberId' : '?familyMemberId=null';
    final res = await ApiService.get('/doses/today$queryParam');
    if (res['success'] == true) {
      final List data = res['data'];
      final fetched = data.map((json) => DoseLogModel.fromJson(json)).toList();

      for (var log in fetched) {
        await _db.insert('dose_logs', log.toSqlMap());
      }

      _todayDoses = fetched;
      notifyListeners();
    }
  }

  Future<void> logDose(String logId, String status) async {
    // 1. Update status locally
    final index = _todayDoses.indexWhere((l) => l.id == logId);
    if (index != -1) {
      final oldLog = _todayDoses[index];
      _todayDoses[index] = DoseLogModel(
        id: oldLog.id,
        scheduleId: oldLog.scheduleId,
        userId: oldLog.userId,
        dueTime: oldLog.dueTime,
        takenTime: status == 'taken' ? DateTime.now() : null,
        status: status,
        isSynced: false,
        medicineName: oldLog.medicineName,
        dosage: oldLog.dosage,
        instructions: oldLog.instructions,
        imageUrl: oldLog.imageUrl
      );
      notifyListeners();
      await _db.insert('dose_logs', _todayDoses[index].toSqlMap());
    }

    final payload = {'doseLogId': logId, 'status': status};

    // 2. Transmit to remote database
    try {
      await ApiService.post('/doses/log', payload);
      await _refreshTodayDoses();
      await fetchComplianceStats();
    } catch (e) {
      print('Offline: Dose compliance logged locally and queued for synchronization.');
      await _db.addToSyncQueue('dose_logs', logId, 'log', payload);
    }
  }

  Future<void> fetchComplianceStats() async {
    try {
      final queryParam = _selectedFamilyMemberId != null ? '?familyMemberId=$_selectedFamilyMemberId' : '?familyMemberId=null';
      final res = await ApiService.get('/doses/stats$queryParam');
      if (res['success'] == true) {
        _complianceStats = res['data'];
        notifyListeners();
      }
    } catch (_) {
      // Local fallback calculation if offline
      final taken = _todayDoses.where((d) => d.status == 'taken').length;
      final total = _todayDoses.length;
      _complianceStats = {
        'total': total,
        'taken': taken,
        'missed': _todayDoses.where((d) => d.status == 'missed').length,
        'skipped': _todayDoses.where((d) => d.status == 'skipped').length,
        'adherenceRate': total > 0 ? ((taken / total) * 100).round() : 0,
        'dailyTrend': {}
      };
      notifyListeners();
    }
  }

  // --- 4. Family Members Profile Switcher ---

  Future<void> fetchFamilyMembers() async {
    await _refreshFamilyMembers().catchError((_) => loadAllFromLocal());
  }

  Future<void> _refreshFamilyMembers() async {
    final res = await ApiService.get('/family');
    if (res['success'] == true) {
      final List data = res['data'];
      final fetched = data.map((json) => FamilyMemberModel.fromJson(json)).toList();

      for (var fm in fetched) {
        await _db.insert('family_members', fm.toSqlMap());
      }

      _familyMembers = fetched;
      notifyListeners();
    }
  }

  Future<void> addFamilyMember(String name, String relationship, int age, String gender, String medicalHistory) async {
    final localId = _uuid.v4();
    final payload = {
      'name': name,
      'relationship': relationship,
      'age': age.toString(),
      'gender': gender,
      'medicalHistory': medicalHistory
    };

    final localMember = FamilyMemberModel(
      id: localId,
      userId: '',
      name: name,
      relationship: relationship,
      age: age,
      gender: gender,
      medicalHistory: medicalHistory,
      isSynced: false
    );

    _familyMembers.add(localMember);
    notifyListeners();
    await _db.insert('family_members', localMember.toSqlMap());

    try {
      await ApiService.post('/family', payload);
      await _refreshFamilyMembers();
    } catch (e) {
      print('Offline: Family member profile added locally and queued.');
      await _db.addToSyncQueue('family_members', localId, 'create', payload);
    }
  }

  Future<void> updateFamilyMember(String id, String name, String relationship, int age, String gender, String medicalHistory) async {
    final payload = {
      'name': name,
      'relationship': relationship,
      'age': age.toString(),
      'gender': gender,
      'medicalHistory': medicalHistory
    };

    final index = _familyMembers.indexWhere((m) => m.id == id);
    if (index != -1) {
      final oldMember = _familyMembers[index];
      final updatedMember = FamilyMemberModel(
        id: id,
        userId: oldMember.userId,
        name: name,
        relationship: relationship,
        age: age,
        gender: gender,
        medicalHistory: medicalHistory,
        isSynced: false
      );
      _familyMembers[index] = updatedMember;
      notifyListeners();
      await _db.insert('family_members', updatedMember.toSqlMap());
    }

    try {
      await ApiService.put('/family/$id', payload);
      await _refreshFamilyMembers();
    } catch (e) {
      print('Offline: Family member profile update queued. $e');
      await _db.addToSyncQueue('family_members', id, 'update', payload);
    }
  }

  Future<void> deleteFamilyMember(String id) async {
    _familyMembers.removeWhere((m) => m.id == id);
    if (_selectedFamilyMemberId == id) {
      _selectedFamilyMemberId = null;
    }
    notifyListeners();

    await _db.delete('family_members', id);

    // Deactivate local schedules belonging to the family member in database
    try {
      final schedulesToDeactivate = await _db.queryAll(
        'medicine_schedules',
        where: 'familyMemberId = ?',
        whereArgs: [id],
      );
      for (var s in schedulesToDeactivate) {
        final String sId = s['id'] ?? s['_id'] ?? '';
        if (sId.isNotEmpty) {
          await _db.update('medicine_schedules', {'isActive': 0}, sId);
          await NotificationService.cancelMedicineNotifications(sId);
        }
      }
    } catch (e) {
      print('Error deactivating local schedules: $e');
    }

    // Refresh active in-memory lists
    _schedules.removeWhere((s) => s.familyMemberId == id);

    try {
      await ApiService.delete('/family/$id');
      await refreshAllData();
    } catch (e) {
      print('Offline: Family member deletion queued. $e');
      await _db.addToSyncQueue('family_members', id, 'delete', {'id': id});
    }
  }

  // --- 5. Doctor Appointments tracker ---

  Future<void> fetchAppointments() async {
    await _refreshAppointments().catchError((_) => loadAllFromLocal());
  }

  Future<void> _refreshAppointments() async {
    final res = await ApiService.get('/appointments');
    if (res['success'] == true) {
      final List data = res['data'];
      final fetched = data.map((json) => AppointmentModel.fromJson(json)).toList();

      for (var appt in fetched) {
        await _db.insert('appointments', appt.toSqlMap());
      }

      _appointments = fetched;
      notifyListeners();
    }
  }

  Future<void> addAppointment(String doctorName, String specialty, DateTime dateTime, String venue, String notes) async {
    final localId = _uuid.v4();
    final payload = {
      'doctorName': doctorName,
      'specialty': specialty,
      'dateTime': dateTime.toIso8601String(),
      'venue': venue,
      'notes': notes
    };

    final localAppt = AppointmentModel(
      id: localId,
      userId: '',
      doctorName: doctorName,
      specialty: specialty,
      dateTime: dateTime,
      venue: venue,
      notes: notes,
      isSynced: false
    );

    _appointments.add(localAppt);
    notifyListeners();
    await _db.insert('appointments', localAppt.toSqlMap());

    try {
      await ApiService.post('/appointments', payload);
      await _refreshAppointments();
    } catch (e) {
      print('Offline: Appointment added locally and queued.');
      await _db.addToSyncQueue('appointments', localId, 'create', payload);
    }
  }

  // --- 6. Emergency SOS Contacts CRUD ---

  Future<void> fetchSOSContacts() async {
    await _refreshSOSContacts().catchError((_) => loadAllFromLocal());
  }

  Future<void> _refreshSOSContacts() async {
    final res = await ApiService.get('/sos');
    if (res['success'] == true) {
      final List data = res['data'];
      final fetched = data.map((json) => SOSContactModel.fromJson(json)).toList();

      for (var contact in fetched) {
        await _db.insert('sos_contacts', contact.toSqlMap());
      }

      _sosContacts = fetched;
      notifyListeners();
    }
  }

  Future<void> addSOSContact(String name, String phone, String relationship) async {
    final localId = _uuid.v4();
    final payload = {
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isEmergency': 'true'
    };

    final localContact = SOSContactModel(
      id: localId,
      userId: '',
      name: name,
      phone: phone,
      relationship: relationship,
      isEmergency: true,
      isSynced: false
    );

    _sosContacts.add(localContact);
    notifyListeners();
    await _db.insert('sos_contacts', localContact.toSqlMap());

    try {
      await ApiService.post('/sos', payload);
      await _refreshSOSContacts();
    } catch (e) {
      print('Offline: SOS Contact added locally and queued.');
      await _db.addToSyncQueue('sos_contacts', localId, 'create', payload);
    }
  }
}
