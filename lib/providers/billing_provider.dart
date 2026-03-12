import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class BillingItem {
  Product product;
  double quantity;
  double unitPrice;
  double? customPrice;
  bool isCustomPrice;

  BillingItem({
    required this.product,
    this.quantity = 1,
    required this.unitPrice,
    this.customPrice,
    this.isCustomPrice = false,
  });

  double get effectivePrice => isCustomPrice ? (customPrice ?? unitPrice) : unitPrice;
  double get lineTotal => effectivePrice * quantity;

  Map<String, dynamic> toJson() => {
        'product_id': product.id,
        'quantity': quantity,
        'unit_price': unitPrice,
        'custom_price': customPrice,
        'is_custom_price': isCustomPrice,
      };
}

class BillingProvider with ChangeNotifier {
  List<BillingItem> _items = [];
  int? _customerId;
  String? _customerName;
  double _customerCreditBalance = 0;
  double _customerExtraAmount = 0;
  double _discount = 0;
  double _collectedAmount = 0;
  String _notes = '';
  bool _isLoading = false;
  String? _error;
  double _customerCreditBalance = 0;
  double _customerExtraAmount = 0;

  // Preview data from Step 1
  Map<String, dynamic>? _previewData;
  String? _previewToken;

  List<BillingItem> get items => _items;
  int? get customerId => _customerId;
  String? get customerName => _customerName;
  double get discount => _discount;
  double get collectedAmount => _collectedAmount;
  String get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;
<<<<<<< HEAD
=======
  Map<String, dynamic>? get previewData => _previewData;
  String? get previewToken => _previewToken;
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
  double get customerCreditBalance => _customerCreditBalance;
  double get customerExtraAmount => _customerExtraAmount;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  double get total => (subtotal - _discount).clamp(0, double.infinity);
  double get creditAmount => (total - _collectedAmount).clamp(0, double.infinity);

<<<<<<< HEAD
  void setCustomer(int id, String name, {double? creditBalance, double? extraAmount}) {
=======
  Future<void> setCustomer(int id, String name, {double? creditBalance, double? extraAmount}) async {
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
    _customerId = id;
    _customerName = name;
    _customerCreditBalance = creditBalance ?? 0;
    _customerExtraAmount = extraAmount ?? 0;
<<<<<<< HEAD
=======
    
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
    notifyListeners();
  }

  void clearCustomer() {
    _customerId = null;
    _customerName = null;
    _customerCreditBalance = 0;
    _customerExtraAmount = 0;
    notifyListeners();
  }

  void addItem(Product product) {
    final existing = _items.indexWhere((e) => e.product.id == product.id);
    if (existing >= 0) {
      _items[existing].quantity++;
    } else {
      _items.add(BillingItem(product: product, unitPrice: product.price));
    }
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(int index, double qty) {
    if (index < _items.length) {
      _items[index].quantity = qty;
      notifyListeners();
    }
  }

  void updateCustomPrice(int index, double? price) {
    if (index < _items.length) {
      _items[index].customPrice = price;
      _items[index].isCustomPrice = price != null;
      notifyListeners();
    }
  }

  void setDiscount(double val) {
    _discount = val;
    notifyListeners();
  }

  void setCollectedAmount(double val) {
    _collectedAmount = val;
    notifyListeners();
  }

  void setNotes(String val) {
    _notes = val;
  }

  void clearBill() {
    _items = [];
    _customerId = null;
    _customerName = null;
    _discount = 0;
    _collectedAmount = 0;
    _notes = '';
    _error = null;
    _previewData = null;
    _previewToken = null;
    notifyListeners();
  }

  /// Step 1: Preview the bill - returns preview data + preview_token
  Future<Map<String, dynamic>?> previewBill() async {
    if (_customerId == null || _items.isEmpty) {
      _error = 'Select a customer and add at least one item';
      notifyListeners();
      return null;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final body = {
        'customer_id': _customerId,
        'items': _items.map((e) => e.toJson()).toList(),
        'discount': _discount,
        'collected_amount': _collectedAmount,
        'notes': _notes,
      };
      final response = await ApiService.post('/billing/preview', body: body);
      _previewData = response['data'];
      _previewToken = response['preview_token'];
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Step 2: Finalize the bill using preview_token
  Future<Map<String, dynamic>?> finalizeBill() async {
    if (_previewToken == null) {
      _error = 'No preview token. Please preview the bill first.';
      notifyListeners();
      return null;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/billing/finalize', body: {
        'preview_token': _previewToken,
      });
      _isLoading = false;
      final billData = response['data'];
      clearBill();
      return billData;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
