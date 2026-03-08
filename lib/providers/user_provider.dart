import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  List<User> _users = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;

  List<User> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;

  Future<void> fetch({String? search, int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': '15',
      };
      if (search != null && search.isNotEmpty) params['search'] = search;
      final response = await ApiService.get('/users', queryParams: params);
      debugPrint('Users API response: $response');
      
      // Handle different response structures
      List<dynamic> usersList;
      Map<String, dynamic> meta = {};
      
      if (response['data'] is List) {
        usersList = response['data'] as List;
      } else if (response['data'] is Map) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['users'] is Map) {
          final usersPaginated = data['users'] as Map<String, dynamic>;
          usersList = usersPaginated['data'] as List? ?? [];
          meta = usersPaginated;
        } else if (data['data'] is List) {
          usersList = data['data'] as List;
          meta = data;
        } else {
          usersList = [];
        }
      } else {
        usersList = [];
      }

      _users = usersList.map((e) => User.fromJson(e)).toList();
      _currentPage = meta['current_page'] ?? 1;
      _lastPage = meta['last_page'] ?? 1;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<User?> getUser(int id) async {
    try {
      final response = await ApiService.get('/users/$id');
      return User.fromJson(response['data']);
    } catch (_) {
      return null;
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await ApiService.post('/users', body: data);
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    try {
      await ApiService.put('/users/$id', body: data);
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await ApiService.delete('/users/$id');
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
