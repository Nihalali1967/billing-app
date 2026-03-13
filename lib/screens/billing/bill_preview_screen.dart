import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import '../../providers/billing_provider.dart';
import '../../providers/auth_provider.dart';
import '../bills/bill_detail_screen.dart';

class BillPreviewScreen extends StatefulWidget {
  const BillPreviewScreen({super.key});

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  bool _isPrinting = false;
  String _printStatus = '';
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void dispose() {
    PrintBluetoothThermal.disconnect;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingProvider>();
    final preview = billing.previewData;
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    if (preview == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bill Preview')),
        body: const Center(child: Text('No preview data available')),
      );
    }

    final customer = preview['customer'] as Map<String, dynamic>? ?? {};
    final items = (preview['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final subtotal = double.tryParse(preview['subtotal']?.toString() ?? '0') ?? 0;
    final discount = double.tryParse(preview['discount']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(preview['total']?.toString() ?? '0') ?? 0;
    final collectedAmount = double.tryParse(preview['collected_amount']?.toString() ?? '0') ?? 0;
    final creditAmount = double.tryParse(preview['credit_amount']?.toString() ?? '0') ?? 0;
    final previousCredit = double.tryParse(preview['previous_credit']?.toString() ?? '0') ?? 0;
    final notes = preview['notes']?.toString();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Bill Preview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Preview Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.preview_rounded, color: Colors.amber[800], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'PREVIEW - Not yet confirmed',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().scale(),
                const SizedBox(height: 20),

                // Customer Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          (customer['name'] ?? 'C')[0].toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer['name'] ?? 'Customer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (customer['shop_name'] != null)
                              Text(customer['shop_name'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            if (customer['mobile'] != null)
                              Text(customer['mobile'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                      if (previousCredit > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text('Previous Credit', style: TextStyle(fontSize: 10, color: Colors.orange[700])),
                              Text(currency.format(previousCredit),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange[800])),
                            ],
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                const SizedBox(height: 16),

                // Items Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('Items (${items.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final itemTotal = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                        final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                        // Try multiple fields for unit price, or calculate from total/quantity
                        double effectivePrice = double.tryParse(item['effective_price']?.toString() ?? '0') ?? 
                                            double.tryParse(item['unit_price']?.toString() ?? '0') ?? 
                                            double.tryParse(item['price']?.toString() ?? '0') ?? 
                                            0;
                        
                        // If no price fields found, calculate from total/quantity
                        if (effectivePrice == 0 && qty > 0) {
                          effectivePrice = itemTotal / qty;
                        }
                        final isCustom = item['is_custom_price'] == true;
                        final productName = item['product']?['name'] ?? item['product_name'] ?? 'Product';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: idx < items.length - 1
                                ? Border(bottom: BorderSide(color: Colors.grey[100]!))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('${idx + 1}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      )),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(productName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 2)} kg × ${currency.format(effectivePrice)}',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹${effectivePrice.toStringAsFixed(2)} /kg',
                                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isCustom) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: const Text('Custom',
                                                style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(currency.format(itemTotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                const SizedBox(height: 16),

                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildRow('Subtotal', currency.format(subtotal)),
                      if (discount > 0) ...[
                        const SizedBox(height: 8),
                        _buildRow('Discount', '- ${currency.format(discount)}', color: Colors.red),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _buildRow('Total', currency.format(total), isBold: true, fontSize: 18),
                      const SizedBox(height: 8),
                      _buildRow('Collected', currency.format(collectedAmount), color: const Color(0xFF10B981)),
                      if (creditAmount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _buildRow('Credit', currency.format(creditAmount), color: Colors.orange[800]),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),

                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note_alt_rounded, color: Colors.blue[400], size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(notes, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: Share and Print buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareBill,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.blue.shade300),
                            foregroundColor: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isPrinting ? null : _printBill,
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))
                              : const Icon(Icons.print_rounded, size: 18),
                          label: Text(_isPrinting ? 'Printing...' : 'Print'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.purple.shade300),
                            foregroundColor: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bottom row: Edit and Confirm buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: billing.isLoading ? null : () => _finalizeBill(context),
                          icon: billing.isLoading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Icon(Icons.check_circle_rounded),
                          label: Text(
                            billing.isLoading ? 'Confirming...' : 'Confirm Bill',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Printing overlay
          if (_isPrinting)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.blue),
                        const SizedBox(height: 16),
                        Text(
                          _printStatus.isEmpty ? 'Printing...' : _printStatus,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please wait',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color, double? fontSize}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? (isBold ? Colors.black87 : Colors.grey[600]),
              fontSize: fontSize ?? (isBold ? 16 : 14),
            )),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? (isBold ? Colors.black87 : Colors.grey[800]),
              fontSize: fontSize ?? (isBold ? 16 : 14),
            )),
      ],
    );
  }

  Future<void> _finalizeBill(BuildContext context) async {
    final billing = context.read<BillingProvider>();
    final result = await billing.finalizeBill();

    if (!context.mounted) return;

    if (result != null) {
      final billId = result['id'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Bill ${result['bill_number'] ?? ''} created!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      // Navigate to bill detail and clear the billing stack
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (billId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BillDetailScreen(billId: billId)),
        );
      }
    } else if (billing.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(billing.error!)),
          ]),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _shareBill() async {
    final billing = context.read<BillingProvider>();
    final preview = billing.previewData;
    if (preview == null) return;

    // Create bill details text for sharing with proper formatting
    final billNumber = preview['bill_number'] ?? 'Preview';
    final customerName = preview['customer']?['name'] ?? 'Walk-in Customer';
    final customerShop = preview['customer']?['shop_name'] ?? '';
    final customerMobile = preview['customer']?['mobile'] ?? '';
    final total = double.tryParse(preview['total']?.toString() ?? '0') ?? 0;
    final subtotal = double.tryParse(preview['subtotal']?.toString() ?? '0') ?? 0;
    final discount = double.tryParse(preview['discount']?.toString() ?? '0') ?? 0;
    final collectedAmount = double.tryParse(preview['collected_amount']?.toString() ?? '0') ?? 0;
    final creditAmount = double.tryParse(preview['credit_amount']?.toString() ?? '0') ?? 0;
    final billedBy = preview['billed_by']?['name'] ??
                     preview['billed_by_name'] ??
                     context.read<AuthProvider>().user?.name ??
                     'Unknown';
    final items = preview['items'] as List? ?? [];
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // Build formatted receipt text
    StringBuffer receipt = StringBuffer();

    // Header
    receipt.writeln('                   STAR CHIPS                   ');
    receipt.writeln('                 --- Receipt ---                ');
    receipt.writeln();

    // Bill info row
    receipt.writeln('Bill No: ${billNumber.toString().padLeft(28)}');
    receipt.writeln('Date: ${dateStr.padLeft(30)}');
    receipt.writeln();

    // Customer info
    receipt.writeln('Customer:');
    receipt.writeln(customerName);
    if (customerShop.isNotEmpty) {
      receipt.writeln(customerShop);
    }
    if (customerMobile.isNotEmpty) {
      receipt.writeln(customerMobile);
    }
    receipt.writeln();

    // Separator line
    receipt.writeln('----------------------------------------------');

    // Items header - aligned columns (Item, Price, Qty, Amount)
    receipt.writeln('${'Item'.padRight(12)} ${'Price'.padLeft(10)} ${'Qty'.padLeft(8)} ${'Amount'.padLeft(10)}');

    // Items
    for (var item in items) {
      final name = item['product']?['name'] ?? item['product_name'] ?? 'Unknown';
      final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final itemTotal = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
      final unitPrice = qty > 0 ? itemTotal / qty : 0;

      // Truncate name if too long
      String displayName = name.length > 11 ? '${name.substring(0, 10)}..' : name;

      receipt.writeln(
        '${displayName.padRight(12)} '
        '${'₹${unitPrice.toStringAsFixed(1)}'.padLeft(10)} '
        '${'$qty kg'.padLeft(8)} '
        '${'₹${itemTotal.toStringAsFixed(2)}'.padLeft(10)}'
      );
    }

    receipt.writeln('----------------------------------------------');
    receipt.writeln();

    // Totals section - right aligned
    receipt.writeln('${'Subtotal'.padRight(30)} ${_currency.format(subtotal).padLeft(10)}');

    if (discount > 0) {
      receipt.writeln('${'Discount'.padRight(30)} -${_currency.format(discount).padLeft(9)}');
    }

    receipt.writeln('${'TOTAL'.padRight(30)} ${_currency.format(total).padLeft(10)}');
    receipt.writeln();
    receipt.writeln('${'Collected'.padRight(30)} ${_currency.format(collectedAmount).padLeft(10)}');

    if (creditAmount > 0) {
      receipt.writeln('${'Credit'.padRight(30)} ${_currency.format(creditAmount).padLeft(10)}');
    }

    receipt.writeln();
    receipt.writeln('----------------------------------------------');
    receipt.writeln();
    receipt.writeln('Billed by: $billedBy');
    receipt.writeln();
    receipt.writeln('    Thank you for your business!');
    receipt.writeln('         Visit again!');

    await Share.share(receipt.toString(), subject: 'Bill Receipt - $billNumber');
  }

  Future<void> _printBill() async {
    final billing = context.read<BillingProvider>();
    final preview = billing.previewData;
    if (preview == null) return;

    // Show print preview first
    await _showPrintPreview();
  }

  Future<void> _showPrintPreview() async {
    final billing = context.read<BillingProvider>();
    final preview = billing.previewData;
    if (preview == null) return;

    // Convert preview data to print format
    final printData = {
      'bill_number': preview['bill_number'] ?? 'Preview',
      'date': DateTime.now().toString().split('.')[0],
      'customer': preview['customer'],
      'items': (preview['items'] as List?)?.map((item) => {
        'name': item['product']?['name'] ?? item['product_name'] ?? 'Unknown',
        'quantity': item['quantity'] ?? 1,
        'total': item['total'] ?? 0,
      }).toList() ?? [],
      'subtotal': preview['subtotal'] ?? 0,
      'discount': preview['discount'] ?? 0,
      'total': preview['total'] ?? 0,
      'collected_amount': preview['collected_amount'] ?? 0,
      'credit_amount': preview['credit_amount'] ?? 0,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Print Preview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _shareBill();
                          },
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share', style: TextStyle(fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size(0, 36),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showPrinterSelectionDialog();
                          },
                          icon: _isPrinting 
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.print_rounded, size: 18),
                          label: Text(_isPrinting ? 'Printing...' : 'Print', style: const TextStyle(fontSize: 14)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size(0, 36),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      width: 300, // Typical thermal printer width proportion
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: ListView(
                        controller: ctrl,
                        children: [
                          Center(child: Text('STAR CHIPS', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2))),
                          const Center(child: Text('--- Receipt ---', style: TextStyle(color: Colors.grey))),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Bill No:'), Text(printData['bill_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))]),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Date:'), Text(printData['date'] ?? '')]),
                          if (printData['customer'] != null) ...[
                            const SizedBox(height: 8),
                            const Text('Customer:'),
                            Text(printData['customer']['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (printData['customer']['shop_name'] != null)
                              Text(printData['customer']['shop_name']),
                            if (printData['customer']['mobile'] != null)
                              Text(printData['customer']['mobile']),
                          ],
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('----------------------------------------', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(color: Colors.grey))),
                          Row(
                            children: const [
                              Expanded(flex: 2, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                              Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...(printData['items'] as List? ?? []).map((item) {
                            // Calculate unit price
                            final quantity = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                            final total = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                            final unitPrice = quantity > 0 ? total / quantity : 0;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${item['name']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      _currency.format(unitPrice),
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${item['quantity'] ?? 0} kg',
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _currency.format(total),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('----------------------------------------', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(color: Colors.grey))),
                          _PrintTotalRow('Subtotal', (printData['subtotal'] ?? 0).toDouble()),
                          if ((printData['discount'] ?? 0) > 0)
                            _PrintTotalRow('Discount', (printData['discount'] ?? 0).toDouble()),
                          _PrintTotalRow('Total', (printData['total'] ?? 0).toDouble(), isBold: true),
                          const SizedBox(height: 8),
                          _PrintTotalRow('Collected', (printData['collected_amount'] ?? 0).toDouble()),
                          if ((printData['credit_amount'] ?? 0) > 0)
                            _PrintTotalRow('Credit', (printData['credit_amount'] ?? 0).toDouble(), isBold: true),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('----------------------------------------', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(color: Colors.grey))),
                          const Center(child: Text('Thank you for your business!', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          const Center(child: Text('Visit again!', style: TextStyle(fontSize: 10))),
                          const SizedBox(height: 16),
                        ],
                      ),
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

  Widget _PrintTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(_currency.format(amount), style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _showPrinterSelectionDialog() async {
    try {
      // Check Bluetooth enabled
      final bool isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.bluetooth_disabled, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Please enable Bluetooth to print'),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      // Check Bluetooth permissions
      final bool permGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!permGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.bluetooth_disabled, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Please grant Bluetooth permission'),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      // Show printer selection dialog
      await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          List<BluetoothInfo> devices = [];
          bool scanning = true;

          // Initial scan
          Future.microtask(() async {
            try {
              final scannedDevices = await PrintBluetoothThermal.pairedBluetooths;
              if (mounted) {
                setDialogState(() {
                  devices = scannedDevices;
                  scanning = false;
                });
              }
            } catch (_) {
              if (mounted) {
                setDialogState(() {
                  scanning = false;
                });
              }
            }
          });

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.print_rounded, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Select Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                if (scanning)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: devices.isEmpty && !scanning
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_disabled_rounded, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No paired printers found',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('Pair your thermal printer in\nBluetooth settings first',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ],
                    )
                  : scanning
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Scanning for printers...', style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: devices.length,
                          itemBuilder: (_, i) {
                            final device = devices[i];
                            return ListTile(
                              leading: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.bluetooth_rounded, color: Colors.blue, size: 20),
                              ),
                              title: Text(device.name),
                              subtitle: Text(device.macAdress),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              onTap: () {
                                Navigator.pop(dialogCtx);
                                _connectAndPrint(device);
                              },
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: scanning ? null : () async {
                  setDialogState(() {
                    scanning = true;
                  });
                  try {
                    final scannedDevices = await PrintBluetoothThermal.pairedBluetooths;
                    setDialogState(() {
                      devices = scannedDevices;
                      scanning = false;
                    });
                  } catch (_) {
                    setDialogState(() {
                      scanning = false;
                    });
                  }
                },
                child: Text('Refresh'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _connectAndPrint(BluetoothInfo device) async {
    setState(() {
      _isPrinting = true;
      _printStatus = 'Connecting to ${device.name}...';
    });

    try {
      // Step 1: Connect
      final bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);

      if (!connected) {
        if (mounted) {
          setState(() => _isPrinting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Failed to connect to ${device.name}'),
              ]),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Step 2: Generate receipt
      if (mounted) setState(() => _printStatus = 'Generating receipt...');
      final List<int> bytes = await _generateEscPosReceipt();

      // Step 3: Send to printer
      if (mounted) setState(() => _printStatus = 'Printing bill...');
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);

      // Step 4: Disconnect
      await PrintBluetoothThermal.disconnect;

      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(result ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(result ? 'Bill printed successfully!' : 'Print may have failed. Please check printer.'),
            ]),
            backgroundColor: result ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      try { await PrintBluetoothThermal.disconnect; } catch (_) {}
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Print failed: ${e.toString().length > 80 ? '${e.toString().substring(0, 80)}...' : e}')),
            ]),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<List<int>> _generateEscPosReceipt() async {
    final billing = context.read<BillingProvider>();
    final preview = billing.previewData;
    if (preview == null) return [];

    final profile = await CapabilityProfile.load(name: 'default');
    final generator = Generator(PaperSize.mm58, profile);
    
    List<int> bytes = [];
    
    // Header
    bytes += generator.text(
      'BILL PREVIEW',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        width: PosTextSize.size2,
        height: PosTextSize.size2,
      ),
    );
    bytes += generator.emptyLines(1);
    
    // Bill details
    final billNumber = preview['bill_number'] ?? 'Preview';
    final customerName = preview['customer']?['name'] ?? 'Walk-in Customer';
    final customerMobile = preview['customer']?['mobile'] ?? '';
    
    bytes += generator.text('Bill No: $billNumber', styles: PosStyles(bold: true));
    bytes += generator.text('Customer: $customerName');
    if (customerMobile.isNotEmpty) {
      bytes += generator.text('Mobile: $customerMobile');
    }
    bytes += generator.text('Date: ${DateTime.now().toString().split('.')[0]}');
    bytes += generator.hr();
    
    // Items header
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(text: 'Total', width: 4, styles: PosStyles(bold: true, align: PosAlign.right)),
    ]);
    
    bytes += generator.hr(ch: '-');
    
    // Items
    final items = preview['items'] as List? ?? [];
    for (var item in items) {
      final name = item['product']?['name'] ?? item['product_name'] ?? 'Unknown';
      final qty = item['quantity'] ?? 1;
      final itemTotal = item['total'] ?? 0;
      
      bytes += generator.row([
        PosColumn(text: name, width: 6),
        PosColumn(text: qty.toString(), width: 2, styles: PosStyles(align: PosAlign.center)),
        PosColumn(text: _currency.format(itemTotal), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    
    bytes += generator.hr();
    
    // Totals
    final subtotal = double.tryParse(preview['subtotal']?.toString() ?? '0') ?? 0;
    final discount = double.tryParse(preview['discount']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(preview['total']?.toString() ?? '0') ?? 0;
    
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(text: '', width: 2),
      PosColumn(text: _currency.format(subtotal), width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    
    if (discount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 6),
        PosColumn(text: '', width: 2),
        PosColumn(text: '-${_currency.format(discount)}', width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: PosStyles(bold: true)),
      PosColumn(text: '', width: 2),
      PosColumn(text: _currency.format(total), width: 4, styles: PosStyles(bold: true, align: PosAlign.right)),
    ]);
    
    bytes += generator.hr(ch: '-');
    
    // Footer
    bytes += generator.text(
      'Thank you for your business!',
      styles: PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Visit again!',
      styles: PosStyles(align: PosAlign.center),
    );
    
    bytes += generator.feed(2);
    bytes += generator.cut();
    
    return bytes;
  }
}
