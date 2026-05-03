import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/bill_provider.dart';

class BillEditScreen extends StatefulWidget {
  final int billId;
  const BillEditScreen({super.key, required this.billId});

  @override
  State<BillEditScreen> createState() => _BillEditScreenState();
}

class _BillEditScreenState extends State<BillEditScreen> {
  Map<String, dynamic>? _editData;
  bool _isLoading = true;
  bool _isSaving = false;
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  late TextEditingController _collectedCtrl;
  late TextEditingController _creditCtrl;
  late TextEditingController _notesCtrl;

  int? _selectedCustomerId;
  double _total = 0.0;
  double _subtotal = 0.0;

  List<Map<String, dynamic>> _items = [];
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _loadEditData();
  }

  @override
  void dispose() {
    _collectedCtrl.dispose();
    _creditCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEditData() async {
    setState(() => _isLoading = true);

    final editData = await context.read<BillProvider>().getBillForEdit(widget.billId);

    if (mounted) {
      if (editData != null) {
        final billData = editData['bill'] as Map<String, dynamic>;
        final customers = editData['customers'] as List<dynamic>;
        final products = editData['products'] as List<dynamic>;
        
        _selectedCustomerId = billData['customer']?['id'] as int?;
        final collectedAmount = (billData['collected_amount'] as num?)?.toDouble() ?? 0.0;
        final creditAmount = (billData['credit_amount'] as num?)?.toDouble() ?? 0.0;
        final notes = billData['notes'] as String? ?? '';
        _total = (billData['total'] as num?)?.toDouble() ?? 0.0;
        _subtotal = (billData['subtotal'] as num?)?.toDouble() ?? 0.0;

        _collectedCtrl = TextEditingController(text: collectedAmount == 0 ? '' : collectedAmount.toString());
        _creditCtrl = TextEditingController(text: creditAmount == 0 ? '' : creditAmount.toString());
        _notesCtrl = TextEditingController(text: notes);

        // Load bill items
        final items = billData['items'] as List<dynamic>? ?? [];
        _items = items.map((item) {
          final productId = item['product_id'];
          final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
          // Use is_custom_price from API directly instead of comparing prices
          // (product price may have changed since bill was created)
          final isCustomPrice = item['is_custom_price'] == true;
          
          return {
            'product_id': productId,
            'product_name': item['product_name'],
            'unit_type': item['unit_type'],
            'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
            'unit_price': unitPrice,
            'total': (item['total'] as num?)?.toDouble() ?? 0.0,
            'custom_price': isCustomPrice,
          };
        }).toList();

        _products = products;

        setState(() {
          _editData = editData;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to load bill data'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _calculateTotals() {
    _subtotal = 0.0;
    for (var item in _items) {
      _subtotal += (item['quantity'] as double) * (item['unit_price'] as double);
    }
    
    // No discount, total equals subtotal
    _total = _subtotal;
    
    // Update credit/collected based on new total
    final collected = double.tryParse(_collectedCtrl.text) ?? 0.0;
    final credit = (_total - collected).clamp(0.0, double.infinity);
    _creditCtrl.text = credit == 0 ? '' : credit.toStringAsFixed(2);
    
    setState(() {});
  }

  void _addItem() async {
    final selectedProducts = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProductSearchSheet(
        products: _products,
        initialSelectedIds: _items.where((i) => i['product_id'] != null).map((i) => i['product_id'] as int).toSet(),
      ),
    );

    if (selectedProducts != null && mounted) {
      final existingProductIds = _items.where((i) => i['product_id'] != null).map((i) => i['product_id'] as int).toSet();
      final returnedIds = selectedProducts.map((p) => p['id'] as int).toSet();

      setState(() {
        // Add newly selected products that aren't already in the list
        for (final product in selectedProducts) {
          if (!existingProductIds.contains(product['id'])) {
            final price = (product['price'] as num?)?.toDouble() ?? 0.0;
            _items.add({
              'product_id': product['id'],
              'product_name': product['name'],
              'unit_type': product['unit_type'],
              'quantity': 1.0,
              'unit_price': price,
              'total': price,
              'custom_price': false,
            });
          }
        }

        // Remove deselected products (were in list but not in returned selection)
        _items.removeWhere((item) {
          final pid = item['product_id'] as int?;
          return pid != null && existingProductIds.contains(pid) && !returnedIds.contains(pid);
        });

        _calculateTotals();
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateItem(int index, String field, dynamic value) {
    setState(() {
      _items[index][field] = value;
      if (field == 'quantity' || field == 'unit_price') {
        _items[index]['total'] = (_items[index]['quantity'] as double) * (_items[index]['unit_price'] as double);
      }
      if (field == 'unit_price') {
        // Check if price is custom compared to product default
        final productId = _items[index]['product_id'];
        if (productId != null) {
          final product = _products.firstWhere((p) => p['id'] == productId, orElse: () => null);
          if (product != null) {
            final defaultPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
            final newPrice = value as double;
            // Mark as custom only if price differs from current product default
            _items[index]['custom_price'] = (newPrice - defaultPrice).abs() > 0.01;
          }
        } else {
          _items[index]['custom_price'] = false;
        }
      }
      _calculateTotals();
    });
  }

  void _updateItemProduct(int index, int? productId) {
    if (productId == null) {
      _updateItem(index, 'product_id', null);
      _updateItem(index, 'product_name', '');
      _updateItem(index, 'unit_type', '');
      _updateItem(index, 'unit_price', 0.0);
      _updateItem(index, 'custom_price', false);
      return;
    }

    final product = _products.firstWhere((p) => p['id'] == productId, orElse: () => null);
    if (product != null) {
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      _updateItem(index, 'product_id', productId);
      _updateItem(index, 'product_name', product['name']);
      _updateItem(index, 'unit_type', product['unit_type']);
      _updateItem(index, 'unit_price', price);
      _updateItem(index, 'custom_price', false); // Reset custom flag when product changes
    }
  }

  Future<void> _saveBill() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final newCollected = double.tryParse(_collectedCtrl.text) ?? 0.0;
    final newCredit = double.tryParse(_creditCtrl.text) ?? 0.0;
    final newNotes = _notesCtrl.text;

    // Build items array
    final itemsData = _items.map((item) {
      return {
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
      };
    }).toList();

    final updated = await context.read<BillProvider>().updateBill(
      widget.billId,
      {
        'customer_id': _selectedCustomerId,
        'collected_amount': newCollected,
        'credit_amount': newCredit,
        'notes': newNotes,
        'items': itemsData,
      },
    );

    if (mounted) {
      setState(() => _isSaving = false);

      if (updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Bill updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to update bill'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Bill')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_editData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Bill')),
        body: const Center(child: Text('Failed to load bill data')),
      );
    }

    final customers = _editData!['customers'] as List<dynamic>;
    final theme = Theme.of(context);
    final bottomNavHeight = kBottomNavigationBarHeight;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final summaryPanelHeight = 180.0 + bottomNavHeight + systemBottom;
    final customerCreditBalance = _getCustomerCreditBalance(customers);
    final billCredit = (_total - (double.tryParse(_collectedCtrl.text) ?? 0)).clamp(0.0, double.infinity);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Bill')),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Customer selection
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedCustomerId == null
                              ? Colors.black.withOpacity(0.05)
                              : theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: _selectedCustomerId == null
                            ? Colors.transparent
                            : theme.colorScheme.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showCustomerDialog(customers),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _selectedCustomerId == null
                                      ? Colors.grey[100]
                                      : theme.colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _selectedCustomerId == null
                                      ? Icons.person_add_rounded
                                      : Icons.person_rounded,
                                  size: 20,
                                  color: _selectedCustomerId == null
                                      ? Colors.grey[600]
                                      : theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCustomerId == null
                                          ? 'Select Customer'
                                          : _getCustomerName(customers),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedCustomerId == null
                                            ? Colors.grey[600]
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (_selectedCustomerId == null)
                                      Text(
                                        'Required to edit bill',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      )
                                    else ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (customerCreditBalance != null && customerCreditBalance > 0) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Credit: ${_currency.format(customerCreditBalance)}',
                                                style: TextStyle(
                                                  color: Colors.orange[700],
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.search_rounded, color: Colors.grey[600], size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Add Product / Notes Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                          label: const Text('Add Product', style: TextStyle(fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showNotesDialog,
                          icon: const Icon(Icons.note_alt_rounded, size: 18),
                          label: const Text('Notes', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Items List
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                              ),
                              const SizedBox(height: 24),
                              Text('No items', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[800])),
                              const SizedBox(height: 8),
                              Text('Tap "Add Product" to add items', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: summaryPanelHeight),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _editItem(index),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.secondary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(Icons.inventory_2_rounded, color: theme.colorScheme.secondary, size: 20),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['product_name'] ?? 'Select Product',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    '${item['quantity'].toString()} × ${_currency.format(item['unit_price'])}',
                                                    style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                                                  ),
                                                  if (item['custom_price'] == true) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'Custom',
                                                        style: TextStyle(
                                                          color: Colors.orange,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _currency.format(item['total']),
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary),
                                            ),
                                            const SizedBox(height: 8),
                                            InkWell(
                                              onTap: () => _removeItem(index),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Padding(
                                                padding: const EdgeInsets.all(4),
                                                child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.red[400]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Floating Summary Panel
          if (_items.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.5), width: 2)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -10)),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SummaryRow('Total', _currency.format(_total), isBold: true, fontSize: 17),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: _setCollected,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: _SummaryRow(
                                  'Collected',
                                  _currency.format(double.tryParse(_collectedCtrl.text) ?? 0),
                                  actionIcon: Icons.edit_rounded,
                                  color: Colors.green[600],
                                  isBold: true,
                                ),
                              ),
                            ),
                            // Show credit for this bill (not customer credit balance)
                            if (billCredit > 0) ...[
                              const SizedBox(height: 2),
                              _SummaryRow(
                                'Credit',
                                _currency.format(billCredit),
                                color: Colors.red[700],
                                isBold: true,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _isSaving ? null : _saveBill,
                                    icon: _isSaving
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.save_rounded, size: 18),
                                    label: Text(_isSaving ? 'Saving...' : 'Update Bill'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getCustomerName(List<dynamic> customers) {
    if (_selectedCustomerId == null) return 'Select Customer';
    final customer = customers.firstWhere((c) => c['id'] == _selectedCustomerId, orElse: () => null);
    if (customer == null) return 'Unknown';
    return '${customer['name']}${customer['shop_name'] != null && customer['shop_name'].toString().isNotEmpty ? ' (${customer['shop_name']})' : ''}';
  }

  double? _getCustomerCreditBalance(List<dynamic> customers) {
    if (_selectedCustomerId == null) return null;
    final customer = customers.firstWhere((c) => c['id'] == _selectedCustomerId, orElse: () => null);
    if (customer == null) return null;
    return (customer['credit_balance'] as num?)?.toDouble();
  }

  void _showCustomerDialog(List<dynamic> customers) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Select Customer'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              final isSelected = customer['id'] == _selectedCustomerId;
              return ListTile(
                title: Text(customer['name']),
                subtitle: customer['shop_name'] != null ? Text(customer['shop_name']) : null,
                trailing: customer['credit_balance'] > 0
                    ? Text('Credit: ${_currency.format(customer['credit_balance'])}', style: const TextStyle(color: Colors.orange))
                    : null,
                selected: isSelected,
                onTap: () {
                  setState(() => _selectedCustomerId = customer['id']);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Notes'),
        content: TextField(
          controller: _notesCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter bill notes...',
            prefixIcon: Icon(Icons.note_alt_outlined),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Save')),
        ],
      ),
    );
  }

  void _editItem(index) {
    final item = _items[index];
    final qtyCtrl = TextEditingController(text: item['quantity'].toString());
    final priceCtrl = TextEditingController(text: item['unit_price'].toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers_rounded)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              decoration: InputDecoration(labelText: 'Unit Price', prefixText: '₹ ', prefixIcon: const Icon(Icons.payments_rounded)),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              _updateItem(index, 'quantity', double.tryParse(qtyCtrl.text) ?? 0);
              _updateItem(index, 'unit_price', double.tryParse(priceCtrl.text) ?? 0);
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _setCollected() {
    final currentVal = double.tryParse(_collectedCtrl.text) ?? _total;
    final displayText = currentVal == currentVal.truncateToDouble() ? currentVal.toInt().toString() : currentVal.toString();
    final ctrl = TextEditingController(text: displayText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Collected Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bill Total:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(_currency.format(_total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Amount Collected', prefixText: '₹ ', prefixIcon: Icon(Icons.payments_rounded)),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              _collectedCtrl.text = ctrl.text;
              final collected = double.tryParse(ctrl.text) ?? 0;
              final credit = (_total - collected).clamp(0.0, double.infinity);
              _creditCtrl.text = credit == 0 ? '' : credit.toStringAsFixed(2);
              setState(() {}); // Force UI update
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isBold;
  final double fontSize;
  final IconData? actionIcon;

  const _SummaryRow(
    this.label,
    this.value, {
    this.color,
    this.isBold = false,
    this.fontSize = 15,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
            if (actionIcon != null) ...[
              const SizedBox(width: 4),
              Icon(actionIcon, size: 16, color: color),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EditProductSearchSheet extends StatefulWidget {
  final List<dynamic> products;
  final Set<int> initialSelectedIds;
  const _EditProductSearchSheet({required this.products, this.initialSelectedIds = const {}});

  @override
  State<_EditProductSearchSheet> createState() => _EditProductSearchSheetState();
}

class _EditProductSearchSheetState extends State<_EditProductSearchSheet> {
  late final Set<int> _selectedIds = Set<int>.from(widget.initialSelectedIds);
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _searchCtrl = TextEditingController();
  List<dynamic> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = List.from(widget.products);
    _filteredProducts.sort((a, b) {
      final aSelected = _selectedIds.contains(a['id']);
      final bSelected = _selectedIds.contains(b['id']);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
    });
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(widget.products);
      } else {
        _filteredProducts = widget.products.where((p) =>
          (p['name'] as String).toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
      _filteredProducts.sort((a, b) {
        final aSelected = _selectedIds.contains(a['id']);
        final bSelected = _selectedIds.contains(b['id']);
        if (aSelected && !bSelected) return -1;
        if (!aSelected && bSelected) return 1;
        return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
      });
    });
  }

  void _toggleProduct(Map<String, dynamic> p) {
    setState(() {
      if (_selectedIds.contains(p['id'])) {
        _selectedIds.remove(p['id']);
      } else {
        _selectedIds.add(p['id'] as int);
      }
    });
  }

  void _confirm() {
    final selected = widget.products.where((p) => _selectedIds.contains(p['id'])).toList().cast<Map<String, dynamic>>();
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (_, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Products',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedIds.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: _filterProducts,
                ),
              ),
              Expanded(
                child: _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_rounded, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No products found', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (_, i) {
                        final p = _filteredProducts[i] as Map<String, dynamic>;
                        final isSelected = _selectedIds.contains(p['id']);
                        return Card(
                          elevation: 0,
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.08)
                              : Colors.grey[50],
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                                ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(0.15)
                                    : theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.inventory_2_rounded, color: theme.colorScheme.primary, size: 20),
                            ),
                            title: Text(
                              p['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${_currency.format((p['price'] as num?)?.toDouble() ?? 0)}${p['unit_type'] != null ? ' / ${p['unit_type']}' : ''}',
                            ),
                            trailing: isSelected
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!, width: 2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const SizedBox(width: 18, height: 18),
                                  ),
                            onTap: () => _toggleProduct(p),
                          ),
                        );
                      },
                    ),
              ),
              if (_selectedIds.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        '${_selectedIds.length} Product${_selectedIds.length > 1 ? 's' : ''} Selected',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
