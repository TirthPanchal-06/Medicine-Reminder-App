import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';
import '../services/web_helper.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _darkMode = false;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get darkMode => _darkMode;

  AuthProvider() {
    _loadSession();
  }

  void _setupPushNotifications(String token) {
    if (kIsWeb) {
      enableWebNotifications(token);
    }
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    _darkMode = prefs.getBool('dark_mode') ?? false;
    notifyListeners();

    if (token != null) {
      _setupPushNotifications(token);
      try {
        final res = await ApiService.get('/auth/profile');
        if (res['success'] == true) {
          _user = UserModel.fromJson(res['data'], token);
          _darkMode = _user!.darkMode;
          prefs.setBool('dark_mode', _darkMode);
        }
      } catch (_) {
        // Offline or token expired; clear session
        _user = null;
      }
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.post('/auth/register', {
        'name': name,
        'email': email,
        'password': password,
      });

      if (res['success'] == true) {
        final data = res['data'];
        final token = data['token'];
        _setupPushNotifications(token);
        _user = UserModel.fromJson(data, token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        _darkMode = _user!.darkMode;
        await prefs.setBool('dark_mode', _darkMode);

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (res['success'] == true) {
        final data = res['data'];
        final token = data['token'];
        _setupPushNotifications(token);
        _user = UserModel.fromJson(data, token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        _darkMode = _user!.darkMode;
        await prefs.setBool('dark_mode', _darkMode);

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> toggleTheme() async {
    _darkMode = !_darkMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);

    if (isAuthenticated) {
      try {
        await ApiService.put('/auth/settings', {'darkMode': _darkMode});
      } catch (_) {
        // Silently fail if offline, setting will sync upon next manual updates
      }
    }
  }

  Future<void> updateProfile(String name) async {
    if (!isAuthenticated) return;
    try {
      final res = await ApiService.put('/auth/settings', {'name': name});
      if (res['success'] == true) {
        _user = UserModel(
          id: _user!.id,
          name: name,
          email: _user!.email,
          token: _user!.token,
          role: _user!.role,
          darkMode: _user!.darkMode,
          language: _user!.language,
        );
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await DBHelper().clearDatabase();
    notifyListeners();
  }
}
