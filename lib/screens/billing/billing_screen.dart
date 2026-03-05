import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../providers/billing_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  Future<void> _selectCustomer() async {
    final customer = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomerSearchSheet(),
    );
    if (customer != null && mounted) {
      context.read<BillingProvider>().setCustomer(customer.id, customer.name);
    }
  }

  Future<void> _addProduct() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProductSearchSheet(),
    );
    if (product != null && mounted) {
      context.read<BillingProvider>().addItem(product);
    }
  }

  void _editItem(int index) {
    final billing = context.read<BillingProvider>();
    final item = billing.items[index];
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final priceCtrl = TextEditingController(text: item.customPrice?.toString() ?? '');

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
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              decoration: InputDecoration(
                labelText: 'Custom Price',
                hintText: 'Default: ${_currency.format(item.unitPrice)}',
                prefixText: '₹ ',
                prefixIcon: const Icon(Icons.payments_rounded),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text) ?? item.quantity;
              billing.updateQuantity(index, qty);
              final customPrice = double.tryParse(priceCtrl.text);
              billing.updateCustomPrice(index, customPrice);
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _setDiscount() {
    final billing = context.read<BillingProvider>();
    final ctrl = TextEditingController(text: billing.discount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Discount'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Discount Amount',
            prefixText: '₹ ',
            prefixIcon: Icon(Icons.local_offer_rounded),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              billing.setDiscount(double.tryParse(ctrl.text) ?? 0);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _setCollected() {
    final billing = context.read<BillingProvider>();
    final ctrl = TextEditingController(text: billing.total.toStringAsFixed(2));
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
                  Text('Bill Total:', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                  Text(_currency.format(billing.total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Amount Collected',
                prefixText: '₹ ',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              billing.setCollectedAmount(double.tryParse(ctrl.text) ?? 0);
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBill() async {
    final billing = context.read<BillingProvider>();
    if (billing.customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.warning_rounded, color: Colors.white), SizedBox(width: 8), Text('Please select a customer')]),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (billing.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.warning_rounded, color: Colors.white), SizedBox(width: 8), Text('Add at least one product')]),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirm Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow('Customer', billing.customerName ?? '', icon: Icons.person_rounded),
            _SummaryRow('Items', billing.items.length.toString(), icon: Icons.inventory_2_rounded),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
            _SummaryRow('Total', _currency.format(billing.total), isBold: true, icon: Icons.receipt_long_rounded),
            _SummaryRow('Collected', _currency.format(billing.collectedAmount), color: Colors.green, isBold: true, icon: Icons.payments_rounded),
            if (billing.creditAmount > 0)
              _SummaryRow('Credit', _currency.format(billing.creditAmount), color: Colors.orange[700], isBold: true, icon: Icons.credit_score_rounded),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Create Bill')),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await billing.submitBill();
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Bill ${result['bill_number'] ?? ''} created successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (billing.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(billing.error!))]),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingProvider>();
    final theme = Theme.of(context);

    // ── FIX: measure bottom nav bar + system bottom inset so the
    //   floating summary and list padding always clear both.
    final bottomNavHeight = kBottomNavigationBarHeight;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    // Extra room so the last list item is never hidden behind the panel.
    // 320 was hardcoded before; now we derive it from the actual widget.
    // We use a GlobalKey approach-free estimate: the panel is roughly 300 dp
    // tall (content) + bottomNavHeight + systemBottom.
    final summaryPanelHeight = 220.0 + bottomNavHeight + systemBottom;

    return Stack(
      children: [
        // Premium Background
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withOpacity(0.05),
            ),
          ),
        ),

        // ── FIX: wrap the main Column in SafeArea so content respects
        //   system insets (status bar, bottom gesture area).
        SafeArea(
          // bottom: false because the floating panel handles its own SafeArea.
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
                        color: billing.customerId == null
                            ? Colors.black.withOpacity(0.05)
                            : theme.colorScheme.primary.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: billing.customerId == null
                          ? Colors.transparent
                          : theme.colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _selectCustomer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: billing.customerId == null
                                    ? Colors.grey[100]
                                    : theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                billing.customerId == null
                                    ? Icons.person_add_rounded
                                    : Icons.person_rounded,
                                size: 20,
                                color: billing.customerId == null
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
                                    billing.customerId == null
                                        ? 'Select Customer'
                                        : billing.customerName!,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: billing.customerId == null
                                          ? Colors.grey[600]
                                          : Colors.black87,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  if (billing.customerId == null)
                                    Text('Required to create a bill',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
                ).animate().fadeIn().slideY(begin: -0.1),
              ),

              // Add Product / Notes Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _addProduct,
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
                        onPressed: () {
                          final ctrl = TextEditingController(text: billing.notes);
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              title: const Text('Notes'),
                              content: TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(
                                  hintText: 'Enter bill notes...',
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(bottom: 48),
                                    child: Icon(Icons.note_alt_outlined),
                                  ),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 3,
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () {
                                    billing.setNotes(ctrl.text);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.note_alt_rounded, size: 18),
                        label: const Text('Notes', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
              ),

              const SizedBox(height: 8),

              // ── FIX: Cart Items list inside Expanded so it fills remaining
              //   vertical space correctly inside the Column, then we add
              //   bottom padding equal to the floating panel height so the
              //   last item is always reachable above the panel.
              Expanded(
                child: billing.items.isEmpty
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
                              child: Icon(Icons.shopping_cart_outlined,
                                  size: 64, color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 24),
                            Text('Cart is empty',
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800])),
                            const SizedBox(height: 8),
                            Text('Tap "Add Product" to start billing',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms).scale()
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 8,
                          // ── FIX: use dynamic padding = floating panel height
                          //   so the last item scrolls fully above the panel.
                          bottom: summaryPanelHeight,
                        ),
                        itemCount: billing.items.length,
                        itemBuilder: (context, index) {
                          final item = billing.items[index];
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
                                    child: Icon(Icons.inventory_2_rounded,
                                        color: theme.colorScheme.secondary, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.product.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '${item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 2)} × ${_currency.format(item.effectivePrice)}',
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            if (item.customPrice != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: Colors.orange.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4)),
                                                child: const Text('Custom Price',
                                                    style: TextStyle(
                                                        color: Colors.orange,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold)),
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
                                        _currency.format(item.lineTotal),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: theme.colorScheme.primary),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () => _editItem(index),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(Icons.edit_rounded,
                                                  size: 18, color: Colors.grey[600]),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () => billing.removeItem(index),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(Icons.remove_circle_outline_rounded,
                                                  size: 18, color: Colors.red[400]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn().slideX(begin: 0.1);
                        },
                      ),
              ),
            ],
          ),
        ),

        // Floating Bill Summary
        if (billing.items.isNotEmpty)
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
                    border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.5), width: 2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  // ── FIX: SafeArea wraps the panel content so the Complete Bill
                  //   button and bottom padding respect the device's bottom
                  //   system UI (home indicator / nav bar).
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SummaryRow('Subtotal', _currency.format(billing.subtotal)),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: _setDiscount,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: _SummaryRow(
                                'Discount',
                                '- ${_currency.format(billing.discount)}',
                                actionIcon: Icons.edit_rounded,
                                color: Colors.red[600],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Divider(height: 1),
                          ),
                          _SummaryRow('Total', _currency.format(billing.total),
                              isBold: true, fontSize: 17),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: _setCollected,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: _SummaryRow(
                                'Collected',
                                _currency.format(billing.collectedAmount),
                                actionIcon: Icons.edit_rounded,
                                color: Colors.green[600],
                                isBold: true,
                              ),
                            ),
                          ),
                          if (billing.creditAmount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: _SummaryRow(
                                  'Credit Amount', _currency.format(billing.creditAmount),
                                  color: Colors.orange[800], isBold: true),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: billing.isLoading ? null : _submitBill,
                              icon: billing.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5, color: Colors.white))
                                  : const Icon(Icons.check_circle_rounded),
                              label: Text(
                                billing.isLoading ? 'Processing...' : 'Complete Bill',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOutBack),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  final IconData? actionIcon;
  final IconData? icon;
  final double? fontSize;

  const _SummaryRow(this.label, this.value,
      {this.isBold = false, this.color, this.actionIcon, this.icon, this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
        ],
        Text(label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? (isBold ? Colors.black87 : Colors.grey[600]),
              fontSize: fontSize ?? (isBold ? 14 : 13),
            )),
        if (actionIcon != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: (color ?? Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Icon(actionIcon, size: 14, color: color ?? Colors.grey[600]),
            ),
          ),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? (isBold ? Colors.black87 : Colors.grey[800]),
              fontSize: fontSize ?? (isBold ? 15 : 13),
              letterSpacing: -0.5,
            )),
      ],
    );
  }
}

class _CustomerSearchSheet extends StatefulWidget {
  const _CustomerSearchSheet();

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  final _ctrl = TextEditingController();
  List<Customer> _results = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final results = await context.read<CustomerProvider>().search(q);
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48, height: 6,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'Search customers...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                autofocus: true,
                onChanged: _search,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty && _ctrl.text.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_off_rounded, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No customers found',
                                  style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final c = _results[i];
                            return Card(
                              elevation: 0,
                              color: Colors.grey[50],
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(c.name[0].toUpperCase(),
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold)),
                                ),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${c.shopName ?? ''} ${c.mobile.isNotEmpty ? '• ${c.mobile}' : ''}'),
                                onTap: () => Navigator.pop(context, c),
                              ),
                            ).animate().fadeIn(delay: (i * 30).ms).slideX(begin: 0.1);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  const _ProductSearchSheet();

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _ctrl = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final results = await context.read<ProductProvider>().search(q);
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48, height: 6,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                autofocus: true,
                onChanged: _search,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty && _ctrl.text.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_rounded, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No products found',
                                  style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final p = _results[i];
                            return Card(
                              elevation: 0,
                              color: Colors.grey[50],
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.inventory_2_rounded,
                                      color: Theme.of(context).colorScheme.primary, size: 20),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    '${_currency.format(p.price)} ${p.displayUnit.isNotEmpty ? '• ${p.displayUnit}' : ''}'),
                                trailing: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                ),
                                onTap: () => Navigator.pop(context, p),
                              ),
                            ).animate().fadeIn(delay: (i * 30).ms).slideX(begin: 0.1);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
