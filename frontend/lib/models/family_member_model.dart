class FamilyMemberModel {
  final String id;
  final String userId;
  final String name;
  final String relationship; // 'parent', 'child', 'spouse', 'sibling', 'other'
  final int? age;
  final String? gender;
  final String medicalHistory;
  final bool isSynced;

  FamilyMemberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    this.age,
    this.gender,
    required this.medicalHistory,
    this.isSynced = true,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? 'other',
      age: json['age'] != null ? int.tryParse(json['age'].toString()) : null,
      gender: json['gender'],
      medicalHistory: json['medicalHistory'] ?? '',
      isSynced: json['isSynced'] == null ? true : (json['isSynced'] == 1 || json['isSynced'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'relationship': relationship,
      'age': age,
      'gender': gender,
      'medicalHistory': medicalHistory,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'relationship': relationship,
      'age': age,
      'gender': gender,
      'medicalHistory': medicalHistory,
      'isSynced': isSynced ? 1 : 0,
    };
  }
}
