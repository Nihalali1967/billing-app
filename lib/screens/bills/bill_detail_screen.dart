import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import '../../models/bill.dart';
import '../../providers/bill_provider.dart';

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
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _loadBill();
    _initBluetooth();
  }

  @override
  void dispose() {
    _bluetoothPrint.disconnect();
    super.dispose();
  }

  void _initBluetooth() {
    _bluetoothPrint.state.listen((state) {
      switch (state) {
        case BluetoothPrint.CONNECTED:
          setState(() {
            _connected = true;
            _isPrinting = false;
          });
          break;
        case BluetoothPrint.DISCONNECTED:
          setState(() {
            _connected = false;
            _isPrinting = false;
          });
          break;
        default:
          break;
      }
    });

    // Check if Bluetooth is available (async check not needed here)
    // Will handle availability when scanning
  }

  Future<void> _scanDevices() async {
    await _bluetoothPrint.startScan(timeout: Duration(seconds: 4));
    _bluetoothPrint.scanResults.listen((results) {
      setState(() {
        _devices = results;
      });
    });
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    setState(() {
      _isPrinting = true;
    });
    await _bluetoothPrint.connect(device);
  }

  Future<void> _disconnectDevice() async {
    await _bluetoothPrint.disconnect();
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
    if (_bill == null) return;
    
    // Create bill details text for sharing
    final billDetails = '''
Bill Details
=============
Bill Number: ${_bill!.billNumber}
Date: ${_bill!.createdAt != null ? DateFormat('dd MMM yyyy').format(_bill!.createdAt!) : 'N/A'}
Customer: ${_bill!.customerName ?? 'N/A'}

Items:
${_bill!.items.map((item) => '${item.quantity}x ${item.productName ?? 'Product'} - ${_currency.format(item.lineTotal)}').join('\n')}

Subtotal: ${_currency.format(_bill!.subtotal)}
Discount: ${_currency.format(_bill!.discount)}
Total: ${_currency.format(_bill!.total)}
Collected: ${_currency.format(_bill!.collectedAmount)}
${_bill!.creditAmount > 0 ? 'Credit: ${_currency.format(_bill!.creditAmount)}' : ''}

Notes: ${_bill!.notes?.isNotEmpty == true ? _bill!.notes : 'N/A'}
''';

    // Show share options dialog
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('Share Bill', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1,
                    children: [
                      _buildShareOption(
                        icon: Icons.message,
                        label: 'WhatsApp',
                        color: Colors.green,
                        onTap: () => _shareToWhatsApp(billDetails),
                      ),
                      _buildShareOption(
                        icon: Icons.sms,
                        label: 'SMS',
                        color: Colors.blue,
                        onTap: () => _shareToSMS(billDetails),
                      ),
                      _buildShareOption(
                        icon: Icons.email,
                        label: 'Email',
                        color: Colors.red,
                        onTap: () => _shareToEmail(billDetails),
                      ),
                      _buildShareOption(
                        icon: Icons.more_horiz,
                        label: 'More',
                        color: Colors.grey,
                        onTap: () => _shareToSystem(billDetails),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToWhatsApp(String text) async {
    final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
    final uri = Uri.parse(whatsappUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not available')),
      );
    }
  }

  Future<void> _shareToSMS(String text) async {
    final smsUrl = 'sms:?body=${Uri.encodeComponent(text)}';
    final uri = Uri.parse(smsUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS not available')),
      );
    }
  }

  Future<void> _shareToEmail(String text) async {
    final emailUrl = 'mailto:?subject=Bill Details&body=${Uri.encodeComponent(text)}';
    final uri = Uri.parse(emailUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not available')),
      );
    }
  }

  Future<void> _shareToSystem(String text) async {
    try {
      await Share.share(text, subject: 'Bill Details');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing: $e')),
      );
    }
  }

  Future<void> _printBill() async {
    if (_bill == null) return;

    try {
      // Show printer selection dialog
      await _showPrinterSelectionDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e')),
      );
    }
  }

  Future<void> _showPrinterSelectionDialog() async {
    await _scanDevices();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.print_rounded),
              const SizedBox(width: 8),
              const Text('Select Printer'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                if (_devices.isEmpty)
                  const Center(child: Text('No printers found'))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return ListTile(
                          leading: const Icon(Icons.bluetooth_rounded),
                          title: Text(device.name ?? 'Unknown Device'),
                          subtitle: Text(device.address ?? 'No Address'),
                          onTap: () async {
                            Navigator.pop(context);
                            await _connectAndPrint(device);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _scanDevices();
                        },
                        child: const Text('Rescan'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
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
  }

  Future<void> _connectAndPrint(BluetoothDevice device) async {
    setState(() {
      _isPrinting = true;
    });

    try {
      await _connectDevice(device);
      
      // Generate receipt data
      final receiptData = await _generateLineTextData();
      
      // Create Map for printReceipt
      final receiptMap = {
        'title': 'Bill Receipt',
        'lines': receiptData,
      };
      
      // Print the receipt
      await _bluetoothPrint.printReceipt(receiptMap, receiptData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill printed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    } finally {
      await _disconnectDevice();
      setState(() {
        _isPrinting = false;
      });
    }
  }

  Future<List<LineText>> _generateLineTextData() async {
    if (_bill == null) return [];

    List<LineText> lines = [];
    
    // Add header
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'BILL RECEIPT',
      weight: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    // Bill details
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Bill No: ${_bill!.billNumber}',
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Date: ${_bill!.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(_bill!.createdAt!) : 'N/A'}',
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Customer: ${_bill!.customerName ?? 'N/A'}',
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    // Divider
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    // Items header
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Item          Qty   Price   Total',
      weight: 1,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    // Items
    for (final item in _bill!.items) {
      final itemName = (item.productName ?? 'Product').padRight(12).substring(0, 12);
      final quantity = item.quantity.toStringAsFixed(0).padLeft(3);
      final price = _currency.format(item.effectivePrice).substring(1).padLeft(7);
      final total = _currency.format(item.lineTotal).substring(1).padLeft(7);
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '$itemName$quantity  $price  $total',
        weight: 0,
        align: LineText.ALIGN_LEFT,
        linefeed: 1,
      ));
    }
    
    // Divider
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    // Totals
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Subtotal:'.padRight(16) + _currency.format(_bill!.subtotal).substring(1).padLeft(8),
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    if (_bill!.discount > 0) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Discount:'.padRight(16) + '-${_currency.format(_bill!.discount).substring(1)}'.padLeft(8),
        weight: 0,
        align: LineText.ALIGN_LEFT,
        linefeed: 1,
      ));
    }
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'TOTAL:'.padRight(16) + _currency.format(_bill!.total).substring(1).padLeft(8),
      weight: 1,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    // Divider
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    // Payment details
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Collected:'.padRight(16) + _currency.format(_bill!.collectedAmount).substring(1).padLeft(8),
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));
    
    if (_bill!.creditAmount > 0) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Credit:'.padRight(16) + _currency.format(_bill!.creditAmount).substring(1).padLeft(8),
        weight: 0,
        align: LineText.ALIGN_LEFT,
        linefeed: 1,
      ));
    }
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '',
      weight: 0,
      align: LineText.ALIGN_LEFT,
      linefeed: 2,
    ));
    
    // Footer
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Thank you for your business!',
      weight: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Visit again!',
      weight: 0,
      align: LineText.ALIGN_CENTER,
      linefeed: 3,
    ));
    
    return lines;
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
                                bill.billedBy ?? '',
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
                                      item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 2),
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
        ],
      ),
    );
  }

  Future<void> _showPrintPreview() async {
    final printData = await context.read<BillProvider>().getPrintData(widget.billId);
    if (printData == null || !mounted) return;

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
                            if (printData['customer']['mobile'] != null)
                              Text(printData['customer']['mobile']),
                          ],
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('----------------------------------------', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(color: Colors.grey))),
                          Row(
                            children: const [
                              Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...(printData['items'] as List? ?? []).map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: Text('${item['name']}', style: const TextStyle(fontSize: 12))),
                                Expanded(flex: 1, child: Text('${item['qty']}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                Expanded(flex: 2, child: Text(_currency.format((item['total'] ?? 0).toDouble()), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                              ],
                            ),
                          )),
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
                          Text('Billed by: ${printData['billed_by'] ?? ''}', style: const TextStyle(fontSize: 11)),
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
