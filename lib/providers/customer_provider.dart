import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;
  int _total = 0;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get total => _total;

  Future<void> fetch({String? search}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{'per_page': '1000'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final response = await ApiService.get('/customers', queryParams: params);
      _customers = (response['data'] as List)
          .map((e) => Customer.fromJson(e))
          .toList();
      _total = _customers.length;
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
      // Fetch existing customer data first to include required fields
      final existingCustomer = await getCustomer(id);
      if (existingCustomer == null) {
        print('Customer $id not found');
        return false;
      }

      // Merge existing data with new data
      final updateData = {
        'name': existingCustomer['name'] ?? '',
        'shop_name': existingCustomer['shop_name'] ?? '',
        'mobile': existingCustomer['mobile'] ?? '',
        'location': existingCustomer['location'] ?? '',
        ...data,
      };

      print('Updating customer $id with data: $updateData');
      final response = await ApiService.post('/customers/$id', body: updateData);
      print('Update response: $response');
      await fetch();
      return true;
    } catch (e) {
      print('Customer update error: $e');
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

  Future<List<Customer>> fetchAll() async {
    try {
      final response = await ApiService.get('/customers', queryParams: {'per_page': '1000'});
      final data = response['data'];
      if (data is List) {
        return data.map((e) => Customer.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
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
