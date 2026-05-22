class SOSContactModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String relationship;
  final bool isEmergency;
  final bool isSynced;

  SOSContactModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.relationship,
    this.isEmergency = true,
    this.isSynced = true,
  });

  factory SOSContactModel.fromJson(Map<String, dynamic> json) {
    return SOSContactModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? '',
      isEmergency: json['isEmergency'] == 1 || json['isEmergency'] == true,
      isSynced: json['isSynced'] == null ? true : (json['isSynced'] == 1 || json['isSynced'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isEmergency': isEmergency ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isEmergency': isEmergency ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
    };
  }
}
