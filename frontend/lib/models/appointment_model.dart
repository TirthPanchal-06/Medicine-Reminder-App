class AppointmentModel {
  final String id;
  final String userId;
  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String venue;
  final String notes;
  final bool isSynced;

  AppointmentModel({
    required this.id,
    required this.userId,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.venue,
    required this.notes,
    this.isSynced = true,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      doctorName: json['doctorName'] ?? '',
      specialty: json['specialty'] ?? '',
      dateTime: DateTime.parse(json['dateTime'] ?? DateTime.now().toIso8601String()),
      venue: json['venue'] ?? '',
      notes: json['notes'] ?? '',
      isSynced: json['isSynced'] == null ? true : (json['isSynced'] == 1 || json['isSynced'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'doctorName': doctorName,
      'specialty': specialty,
      'dateTime': dateTime.toIso8601String(),
      'venue': venue,
      'notes': notes,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'userId': userId,
      'doctorName': doctorName,
      'specialty': specialty,
      'dateTime': dateTime.toIso8601String(),
      'venue': venue,
      'notes': notes,
      'isSynced': isSynced ? 1 : 0,
    };
  }
}
