import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../providers/billing_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/auth_provider.dart';
import '../bills/bill_detail_screen.dart';
import 'bill_preview_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  bool _isPrinting = false;
  String _printStatus = '';

  Future<void> _selectCustomer() async {
    final customer = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomerSearchSheet(),
    );
    if (customer != null && mounted) {
      // Set customer with full data including credit and extra amounts
      await context.read<BillingProvider>().setCustomer(
        customer.id,
        customer.name,
        creditBalance: customer.creditBalance,
        extraAmount: customer.extraAmount,
      );
    }
  }

  Future<void> _addProduct() async {
    final products = await showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSearchSheet(
        initialSelectedIds: context.read<BillingProvider>().items.map((e) => e.product.id).toSet(),
      ),
    );
    if (products != null && mounted) {
      final billing = context.read<BillingProvider>();
      final existingIds = billing.items.map((e) => e.product.id).toSet();
      // Only add newly selected products (not already in cart)
      for (final product in products) {
        if (!existingIds.contains(product.id)) {
          billing.addItem(product);
        }
      }
      // Remove deselected products (were in cart but not in returned list)
      final returnedIds = products.map((p) => p.id).toSet();
      final toRemove = billing.items
          .asMap()
          .entries
          .where((e) => existingIds.contains(e.value.product.id) && !returnedIds.contains(e.value.product.id))
          .map((e) => e.key)
          .toList()
          .reversed;
      for (final index in toRemove) {
        billing.removeItem(index);
      }
    }
  }

  void _editItem(int index) {
    final billing = context.read<BillingProvider>();
    final item = billing.items[index];
    final qtyCtrl = TextEditingController(text: item.quantity == item.quantity.toInt() ? item.quantity.toInt().toString() : item.quantity.toString());
    final priceCtrl = TextEditingController(
      text: item.customPrice?.toString() ?? '',
    );

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
              autofocus: true,
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
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Total:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    _currency.format(billing.total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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

  Future<void> _previewBill() async {
    final billing = context.read<BillingProvider>();
    if (billing.customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select a customer'),
            ],
          ),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    if (billing.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Add at least one product'),
            ],
          ),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final result = await billing.previewBill();
    if (!mounted) return;

    if (result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BillPreviewScreen()),
      );
    } else if (billing.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(billing.error!)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _shareBill() async {
    final billing = context.read<BillingProvider>();

    // Build share text from current cart items
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final items = billing.items;

    StringBuffer receipt = StringBuffer();
    receipt.writeln('                   STAR CHIPS                   ');
    receipt.writeln('                 --- Manjeri ---                ');
    receipt.writeln();
    receipt.writeln('Date: ${dateStr.padLeft(30)}');
    receipt.writeln();

    // Customer info
    if (billing.customerId != null) {
      receipt.writeln('Customer:');
      receipt.writeln(billing.customerName ?? 'Unknown');
      receipt.writeln();
    }

    // Items
    receipt.writeln(
      '${'Item'.padRight(12)} ${'Price'.padLeft(10)} ${'Qty'.padLeft(8)} ${'Amount'.padLeft(10)}',
    );
    receipt.writeln('----------------------------------');

    for (var item in items) {
      final name = item.product.name;
      final qty = item.quantity;
      final itemTotal = item.lineTotal;
      final unitPrice = item.effectivePrice;

      String displayName = name.length > 11
          ? '${name.substring(0, 10)}..'
          : name;
      receipt.writeln(
        '${displayName.padRight(12)} '
        '${_currency.format(unitPrice).padLeft(10)} '
        '${'$qty kg'.padLeft(8)} '
        '${_currency.format(itemTotal).padLeft(10)}',
      );
    }

    receipt.writeln('----------------------------------');
    receipt.writeln();
    receipt.writeln(
      '${'TOTAL'.padRight(30)} ${_currency.format(billing.total).padLeft(10)}',
    );
    receipt.writeln();
    if ((billing.collectedAmount ?? 0) != 0) {
      receipt.writeln(
        '${'Collected'.padRight(30)} ${_currency.format(billing.collectedAmount).padLeft(10)}',
      );
    }

    // Show customer-based credit/extra amounts from customer table
    if (billing.customerCreditBalance > 0 || billing.customerExtraAmount > 0) {
      receipt.writeln('----------------------------------');
      if (billing.customerCreditBalance > 0) {
        receipt.writeln(
          '${'Old Credit Bal:'.padRight(30)} ${_currency.format(billing.customerCreditBalance).padLeft(10)}',
        );
      }
      if (billing.customerExtraAmount > 0) {
        receipt.writeln(
          '${'Old Extra Amt:'.padRight(30)} ${_currency.format(billing.customerExtraAmount).padLeft(10)}',
        );
      }
    }

    // Calculate and show Credit/Extra
    if (billing.customerCreditBalance > 0 || billing.customerExtraAmount > 0) {
      receipt.writeln('----------------------------------');

      if (billing.customerCreditBalance > 0) {
        // Credit Balance: total owed = bill total + old credit
        final totalWithCredit = billing.total + billing.customerCreditBalance;
        final netBalance = billing.collectedAmount - totalWithCredit;

        if (netBalance > 0) {
          receipt.writeln(
            '${'Total Extra Amt'.padRight(30)} ${_currency.format(netBalance).padLeft(10)}',
          );
        } else if (netBalance == 0) {
          receipt.writeln(
            '${'Total Credit'.padRight(30)} ${_currency.format(0).padLeft(10)}',
          );
        } else {
          receipt.writeln(
            '${'Total Credit'.padRight(30)} ${_currency.format(netBalance.abs()).padLeft(10)}',
          );
        }
      } else if (billing.customerExtraAmount > 0) {
        // Extra Amount: netBalance = extraAmt + collected - total
        final netBalance = billing.customerExtraAmount + billing.collectedAmount - billing.total;

        if (netBalance > 0) {
          receipt.writeln(
            '${'Total Extra Amt'.padRight(30)} ${_currency.format(netBalance).padLeft(10)}',
          );
        } else if (netBalance == 0) {
          receipt.writeln(
            '${'Total Credit'.padRight(30)} ${_currency.format(0).padLeft(10)}',
          );
        } else {
          receipt.writeln(
            '${'Total Credit'.padRight(30)} ${_currency.format(netBalance.abs()).padLeft(10)}',
          );
        }
      }
    }

    receipt.writeln();
    receipt.writeln('-----------------------------------');
    receipt.writeln();
    receipt.writeln('    Thank you !');

    await Share.share(receipt.toString(), subject: 'Bill Receipt');
  }

  Future<void> _printBill() async {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Check Bluetooth permissions
      final bool permGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!permGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.security, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bluetooth permission required. Please grant in Settings.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Show printer selection dialog
      await _showPrinterSelectionDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveBill() async {
    final billing = context.read<BillingProvider>();
    if (billing.customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select a customer'),
            ],
          ),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    if (billing.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Add at least one product'),
            ],
          ),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Step 1: Preview the bill
    final previewResult = await billing.previewBill();
    if (!mounted) return;
    if (previewResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(billing.error ?? 'Preview failed')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Step 2: Finalize the bill
    final result = await billing.finalizeBill();
    if (!mounted) return;

    if (result != null) {
      final billId = result['id'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Bill ${result['bill_number'] ?? ''} saved!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      // Cart is already cleared by finalizeBill()
      // Navigate to bill detail
      if (billId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BillDetailScreen(billId: billId)),
        );
      }
    } else if (billing.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(billing.error!)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showPrinterSelectionDialog() async {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      // Check Bluetooth permissions
      final bool permGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!permGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.bluetooth_disabled, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Please grant Bluetooth permission'),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      // Fetch paired devices BEFORE showing dialog
      List<BluetoothInfo> devices = [];
      bool scanning = true;

      try {
        devices = await PrintBluetoothThermal.pairedBluetooths;
      } catch (_) {}
      scanning = false;

      if (!mounted) return;

      // Show printer selection dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
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
                    child: const Icon(
                      Icons.print_rounded,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Printer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (scanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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
                              Icon(
                                Icons.bluetooth_disabled_rounded,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No paired printers found',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pair your thermal printer in\nBluetooth settings first',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
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
                              Text(
                                'Scanning for printers...',
                                style: TextStyle(color: Colors.grey),
                              ),
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.bluetooth,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                device.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                device.macAdress,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Colors.grey,
                              ),
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
                            onPressed: scanning
                                ? null
                                : () async {
                                    setDialogState(() => scanning = true);
                                    try {
                                      devices = await PrintBluetoothThermal
                                          .pairedBluetooths;
                                    } catch (_) {}
                                    setDialogState(() => scanning = false);
                                  },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Rescan'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
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
      final bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );

      if (!connected) {
        if (mounted) {
          setState(() => _isPrinting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Failed to connect to ${device.name}'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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

      // Wait a moment for printer to process before disconnecting
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 4: Disconnect
      await PrintBluetoothThermal.disconnect;

      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  result
                      ? 'Bill printed successfully!'
                      : 'Print may have failed. Please check printer.',
                ),
              ],
            ),
            backgroundColor: result ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Print failed: ${e.toString().length > 80 ? '${e.toString().substring(0, 80)}...' : e}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<List<int>> _generateEscPosReceipt() async {
    final billing = context.read<BillingProvider>();
    final items = billing.items;

    final profile = await CapabilityProfile.load(name: 'default');
    final generator = Generator(PaperSize.mm58, profile);

    // Helper to format currency for printer (uses Rs. instead of )
    String formatPrintCurrency(double amount) {
      return 'Rs.${amount.toStringAsFixed(2)}';
    }

    List<int> bytes = [];

    // Header
    bytes += generator.text(
      'STAR CHIPS',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        width: PosTextSize.size2,
        height: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'Manjeri',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += generator.emptyLines(1);

    // Bill details
    bytes += generator.text('Date: ${DateTime.now().toString().split('.')[0]}');

    // Customer info
    if (billing.customerId != null) {
      bytes += generator.text('Customer: ${billing.customerName ?? 'Unknown'}');
    }

    // Add customer credit/extra to thermal print if exists
    final customerCreditBalance = billing.customerCreditBalance;
    final customerExtraAmount = billing.customerExtraAmount;

    // if (customerCreditBalance > 0 || customerExtraAmount > 0) {
    //   bytes += generator.hr(ch: '-');
    //   if (customerCreditBalance > 0) {
    //     bytes += generator.row([
    //       PosColumn(
    //         text: 'Previous Credit:',
    //         width: 6,
    //         styles: const PosStyles(bold: true),
    //       ),
    //       PosColumn(text: '', width: 2),
    //       PosColumn(
    //         text: formatPrintCurrency(customerCreditBalance),
    //         width: 4,
    //         styles: const PosStyles(bold: true, align: PosAlign.right),
    //       ),
    //     ]);
    //   }
    //   if (customerCreditBalance > 0) {
    //     bytes += generator.row([
    //       PosColumn(
    //         text: 'Cust Credit Bal:',
    //         width: 6,
    //         styles: const PosStyles(bold: true),
    //       ),
    //       PosColumn(text: '', width: 2),
    //       PosColumn(
    //         text: formatPrintCurrency(customerCreditBalance),
    //         width: 4,
    //         styles: const PosStyles(bold: true, align: PosAlign.right),
    //       ),
    //     ]);
    //   }
    //   if (customerExtraAmount > 0) {
    //     bytes += generator.row([
    //       PosColumn(
    //         text: 'Cust Extra Amt:',
    //         width: 6,
    //         styles: const PosStyles(bold: true),
    //       ),
    //       PosColumn(text: '', width: 2),
    //       PosColumn(
    //         text: formatPrintCurrency(customerExtraAmount),
    //         width: 4,
    //         styles: const PosStyles(bold: true, align: PosAlign.right),
    //       ),
    //     ]);
    //   }
    // }

    bytes += generator.hr();

    // Items header
    bytes += generator.row([
      PosColumn(text: 'Item', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        text: 'Price',
        width: 3,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
      PosColumn(
        text: 'Total',
        width: 3,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    bytes += generator.hr(ch: '-');

    // Items
    for (var item in items) {
      final name = item.product.name;
      final qty = item.quantity;
      final itemTotal = item.lineTotal;
      final unitPrice = item.effectivePrice;

      bytes += generator.row([
        PosColumn(text: name, width: 4),
        PosColumn(
          text: qty.toStringAsFixed(qty == qty.toInt() ? 0 : 2),
          width: 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: formatPrintCurrency(unitPrice),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: formatPrintCurrency(itemTotal),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    // Get values
    final total = billing.total;
    final collectedAmount = billing.collectedAmount;

    // 1. TOTAL first
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: '', width: 2),
      PosColumn(
        text: formatPrintCurrency(total),
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    bytes += generator.hr(ch: '-');

    // 2. Collected
    if ((collectedAmount ?? 0) > 0) {
      bytes += generator.row([
        PosColumn(
          text: 'Collected',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(text: '', width: 2),
        PosColumn(
          text: formatPrintCurrency(collectedAmount),
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
    }

    // 3. Customer-based credit/extra amounts from customer table
    if (customerCreditBalance > 0 || customerExtraAmount > 0) {
      bytes += generator.hr(ch: '-');
      if (customerCreditBalance > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Old Credit Bal:',
            width: 6,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(text: '', width: 2),
          PosColumn(
            text: formatPrintCurrency(customerCreditBalance),
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]);
        
      }
      if (customerExtraAmount > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Old Extra Amt:',
            width: 6,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(text: '', width: 2),
          PosColumn(
            text: formatPrintCurrency(customerExtraAmount),
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]);
      }
    }

    // 3. Show Total Credit or Total Extra based on customer OB balance
    if (customerCreditBalance > 0 || customerExtraAmount > 0) {
      bytes += generator.hr(ch: '-');

      if (customerCreditBalance > 0) {
        // Credit Balance: total owed = bill total + old credit
        final totalWithCredit = total + customerCreditBalance;
        final netBalance = collectedAmount - totalWithCredit;

        if (netBalance > 0) {
          bytes += generator.row([
            PosColumn(text: 'Total Extra Amt', width: 6, styles: const PosStyles(bold: true)),
            PosColumn(text: '', width: 2),
            PosColumn(text: formatPrintCurrency(netBalance), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
          ]);
        } else if (netBalance == 0) {
          bytes += generator.row([
            PosColumn(text: 'Total Credit', width: 6, styles: const PosStyles(bold: true)),
            PosColumn(text: '', width: 2),
            PosColumn(text: formatPrintCurrency(0), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
          ]);
        } else {
          bytes += generator.row([
            PosColumn(text: 'Total Credit', width: 6, styles: const PosStyles(bold: true)),
            PosColumn(text: '', width: 2),
            PosColumn(text: formatPrintCurrency(netBalance.abs()), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
          ]);
        }
      } else if (customerExtraAmount > 0) {
        // Extra Amount: netBalance = extraAmt + collected - total
        final netBalance = customerExtraAmount + collectedAmount - total;

        if (netBalance > 0) {
          bytes += generator.row([
            PosColumn(text: 'Total Extra Amt', width: 6, styles: const PosStyles(bold: true)),
            PosColumn(text: '', width: 2),
            PosColumn(text: formatPrintCurrency(netBalance), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
          ]);
        } else if (netBalance == 0) {
          bytes += generator.row([
            PosColumn(text: 'Total Credit', width: 6, styles: const PosStyles(bold: true)),
            PosColumn(text: '', width: 2),
            PosColumn(text: formatPrintCurrency(0), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
          ]);
        } else {
          bytes += generator.row([
            PosColumn(text: 'Total Credit', width: 6, styles: const PosStyles(bold: true)),
            PosColumn(text: '', width: 2),
            PosColumn(text: formatPrintCurrency(netBalance.abs()), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
          ]);
        }
      }
    }

    bytes += generator.hr();
    bytes += generator.text(
      'Thank you !',
      styles: PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingProvider>();
    final theme = Theme.of(context);

    final bottomNavHeight = kBottomNavigationBarHeight;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final summaryPanelHeight = 220.0 + bottomNavHeight + systemBottom;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Customer selection
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: billing.customerId == null
                                    ? Colors.grey[100]
                                    : theme.colorScheme.primary.withOpacity(
                                        0.1,
                                      ),
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
                                    Text(
                                      'Required to create a bill',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    )
                                  else ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (billing.customerCreditBalance >
                                            0) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Credit: ${_currency.format(billing.customerCreditBalance)}',
                                              style: TextStyle(
                                                color: Colors.orange[700],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (billing.customerExtraAmount >
                                            0) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Extra: ${_currency.format(billing.customerExtraAmount)}',
                                              style: TextStyle(
                                                color: Colors.blue[700],
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
                              child: Icon(
                                Icons.search_rounded,
                                color: Colors.grey[600],
                                size: 16,
                              ),
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
                        icon: const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Add Product',
                          style: TextStyle(fontSize: 13),
                        ),
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
                          final ctrl = TextEditingController(
                            text: billing.notes,
                          );
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
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
                                  child: const Text('Cancel'),
                                ),
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
                        label: const Text(
                          'Notes',
                          style: TextStyle(fontSize: 13),
                        ),
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

              // Cart Items
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
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Cart is empty',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Add Product" to start billing',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms).scale()
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 8,
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
                                      color: theme.colorScheme.secondary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_rounded,
                                      color: theme.colorScheme.secondary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '${item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 2)} kg × ${_currency.format(item.effectivePrice)}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (item.customPrice != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                        _currency.format(item.lineTotal),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () =>
                                            billing.removeItem(index),
                                        borderRadius: BorderRadius.circular(
                                          8,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons
                                                .remove_circle_outline_rounded,
                                            size: 18,
                                            color: Colors.red[400],
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Total
                          _SummaryRow(
                            'Total',
                            _currency.format(billing.total),
                            isBold: true,
                            fontSize: 17,
                          ),
                          const SizedBox(height: 2),
                          // Collected
                          InkWell(
                            onTap: _setCollected,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: _SummaryRow(
                                'Collected',
                                _currency.format(billing.collectedAmount),
                                actionIcon: Icons.edit_rounded,
                                color: Colors.green[600],
                                isBold: true,
                              ),
                            ),
                          ),
                          // Show calculated totals based on customer OB balances
                          if (billing.customerCreditBalance > 0 ||
                              billing.customerExtraAmount > 0) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Divider(height: 1),
                            ),
                            () {
                              // Case 1: Customer has Credit Balance (OB)
                              if (billing.customerCreditBalance > 0) {
                                // Credit Balance: total owed = bill total + old credit
                                final totalWithCredit = billing.total + billing.customerCreditBalance;
                                final netBalance = billing.collectedAmount - totalWithCredit;

                                if (netBalance > 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Extra Amt',
                                      _currency.format(netBalance),
                                      color: Colors.green[700],
                                      isBold: true,
                                    ),
                                  );
                                } else if (netBalance == 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Credit',
                                      _currency.format(0),
                                      color: Colors.green[700],
                                      isBold: true,
                                    ),
                                  );
                                } else {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Credit',
                                      _currency.format(netBalance.abs()),
                                      color: Colors.red[700],
                                      isBold: true,
                                    ),
                                  );
                                }
                              }
                              // Case 2: Customer has Extra Amount (OB)
                              else if (billing.customerExtraAmount > 0) {
                                // Extra Amount: netBalance = extraAmt + collected - total
                                final netBalance = billing.customerExtraAmount + billing.collectedAmount - billing.total;

                                if (netBalance > 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Extra Amt',
                                      _currency.format(netBalance),
                                      color: Colors.green[700],
                                      isBold: true,
                                    ),
                                  );
                                } else if (netBalance == 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Credit',
                                      _currency.format(0),
                                      color: Colors.green[700],
                                      isBold: true,
                                    ),
                                  );
                                } else {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Credit',
                                      _currency.format(netBalance.abs()),
                                      color: Colors.red[700],
                                      isBold: true,
                                    ),
                                  );
                                }
                              }
                              // Case 3: Customer has no Credit Balance and no Extra Amount (normal case)
                              else {
                                final netBalance = billing.collectedAmount - billing.total;

                                if (netBalance > 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Extra Amt',
                                      _currency.format(netBalance),
                                      color: Colors.green[700],
                                      isBold: true,
                                    ),
                                  );
                                } else if (netBalance == 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Credit',
                                      _currency.format(0),
                                      color: Colors.green[700],
                                      isBold: true,
                                    ),
                                  );
                                } else {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: _SummaryRow(
                                      'Total Credit',
                                      _currency.format(netBalance.abs()),
                                      color: Colors.red[700],
                                      isBold: true,
                                    ),
                                  );
                                }
                              }
                            }(),
                          ],
                          const SizedBox(height: 12),
                          // Action buttons row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: billing.isLoading
                                      ? null
                                      : _shareBill,
                                  icon: const Icon(
                                    Icons.share_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Share'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: billing.isLoading
                                      ? null
                                      : _printBill,
                                  icon: const Icon(
                                    Icons.print_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Print'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: billing.isLoading
                                      ? null
                                      : _saveBill,
                                  icon: billing.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_rounded),
                                  label: Text(
                                    billing.isLoading
                                        ? 'Saving...'
                                        : 'Save Bill',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
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
          ).animate().slideY(
            begin: 1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ),
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

  const _SummaryRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.color,
    this.actionIcon,
    this.icon,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? (isBold ? Colors.black87 : Colors.grey[600]),
            fontSize: fontSize ?? (isBold ? 14 : 13),
          ),
        ),
        if (actionIcon != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: (color ?? Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                actionIcon,
                size: 14,
                color: color ?? Colors.grey[600],
              ),
            ),
          ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? (isBold ? Colors.black87 : Colors.grey[800]),
            fontSize: fontSize ?? (isBold ? 15 : 13),
            letterSpacing: -0.5,
          ),
        ),
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
  List<Customer> _allCustomers = [];
  List<Customer> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllCustomers();
  }

  Future<void> _loadAllCustomers() async {
    setState(() => _loading = true);
    final results = await context.read<CustomerProvider>().fetchAll();
    if (mounted) {
      results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _allCustomers = results;
        _results = results;
        _loading = false;
      });
    }
  }

  void _search(String q) {
    if (q.isEmpty) {
      setState(() => _results = _allCustomers);
      return;
    }
    final query = q.toLowerCase();
    final filtered = _allCustomers.where((c) {
      return c.name.toLowerCase().contains(query) ||
          (c.shopName?.toLowerCase().contains(query) ?? false) ||
          c.mobile.contains(query);
    }).toList();
    // Sort: items starting with query first, then alphabetically
    filtered.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(query);
      final bStarts = b.name.toLowerCase().startsWith(query);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    setState(() => _results = filtered);
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
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
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
                  : _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_off_rounded,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No customers found',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Text(
                                c.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${c.shopName ?? ''} ${c.mobile.isNotEmpty ? '• ${c.mobile}' : ''}',
                            ),
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
  final Set<int> initialSelectedIds;
  const _ProductSearchSheet({this.initialSelectedIds = const {}});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  List<Product> _allProducts = [];
  late final Set<int> _selectedIds = Set<int>.from(widget.initialSelectedIds);
  bool _loading = true;
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await context.read<ProductProvider>().getAllProducts();
    products.sort((a, b) {
      final aSelected = widget.initialSelectedIds.contains(a.id);
      final bSelected = widget.initialSelectedIds.contains(b.id);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    if (mounted) {
      setState(() {
        _allProducts = products;
        _loading = false;
      });
    }
  }

  void _toggleProduct(Product p) {
    setState(() {
      if (_selectedIds.contains(p.id)) {
        _selectedIds.remove(p.id);
      } else {
        _selectedIds.add(p.id);
      }
    });
  }

  void _confirm() {
    final selected = _allProducts.where((p) => _selectedIds.contains(p.id)).toList();
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Products',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _allProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _allProducts.length,
                      itemBuilder: (_, i) {
                        final p = _allProducts[i];
                        final isSelected = _selectedIds.contains(p.id);
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
                              child: Icon(
                                Icons.inventory_2_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${_currency.format(p.price)}${p.unitType != null ? ' / ${p.unitType}' : ''}',
                            ),
                            trailing: isSelected
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
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
                        ).animate().fadeIn(delay: (i * 30).ms).slideX(begin: 0.1);
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
