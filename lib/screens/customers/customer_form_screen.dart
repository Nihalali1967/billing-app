import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;
  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _mobileSecondaryCtrl;
  late final TextEditingController _locationCtrl;
<<<<<<< HEAD
  late final TextEditingController _creditBalanceCtrl;
=======
  late final TextEditingController _creditAmountCtrl;
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
  late final TextEditingController _extraAmountCtrl;
  bool _isLoading = false;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _shopNameCtrl = TextEditingController(text: c?.shopName ?? '');
    _mobileCtrl = TextEditingController(text: c?.mobile ?? '');
    _mobileSecondaryCtrl =
        TextEditingController(text: c?.mobileSecondary ?? '');
    _locationCtrl = TextEditingController(text: c?.location ?? '');
<<<<<<< HEAD
    _creditBalanceCtrl = TextEditingController(text: c?.creditBalance.toString() ?? '0');
=======
    _creditAmountCtrl = TextEditingController(text: c?.creditBalance.toString() ?? '0');
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
    _extraAmountCtrl = TextEditingController(text: c?.extraAmount.toString() ?? '0');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shopNameCtrl.dispose();
    _mobileCtrl.dispose();
    _mobileSecondaryCtrl.dispose();
    _locationCtrl.dispose();
<<<<<<< HEAD
    _creditBalanceCtrl.dispose();
=======
    _creditAmountCtrl.dispose();
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
    _extraAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'mobile': _mobileCtrl.text.trim(),
    };

    if (_shopNameCtrl.text.isNotEmpty) {
      data['shop_name'] = _shopNameCtrl.text.trim();
    }
    if (_mobileSecondaryCtrl.text.isNotEmpty) {
      data['mobile_secondary'] = _mobileSecondaryCtrl.text.trim();
    }
    if (_locationCtrl.text.isNotEmpty) {
      data['location'] = _locationCtrl.text.trim();
    }
    
<<<<<<< HEAD
    // Add credit balance and extra amount
    final creditBalance = double.tryParse(_creditBalanceCtrl.text) ?? 0;
    final extraAmount = double.tryParse(_extraAmountCtrl.text) ?? 0;
    if (creditBalance > 0) {
      data['credit_balance'] = creditBalance;
    }
    if (extraAmount > 0) {
=======
    // Add credit and extra amounts
    final creditAmount = double.tryParse(_creditAmountCtrl.text) ?? 0;
    final extraAmount = double.tryParse(_extraAmountCtrl.text) ?? 0;
    if (creditAmount != 0) {
      data['credit_balance'] = creditAmount;
    }
    if (extraAmount != 0) {
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
      data['extra_amount'] = extraAmount;
    }

    final provider = context.read<CustomerProvider>();
    bool success;
    if (isEditing) {
      success = await provider.update(widget.customer!.id, data);
    } else {
      success = await provider.create(data);
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save customer'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'New Customer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _shopNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop Name',
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _mobileCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Primary Mobile *',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mobileSecondaryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Secondary Mobile',
                      prefixIcon: Icon(Icons.phone_android_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address / Location',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 24),
            
<<<<<<< HEAD
            // Credit & Extra Balance Section
=======
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
<<<<<<< HEAD
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
=======
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
<<<<<<< HEAD
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Account Balance',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Set initial credit balance or extra amount for this customer',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  
                  // Credit Balance Field
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, color: Colors.orange[700], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Credit Balance',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _creditBalanceCtrl,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: '₹ ',
                            helperText: 'Amount customer owes (credit)',
                            helperStyle: TextStyle(color: Colors.orange[600], fontSize: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.orange.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Extra Amount Field
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: Colors.green[700], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Extra Amount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _extraAmountCtrl,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: '₹ ',
                            helperText: 'Advance payment by customer',
                            helperStyle: TextStyle(color: Colors.green[600], fontSize: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
=======
                  Text(
                    'Financial Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _creditAmountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Credit Balance',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      hintText: '0.00',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final value = double.tryParse(v);
                      if (value == null) return 'Enter a valid number';
                      if (value < 0) return 'Credit balance cannot be negative';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _extraAmountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Extra Amount',
                      prefixIcon: Icon(Icons.add_circle_outline),
                      hintText: '0.00',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final value = double.tryParse(v);
                      if (value == null) return 'Enter a valid number';
                      if (value < 0) return 'Extra amount cannot be negative';
                      return null;
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
            
            const SizedBox(height: 32),
            
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        isEditing ? 'Update Customer' : 'Create Customer',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ).animate().fadeIn(delay: 400.ms).scale(),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
