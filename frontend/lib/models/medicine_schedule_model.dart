import 'dart:convert';

class MedicineScheduleModel {
  final String id;
  final String userId;
  final String? familyMemberId;
  final String name;
  final String dosage;
  final String frequency;
  final List<String> specificDays;
  final int interval;
  final List<String> times;
  final DateTime startDate;
  final DateTime? endDate;
  final String instructions;
  final String imageUrl;
  final bool isActive;
  final bool isSynced;

  MedicineScheduleModel({
    required this.id,
    required this.userId,
    this.familyMemberId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.specificDays,
    required this.interval,
    required this.times,
    required this.startDate,
    this.endDate,
    required this.instructions,
    required this.imageUrl,
    required this.isActive,
    this.isSynced = true,
  });

  factory MedicineScheduleModel.fromJson(Map<String, dynamic> json) {
    List<String> days = [];
    if (json['specificDays'] != null) {
      if (json['specificDays'] is List) {
        days = List<String>.from(json['specificDays']);
      } else if (json['specificDays'] is String) {
        try {
          days = List<String>.from(jsonDecode(json['specificDays']));
        } catch (_) {
          days = (json['specificDays'] as String).split(',').where((s) => s.isNotEmpty).toList();
        }
      }
    }

    List<String> parsedTimes = [];
    if (json['times'] != null) {
      if (json['times'] is List) {
        parsedTimes = List<String>.from(json['times']);
      } else if (json['times'] is String) {
        try {
          parsedTimes = List<String>.from(jsonDecode(json['times']));
        } catch (_) {
          parsedTimes = (json['times'] as String).split(',').where((s) => s.isNotEmpty).toList();
        }
      }
    }

    // Handle nested populates from MongoDB if present
    String? fId;
    if (json['familyMemberId'] != null) {
      if (json['familyMemberId'] is Map) {
        fId = json['familyMemberId']['_id'];
      } else {
        fId = json['familyMemberId'].toString();
      }
    }

    return MedicineScheduleModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      familyMemberId: fId,
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? 'daily',
      specificDays: days,
      interval: json['interval'] ?? 1,
      times: parsedTimes,
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      instructions: json['instructions'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      isActive: json['isActive'] == 1 || json['isActive'] == true,
      isSynced: json['isSynced'] == null ? true : (json['isSynced'] == 1 || json['isSynced'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'familyMemberId': familyMemberId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'specificDays': jsonEncode(specificDays),
      'interval': interval,
      'times': jsonEncode(times),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'instructions': instructions,
      'imageUrl': imageUrl,
      'isActive': isActive ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  // To SQL-compatible map
  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'userId': userId,
      'familyMemberId': familyMemberId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'specificDays': specificDays.join(','),
      'interval': interval,
      'times': times.join(','),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'instructions': instructions,
      'imageUrl': imageUrl,
      'isActive': isActive ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
    };
  }
}
