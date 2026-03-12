import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../services/api_service.dart';

class BillProvider with ChangeNotifier {
  List<Bill> _bills = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  List<Map<String, dynamic>> _filterCustomers = [];
  List<Map<String, dynamic>> _filterUsers = [];

  List<Bill> get bills => _bills;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  bool get hasMore => _currentPage < _lastPage;
  List<Map<String, dynamic>> get filterCustomers => _filterCustomers;
  List<Map<String, dynamic>> get filterUsers => _filterUsers;

  Future<void> fetch({
    String? dateFrom,
    String? dateTo,
    int? customerId,
    int? userId,
    String? search,
    int page = 1,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{'page': page.toString()};
      if (dateFrom != null) params['date_from'] = dateFrom;
      if (dateTo != null) params['date_to'] = dateTo;
      if (customerId != null) params['customer_id'] = customerId.toString();
      if (userId != null) params['user_id'] = userId.toString();
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await ApiService.get('/bills', queryParams: params);
<<<<<<< HEAD
      final data = response['data'] ?? {};
      final billsPaginated = data['bills'] ?? {};
      final billsList = billsPaginated['data'] as List? ?? [];

      _bills = billsList.map((e) => Bill.fromListJson(e)).toList();
      _currentPage = billsPaginated['current_page'] ?? 1;
      _lastPage = billsPaginated['last_page'] ?? 1;
      _total = billsPaginated['total'] ?? _bills.length;

      final filterOptions = data['filter_options'] ?? {};
      _filterCustomers = List<Map<String, dynamic>>.from(filterOptions['customers'] ?? []);
      _filterUsers = List<Map<String, dynamic>>.from(filterOptions['users'] ?? []);

=======
      _bills =
          (response['data'] as List).map((e) => Bill.fromJson(e)).toList();
      final meta = response['meta'] ?? {};
      _summary = meta['summary'] != null
          ? Map<String, dynamic>.from(meta['summary'])
          : {};
      _currentPage = meta['current_page'] ?? 1;
      _lastPage = meta['last_page'] ?? 1;
      _total = meta['total'] ?? _bills.length;
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Bill?> getBill(int id) async {
    try {
      final response = await ApiService.get('/bills/$id');
      return Bill.fromDetailJson(response['data']);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWhatsAppData(int id) async {
    try {
      final response = await ApiService.get('/bills/$id/whatsapp');
      return response['data'];
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteBill(int id) async {
    try {
      await ApiService.delete('/bills/$id');
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPrintData(int id) async {
    try {
      final response = await ApiService.get('/bills/$id/print');
      return response['data'];
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> exportBills({
    String? dateFrom,
    String? dateTo,
    int? customerId,
  }) async {
    try {
      final params = <String, String>{};
      if (dateFrom != null) params['date_from'] = dateFrom;
      if (dateTo != null) params['date_to'] = dateTo;
      if (customerId != null) params['customer_id'] = customerId.toString();

      final response = await ApiService.get('/bills/export', queryParams: params);
      return response['data'] ?? [];
    } catch (_) {
      return [];
    }
  }
}
