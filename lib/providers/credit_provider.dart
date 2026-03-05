import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';

class CreditProvider with ChangeNotifier {
  List<Customer> _creditCustomers = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  double _totalCredit = 0;

  List<Customer> get creditCustomers => _creditCustomers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  double get totalCredit => _totalCredit;

  Future<void> fetch({String? search, int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': '20',
      };
      if (search != null && search.isNotEmpty) params['search'] = search;
      final response = await ApiService.get('/credits', queryParams: params);
      _creditCustomers = (response['data'] as List)
          .map((e) => Customer.fromJson(e))
          .toList();
      _totalCredit =
          (response['summary']?['total_credit'] ?? 0).toDouble();
      final meta = response['meta'] ?? {};
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

  Future<Map<String, dynamic>?> getCustomerCredit(int customerId) async {
    try {
      final response = await ApiService.get('/credits/$customerId');
      return response['data'];
    } catch (_) {
      return null;
    }
  }

  Future<bool> recordPayment(int customerId, double amount, String? notes) async {
    try {
      await ApiService.post('/credits/$customerId/payment', body: {
        'amount': amount,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> adjustCredit(
      int customerId, double amount, String type, String? notes) async {
    try {
      await ApiService.post('/credits/$customerId/adjust', body: {
        'amount': amount,
        'type': type,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
