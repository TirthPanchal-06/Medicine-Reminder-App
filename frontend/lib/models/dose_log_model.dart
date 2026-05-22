class DoseLogModel {
  final String id;
  final String scheduleId;
  final String userId;
  final String? familyMemberId;
  final DateTime dueTime;
  final DateTime? takenTime;
  final String status; // 'taken', 'missed', 'skipped'
  final bool isSynced;
  
  // Virtual fields populated from backend or DB joins
  final String? medicineName;
  final String? dosage;
  final String? instructions;
  final String? imageUrl;

  DoseLogModel({
    required this.id,
    required this.scheduleId,
    required this.userId,
    this.familyMemberId,
    required this.dueTime,
    this.takenTime,
    required this.status,
    this.isSynced = true,
    this.medicineName,
    this.dosage,
    this.instructions,
    this.imageUrl,
  });

  factory DoseLogModel.fromJson(Map<String, dynamic> json) {
    return DoseLogModel(
      id: json['_id'] ?? json['id'] ?? '',
      scheduleId: json['scheduleId'] ?? '',
      userId: json['userId'] ?? '',
      familyMemberId: json['familyMemberId']?.toString(),
      dueTime: DateTime.parse(json['dueTime'] ?? DateTime.now().toIso8601String()),
      takenTime: json['takenTime'] != null ? DateTime.parse(json['takenTime']) : null,
      status: json['status'] ?? 'missed',
      isSynced: json['isSynced'] == null ? true : (json['isSynced'] == 1 || json['isSynced'] == true),
      medicineName: json['medicineName'],
      dosage: json['dosage'],
      instructions: json['instructions'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'userId': userId,
      'familyMemberId': familyMemberId,
      'dueTime': dueTime.toIso8601String(),
      'takenTime': takenTime?.toIso8601String(),
      'status': status,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'userId': userId,
      'familyMemberId': familyMemberId,
      'dueTime': dueTime.toIso8601String(),
      'takenTime': takenTime?.toIso8601String(),
      'status': status,
      'isSynced': isSynced ? 1 : 0,
    };
  }
}
