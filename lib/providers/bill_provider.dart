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
  Map<String, dynamic> _summary = {};

  List<Bill> get bills => _bills;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  Map<String, dynamic> get summary => _summary;
  bool get hasMore => _currentPage < _lastPage;

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
      final params = <String, String>{
        'page': page.toString(),
        'per_page': '20',
      };
      if (dateFrom != null) params['date_from'] = dateFrom;
      if (dateTo != null) params['date_to'] = dateTo;
      if (customerId != null) params['customer_id'] = customerId.toString();
      if (userId != null) params['user_id'] = userId.toString();
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await ApiService.get('/bills', queryParams: params);
      _bills =
          (response['data'] as List).map((e) => Bill.fromJson(e)).toList();
      final meta = response['meta'] ?? {};
      _summary = meta['summary'] != null
          ? Map<String, dynamic>.from(meta['summary'])
          : {};
      _currentPage = meta['current_page'] ?? 1;
      _lastPage = meta['last_page'] ?? 1;
      _total = meta['total'] ?? _bills.length;
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
      return Bill.fromJson(response['data']);
    } catch (_) {
      return null;
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
}
