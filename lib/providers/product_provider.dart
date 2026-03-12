import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  bool get hasMore => _currentPage < _lastPage;

  Future<void> fetch({String? search, bool activeOnly = false, int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{'page': page.toString(), 'per_page': '15'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (activeOnly) params['active_only'] = '1';
      final response = await ApiService.get('/products', queryParams: params);
      debugPrint('Products API response: $response');
      
      // Handle different response structures
      List<dynamic> productsList;
      Map<String, dynamic> meta = {};
      
      if (response['data'] is List) {
        // Direct list: { "data": [...] }
        productsList = response['data'] as List;
      } else if (response['data'] is Map) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['products'] is Map) {
          // Nested: { "data": { "products": { "data": [...] } } }
          final productsPaginated = data['products'] as Map<String, dynamic>;
          productsList = productsPaginated['data'] as List? ?? [];
          meta = productsPaginated;
        } else if (data['data'] is List) {
          // Laravel style: { "data": { "data": [...] } }
          productsList = data['data'] as List;
          meta = data;
        } else {
          productsList = [];
        }
      } else {
        productsList = [];
      }

      _products = productsList.map((e) => Product.fromJson(e)).toList();
      _currentPage = meta['current_page'] ?? 1;
      _lastPage = meta['last_page'] ?? 1;
      _total = meta['total'] ?? _products.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Product?> getProduct(int id) async {
    try {
      final response = await ApiService.get('/products/$id');
      return Product.fromJson(response['data']);
    } catch (_) {
      return null;
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await ApiService.post('/products', body: data);
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
      await ApiService.put('/products/$id', body: data);
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await ApiService.delete('/products/$id');
      await fetch();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Product>> search(String query) async {
    try {
      final response = await ApiService.get('/products/search', queryParams: {'search': query});
      return (response['data'] as List)
          .map((e) => Product.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
