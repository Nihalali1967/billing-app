import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/bill_provider.dart';
import 'bill_detail_screen.dart';

class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  final _searchController = TextEditingController();
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<BillProvider>().fetch());
  }

  void _search() {
    context.read<BillProvider>().fetch(
          search: _searchController.text.trim(),
          dateFrom: _dateRange?.start.toIso8601String().split('T')[0],
          dateTo: _dateRange?.end.toIso8601String().split('T')[0],
        );
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() => _dateRange = range);
      _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    final theme = Theme.of(context);

    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search bills...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _search();
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() {}),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _dateRange != null
                        ? theme.colorScheme.primaryContainer
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _dateRange == null ? Icons.calendar_month_outlined : Icons.calendar_month,
                      color: _dateRange != null ? theme.colorScheme.primary : Colors.grey[600],
                    ),
                    onPressed: _selectDateRange,
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500], size: 20),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _search();
                    },
                  ),
              ],
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),
          ),
          const SizedBox(height: 8),

          // Total count
          if (provider.total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '${provider.total} bills found',
                style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),

          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.bills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No bills found',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      ).animate().fadeIn()
                    : RefreshIndicator(
                        onRefresh: () => provider.fetch(
                          search: _searchController.text.trim(),
                          dateFrom: _dateRange?.start.toIso8601String().split('T')[0],
                          dateTo: _dateRange?.end.toIso8601String().split('T')[0],
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: provider.bills.length,
                          itemBuilder: (context, index) {
                            final b = provider.bills[index];

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => BillDetailScreen(billId: b.id)),
                                  );
                                  provider.fetch(
                                    search: _searchController.text.trim(),
                                    dateFrom: _dateRange?.start.toIso8601String().split('T')[0],
                                    dateTo: _dateRange?.end.toIso8601String().split('T')[0],
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              b.billNumber,
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            b.date ?? (b.createdAt != null
                                                ? DateFormat('dd MMM, hh:mm a').format(b.createdAt!.toLocal())
                                                : ''),
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.grey[100],
                                            child: Icon(Icons.person_outline, color: Colors.grey[600], size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  b.customerName ?? 'Walk-in Customer',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (b.customerShop != null && b.customerShop!.isNotEmpty)
                                                  Text(
                                                    b.customerShop!,
                                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _currency.format(b.total),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (b.hasCredit)
                                                Text(
                                                  'Cr: ${_currency.format(b.creditAmount)}',
                                                  style: TextStyle(color: Colors.orange[700], fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                          },
                        ),
                      ),
          ),
          if (provider.lastPage > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: provider.currentPage > 1
                        ? () => provider.fetch(
                              search: _searchController.text.trim(),
                              page: provider.currentPage - 1,
                              dateFrom: _dateRange?.start.toIso8601String().split('T')[0],
                              dateTo: _dateRange?.end.toIso8601String().split('T')[0],
                            )
                        : null,
                  ),
                  Text('Page ${provider.currentPage} of ${provider.lastPage}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: provider.currentPage < provider.lastPage
                        ? () => provider.fetch(
                              search: _searchController.text.trim(),
                              page: provider.currentPage + 1,
                              dateFrom: _dateRange?.start.toIso8601String().split('T')[0],
                              dateTo: _dateRange?.end.toIso8601String().split('T')[0],
                            )
                        : null,
                  ),
                ],
              ),
            ).animate().slideY(begin: 1, end: 0),
        ],
    );
  }
}
