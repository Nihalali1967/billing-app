import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import '../../models/bill.dart';
import '../../providers/bill_provider.dart';
import '../../providers/customer_provider.dart';

class BillDetailScreen extends StatefulWidget {
  final int billId;
  const BillDetailScreen({super.key, required this.billId});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  Bill? _bill;
  bool _isLoading = true;
  bool _isPrinting = false;
  String _printStatus = '';
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  @override
  void dispose() {
    PrintBluetoothThermal.disconnect;
    super.dispose();
  }

  Future<void> _loadBill() async {
    setState(() => _isLoading = true);
    final bill = await context.read<BillProvider>().getBill(widget.billId);
    if (mounted) setState(() { _bill = bill; _isLoading = false; });
  }

  Future<void> _deleteBill() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Delete Bill'),
          ],
        ),
        content: Text('Delete bill "${_bill?.billNumber}"?\nThis will restore the customer\'s credit balance and stock quantities. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final success = await context.read<BillProvider>().deleteBill(widget.billId);
      if (success && mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _shareBill() async {
    // Fetch print data to get customer credit/extra amounts
    final printData = await context.read<BillProvider>().getPrintData(widget.billId);
    if (printData == null || !mounted) return;

    // Create bill details text for sharing with proper formatting
    final billNumber = printData['bill_number'] ?? 'N/A';
    final customerName = printData['customer']?['name'] ?? 'Walk-in Customer';
    final customerShop = printData['customer']?['shop_name'] ?? '';
    final customerMobile = printData['customer']?['mobile'] ?? '';
    final total = (printData['total'] ?? 0).toDouble();
    final subtotal = (printData['subtotal'] ?? 0).toDouble();
    final discount = (printData['discount'] ?? 0).toDouble();
    final collectedAmount = (printData['collected_amount'] ?? 0).toDouble();
    final creditAmount = (printData['credit_amount'] ?? 0).toDouble();
    final billedBy = printData['billed_by']?['name'] ?? printData['billed_by_name'] ?? 'Unknown';
    final items = printData['items'] as List? ?? [];
    final dateStr = printData['date'] ?? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // Customer table balance - try print data first, then fetch customer directly
    var customerCreditBalance = (printData['customer']?['credit_balance'] ?? 0).toDouble();
    var customerExtraAmount = (printData['customer']?['extra_amount'] ?? 0).toDouble();
    
    // If values are 0, fetch customer directly to get actual table values
    if ((customerCreditBalance == 0 && customerExtraAmount == 0) && printData['customer']?['id'] != null) {
      final customerId = printData['customer']['id'];
      final customerData = await context.read<CustomerProvider>().getCustomer(customerId);
      if (customerData != null) {
        customerCreditBalance = (customerData['credit_balance'] ?? 0).toDouble();
        customerExtraAmount = (customerData['extra_amount'] ?? 0).toDouble();
      }
    }

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
    // Show customer table balance if exists
    if (customerCreditBalance > 0 || customerExtraAmount > 0) {
      receipt.writeln();
      if (customerCreditBalance > 0) {
        receipt.writeln('${'Customer Credit Bal:'.padRight(30)} ${_currency.format(customerCreditBalance).padLeft(10)}');
      }
      if (customerExtraAmount > 0) {
        receipt.writeln('${'Customer Extra Amt:'.padRight(30)} ${_currency.format(customerExtraAmount).padLeft(10)}');
      }
    }
    receipt.writeln();

    // Separator line
    receipt.writeln('--------------------------------');

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

    receipt.writeln('--------------------------------');
    receipt.writeln();

    // 1. TOTAL first
    receipt.writeln('${'TOTAL'.padRight(30)} ${_currency.format(total).padLeft(10)}');
    receipt.writeln();

    // 2. Collected
    receipt.writeln('${'Collected'.padRight(30)} ${_currency.format(collectedAmount).padLeft(10)}');

    // 3. Credit
    if (creditAmount > 0) {
      receipt.writeln('${'Credit'.padRight(30)} ${_currency.format(creditAmount).padLeft(10)}');
    }

    // 4. Discount if any
    if (discount > 0) {
      receipt.writeln('${'Discount'.padRight(30)} -${_currency.format(discount).padLeft(9)}');
    }

    // 5. Credit Balance / Extra Amount (OB)
    if (customerCreditBalance > 0 || customerExtraAmount > 0) {
      receipt.writeln('--------------------------------');
      if (customerCreditBalance > 0) {
        receipt.writeln('${'Credit Balance (OB)'.padRight(30)} ${_currency.format(customerCreditBalance).padLeft(10)}');
      }
      if (customerExtraAmount > 0) {
        receipt.writeln('${'Extra Amount (OB)'.padRight(30)} ${_currency.format(customerExtraAmount).padLeft(10)}');
      }
      
      // 6. Totals
      // if (creditAmount > 0) {
      //   if (customerCreditBalance > 0) {
      //     final totalCredit = customerCreditBalance + creditAmount;
      //     receipt.writeln('${'  Total Credit'.padRight(30)} ${_currency.format(totalCredit).padLeft(10)}');
      //   }
      //   if (customerExtraAmount > 0) {
      //     final totalExtra = customerExtraAmount - creditAmount;
      //     receipt.writeln('${'  Total Extra Balance'.padRight(30)} ${_currency.format(totalExtra).padLeft(10)}');
      //   }
      // }
    }

    receipt.writeln();
    receipt.writeln('--------------------------------');
    receipt.writeln();
    receipt.writeln('Billed by: $billedBy');
    receipt.writeln();
    receipt.writeln('    Thank you for your business!');
    receipt.writeln('         Visit again!');

    await Share.share(receipt.toString(), subject: 'Bill Receipt - $billNumber');
  }

  Future<void> _printBill() async {
    if (_bill == null) return;

    try {
      // Check Bluetooth enabled
      final bool isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.bluetooth_disabled, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Please enable Bluetooth to print'),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            content: const Row(
              children: [
                Icon(Icons.security, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Bluetooth permission required. Please grant in Settings.')),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Show printer selection
      await _showPrinterSelectionDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showPrinterSelectionDialog() async {
    // Use local state for dialog so it updates independently
    List<BluetoothInfo> devices = [];
    bool scanning = true;

    // Initial scan
    try {
      devices = await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {}
    scanning = false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
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
              height: 320,
              child: Column(
                children: [
                  if (devices.isEmpty && !scanning)
                    Expanded(
                      child: Center(
                        child: Column(
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
                        ),
                      ),
                    )
                  else if (devices.isEmpty && scanning)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Scanning for printers...', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: devices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.bluetooth, color: Colors.blue, size: 20),
                            ),
                            title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(device.macAdress, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              _connectAndPrint(device);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: scanning ? null : () async {
                            setDialogState(() => scanning = true);
                            try {
                              devices = await PrintBluetoothThermal.pairedBluetooths;
                            } catch (_) {}
                            setDialogState(() => scanning = false);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Rescan'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Could not connect to ${device.name}')),
              ]),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<List<int>> _generateEscPosReceipt() async {
    if (_bill == null) return [];

    final profile = await CapabilityProfile.load(name: 'default');
    final generator = Generator(PaperSize.mm58, profile);

    // Helper to format currency for printer (uses Rs. instead of ₹)
    String formatPrintCurrency(double amount) {
      return 'Rs.${amount.toStringAsFixed(2)}';
    }

    List<int> bytes = [];

    // Header
    bytes += generator.text(
      'STAR CHIPS BILL RECEIPT',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.emptyLines(1);

    bytes += generator.hr();

    // Bill details
    bytes += generator.text(
      'Bill No: ${_bill!.billNumber}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      'Date: ${_bill!.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(_bill!.createdAt!) : 'N/A'}',
    );
    bytes += generator.text(
      'Customer: ${_bill!.customerName ?? 'Walk-in'}',
    );
    if (_bill!.customerShop != null && _bill!.customerShop!.isNotEmpty) {
      bytes += generator.text(
        'Shop: ${_bill!.customerShop}',
      );
    }
    
    // Fetch customer credit/extra - try print data first, then fetch customer directly
    final printData = await context.read<BillProvider>().getPrintData(widget.billId);
    var customerCreditBalance = (printData?['customer']?['credit_balance'] ?? 0).toDouble();
    var customerExtraAmount = (printData?['customer']?['extra_amount'] ?? 0).toDouble();
    
    // If values are 0, fetch customer directly to get actual table values
    if ((customerCreditBalance == 0 && customerExtraAmount == 0) && printData?['customer']?['id'] != null) {
      final customerId = printData!['customer']['id'];
      final customerData = await context.read<CustomerProvider>().getCustomer(customerId);
      if (customerData != null) {
        customerCreditBalance = (customerData['credit_balance'] ?? 0).toDouble();
        customerExtraAmount = (customerData['extra_amount'] ?? 0).toDouble();
      }
    }
    
bytes += generator.hr();

    // Items header
    bytes += generator.row([
      PosColumn(text: 'Item', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(text: 'Price', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    bytes += generator.hr(ch: '-');

    // Items
    for (final item in _bill!.items) {
      final name = item.productName ?? 'Product';
      final qty = item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 2);
      final unitPrice = (item.quantity > 0 ? item.lineTotal / item.quantity : 0).toDouble();
      final total = formatPrintCurrency(item.lineTotal);

      bytes += generator.row([
        PosColumn(text: name, width: 4),
        PosColumn(text: qty, width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: formatPrintCurrency(unitPrice), width: 3, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: total, width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    // 1. TOTAL first
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: '', width: 2),
      PosColumn(text: formatPrintCurrency(_bill!.total), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    // 2. Collected
    bytes += generator.hr(ch: '-');
    bytes += generator.row([
      PosColumn(text: 'Collected', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: '', width: 2),
      PosColumn(text: formatPrintCurrency(_bill!.collectedAmount), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    // 3. Credit amount
    if (_bill!.creditAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Credit', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: '', width: 2),
        PosColumn(text: formatPrintCurrency(_bill!.creditAmount), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
    }

    if (_bill!.discount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 6),
        PosColumn(text: '', width: 2),
        PosColumn(text: '-${formatPrintCurrency(_bill!.discount)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    // 4. Customer table balance (OB) after credit
    if (customerCreditBalance > 0 || customerExtraAmount > 0) {
      bytes += generator.hr(ch: '-');
      if (customerCreditBalance > 0) {
        bytes += generator.row([
          PosColumn(text: 'Credit Balance (OB)', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: '', width: 2),
          PosColumn(text: formatPrintCurrency(customerCreditBalance), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
      }
      if (customerExtraAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Extra Amount (OB)', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: '', width: 2),
          PosColumn(text: formatPrintCurrency(customerExtraAmount), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
      }
    }

    bytes += generator.hr();

    // Footer
    bytes += generator.text(
      'Thank you for your business!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Visit again!',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text('Bill Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_bill == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text('Bill Details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Bill not found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final bill = _bill!;
    final hasCredit = bill.creditAmount > 0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(bill.billNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: () => _showPrintPreview(),
            tooltip: 'Print Bill',
          ),
          PopupMenuButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), SizedBox(width: 12), Text('Delete Bill', style: TextStyle(color: Colors.red))]),
              ),
            ],
            onSelected: (val) {
              if (val == 'delete') _deleteBill();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.05),
              ),
            ),
          ),
          
          RefreshIndicator(
            onRefresh: _loadBill,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, const Color(0xFF3730A3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL AMOUNT',
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currency.format(bill.total),
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: hasCredit ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: hasCredit ? Colors.orange.withOpacity(0.5) : Colors.green.withOpacity(0.5)),
                            ),
                            child: Text(
                              hasCredit ? 'CREDIT' : 'PAID',
                              style: TextStyle(
                                color: hasCredit ? Colors.orange[200] : Colors.green[200],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.person_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.customerName ?? 'Walk-in Customer',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                if (bill.customerShop != null && bill.customerShop!.isNotEmpty)
                                  Text(bill.customerShop!, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                                if (bill.customerMobile != null && bill.customerMobile!.isNotEmpty)
                                  Text(bill.customerMobile!, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(color: Colors.white24, height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
                              const SizedBox(width: 6),
                              Text(
                                bill.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt!.toLocal()) : '',
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
                              const SizedBox(width: 6),
                              Text(
                                bill.billedByName ?? '',
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 32),

                // Items Section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.shopping_bag_rounded, color: Colors.purple, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Items (${bill.items.length})',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                
                const SizedBox(height: 16),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Items header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text('ITEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5))),
                            Expanded(flex: 1, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5), textAlign: TextAlign.right)),
                            Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5), textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      // Item rows
                      ...bill.items.asMap().entries.map((e) {
                        final i = e.key;
                        final item = e.value;
                        final isLast = i == bill.items.length - 1;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        if (item.isCustomPrice)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('Custom Price', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 2)} kg',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800], fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _currency.format(item.effectivePrice),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _currency.format(item.lineTotal > 0 ? item.lineTotal : item.total),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 20, endIndent: 20),
                          ],
                        );
                      }),
                      
                      // Totals section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        ),
                        child: Column(
                          children: [
                            _TotalRow('Subtotal', _currency.format(bill.subtotal)),
                            if (bill.discount > 0) _TotalRow('Discount', '- ${_currency.format(bill.discount)}', color: Colors.red),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                            _TotalRow('Total', _currency.format(bill.total), isBold: true, fontSize: 18),
                            const SizedBox(height: 8),
                            _TotalRow('Collected', _currency.format(bill.collectedAmount), color: Colors.green[700], isBold: true),
                            if (bill.creditAmount > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                                child: _TotalRow('Credit Balance', _currency.format(bill.creditAmount), color: Colors.orange[800], isBold: true),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_alt_rounded, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Notes', style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(bill.notes!, style: TextStyle(color: Colors.blue[800], fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ],
            ),
          ),

          // Printing overlay
          if (_isPrinting)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 24),
                        const Text('Printing...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          _printStatus,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          textAlign: TextAlign.center,
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

  Future<void> _showPrintPreview() async {
    final printData = await context.read<BillProvider>().getPrintData(widget.billId);
    if (printData == null || !mounted) return;

    // Get customer credit/extra - try print data first, then fetch customer directly
    var customerCreditBalance = (printData['customer']?['credit_balance'] ?? 0).toDouble();
    var customerExtraAmount = (printData['customer']?['extra_amount'] ?? 0).toDouble();
    
    // If values are 0, fetch customer directly to get actual table values
    if ((customerCreditBalance == 0 && customerExtraAmount == 0) && printData['customer']?['id'] != null) {
      final customerId = printData['customer']['id'];
      final customerData = await context.read<CustomerProvider>().getCustomer(customerId);
      if (customerData != null) {
        customerCreditBalance = (customerData['credit_balance'] ?? 0).toDouble();
        customerExtraAmount = (customerData['extra_amount'] ?? 0).toDouble();
      }
    }

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
                            _printBill();
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
                            if (customerCreditBalance > 0 || customerExtraAmount > 0) ...[
                              const SizedBox(height: 4),
                              if (customerCreditBalance > 0)
                                _PrintTotalRow('Customer Credit Bal', customerCreditBalance),
                              if (customerExtraAmount > 0)
                                _PrintTotalRow('Customer Extra Amt', customerExtraAmount),
                            ],
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
                                      '${item['product']?['name'] ?? item['product_name'] ?? item['name'] ?? 'Unknown'}',
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
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '----------------------------------------',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          // 1. TOTAL first
                          _PrintTotalRow('Total', (printData['total'] ?? 0).toDouble(), isBold: true),
                          const SizedBox(height: 4),
                          // 2. Collected
                          _PrintTotalRow('Collected', (printData['collected_amount'] ?? 0).toDouble()),
                          // 3. Credit
                          if ((printData['credit_amount'] ?? 0) > 0)
                            _PrintTotalRow('Credit', (printData['credit_amount'] ?? 0).toDouble(), isBold: true),
                          // 4. Discount if any
                          if ((printData['discount'] ?? 0) > 0)
                            _PrintTotalRow('Discount', (printData['discount'] ?? 0).toDouble()),
                          // 5. Credit Balance / Extra Amount (OB)
                          if (customerCreditBalance > 0 || customerExtraAmount > 0) ...[
                            const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('----------------------------------------', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(color: Colors.grey))),
                            if (customerCreditBalance > 0)
                              _PrintTotalRow('Credit Balance (OB)', customerCreditBalance),
                            if (customerExtraAmount > 0)
                              _PrintTotalRow('Extra Amount (OB)', customerExtraAmount),
                          ],
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('----------------------------------------', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(color: Colors.grey))),
                          Text('Billed by: ${printData['billed_by']?['name'] ?? printData['billed_by_name'] ?? printData['billed_by'] ?? 'Unknown'}', style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 16),
                          const Center(child: Text('Thank you for your business!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          const SizedBox(height: 24),
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
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  final double? fontSize;

  const _TotalRow(this.label, this.value, {this.isBold = false, this.color, this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? Colors.grey[700], fontSize: fontSize ?? 14)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.black87, fontSize: fontSize ?? (isBold ? 16 : 14))),
        ],
      ),
    );
  }
}

class _PrintTotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _PrintTotalRow(this.label, this.amount, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 14 : 12)),
          Text(currency.format(amount), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 14 : 12)),
        ],
      ),
    );
  }
}
