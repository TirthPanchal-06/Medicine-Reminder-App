import 'dart:convert';

class HealthRecordModel {
  final String id;
  final String userId;
  final String? familyMemberId;
  final String type; // 'blood_pressure', 'blood_sugar', 'weight', 'heart_rate'
  final Map<String, dynamic> value;
  final DateTime timestamp;
  final bool isSynced;

  HealthRecordModel({
    required this.id,
    required this.userId,
    this.familyMemberId,
    required this.type,
    required this.value,
    required this.timestamp,
    this.isSynced = true,
  });

  factory HealthRecordModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedVal = {};
    if (json['value'] != null) {
      if (json['value'] is Map) {
        parsedVal = Map<String, dynamic>.from(json['value']);
      } else if (json['value'] is String) {
        try {
          parsedVal = Map<String, dynamic>.from(jsonDecode(json['value']));
        } catch (_) {
          // Fallback if not a json map
          parsedVal = {'value': json['value']};
        }
      } else {
        parsedVal = {'value': json['value']};
      }
    }

    return HealthRecordModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      familyMemberId: json['familyMemberId']?.toString(),
      type: json['type'] ?? '',
      value: parsedVal,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isSynced: json['isSynced'] == null ? true : (json['isSynced'] == 1 || json['isSynced'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'familyMemberId': familyMemberId,
      'type': type,
      'value': jsonEncode(value),
      'timestamp': timestamp.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'userId': userId,
      'familyMemberId': familyMemberId,
      'type': type,
      'value': jsonEncode(value),
      'timestamp': timestamp.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  // Helper getters for easy UI display
  String get displayValue {
    switch (type) {
      case 'blood_pressure':
        return '${value['systolic']}/${value['diastolic']} mmHg';
      case 'blood_sugar':
        final mealType = value['mealType'] ?? 'random';
        return '${value['value']} mg/dL ($mealType)';
      case 'weight':
        return '${value['value']} ${value['unit'] ?? 'kg'}';
      case 'heart_rate':
        return '${value['value']} bpm';
      default:
        return value.toString();
    }
  }
}
