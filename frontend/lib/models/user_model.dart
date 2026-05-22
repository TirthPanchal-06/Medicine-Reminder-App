class UserModel {
  final String id;
  final String name;
  final String email;
  final String token;
  final String role;
  final bool darkMode;
  final String language;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    required this.role,
    required this.darkMode,
    required this.language,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String token) {
    final settings = json['settings'] ?? {};
    return UserModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      token: token,
      role: json['role'] ?? 'user',
      darkMode: settings['darkMode'] ?? false,
      language: settings['language'] ?? 'en',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'role': role,
      'settings': {
        'darkMode': darkMode,
        'language': language,
      }
    };
  }
}
