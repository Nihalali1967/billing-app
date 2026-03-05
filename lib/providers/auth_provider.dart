import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => ApiService.isLoggedIn && _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<bool> tryAutoLogin() async {
    await ApiService.loadToken();
    if (!ApiService.isLoggedIn) return false;
    try {
      final response = await ApiService.get('/profile');
      _user = User.fromJson(response['data']);
      notifyListeners();
      return true;
    } catch (e) {
      await ApiService.clearToken();
      return false;
    }
  }

  Future<bool> login(String login, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/login', body: {
        'login': login,
        'password': password,
        'device_name': 'flutter-app',
      });
      final data = response['data'];
      await ApiService.saveToken(data['token']);
      _user = User.fromJson(data['user']);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.post('/logout');
    } catch (_) {}
    _user = null;
    await ApiService.clearToken();
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    try {
      final response = await ApiService.get('/profile');
      _user = User.fromJson(response['data']);
      notifyListeners();
    } catch (_) {}
  }
}
