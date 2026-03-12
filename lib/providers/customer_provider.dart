import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  bool get hasMore => _currentPage < _lastPage;

  Future<void> fetch({String? search, int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{'page': page.toString(), 'per_page': '15'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final response = await ApiService.get('/customers', queryParams: params);
      debugPrint('Customers API response: $response');
      
      // Handle different response structures
      List<dynamic> customersList;
      Map<String, dynamic> meta = {};
      
      if (response['data'] is List) {
        customersList = response['data'] as List;
      } else if (response['data'] is Map) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['customers'] is Map) {
          final customersPaginated = data['customers'] as Map<String, dynamic>;
          customersList = customersPaginated['data'] as List? ?? [];
          meta = customersPaginated;
        } else if (data['data'] is List) {
          customersList = data['data'] as List;
          meta = data;
        } else {
          customersList = [];
        }
      } else {
        customersList = [];
      }

      _customers = customersList.map((e) => Customer.fromJson(e)).toList();
      _currentPage = meta['current_page'] ?? 1;
      _lastPage = meta['last_page'] ?? 1;
      _total = meta['total'] ?? _customers.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getCustomer(int id) async {
    try {
      final response = await ApiService.get('/customers/$id');
      debugPrint('Customer detail API response: $response');
      return response['data'];
    } catch (_) {
      return null;
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await ApiService.post('/customers', body: data);
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
      await ApiService.put('/customers/$id', body: data);
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    try {
      await ApiService.delete('/customers/$id');
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Customer>> search(String query) async {
    try {
      final response =
          await ApiService.get('/customers/search', queryParams: {'search': query});
      final data = response['data'];
      if (data is List) {
        return data.map((e) => Customer.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
