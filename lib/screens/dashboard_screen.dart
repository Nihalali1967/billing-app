import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/dashboard_provider.dart';
import 'bills/bill_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<DashboardProvider>().fetch());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final theme = Theme.of(context);

    if (provider.isLoading && provider.data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Failed to load dashboard', style: theme.textTheme.titleLarge),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(provider.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => provider.fetch(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final data = provider.data;
    if (data == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: provider.fetch,
      color: theme.colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        children: [
          // 4 Stat Cards (2x2 grid)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
            children: [
              _StatCard(
                title: 'Credit Balance',
                value: _currency.format(data.stats.totalCreditBalance),
                icon: Icons.warning_amber_rounded,
                gradient: data.stats.totalCreditBalance > 0
                    ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
                    : const [Color(0xFF10B981), Color(0xFF059669)],
                delay: 100,
              ),
              _StatCard(
                title: 'Extra Amount',
                value: _currency.format(data.stats.totalExtraAmount),
                icon: Icons.savings_rounded,
                gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                delay: 200,
              ),
              _StatCard(
                title: "Today's Sales",
                value: _currency.format(data.stats.todaySales),
                icon: Icons.trending_up_rounded,
                gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                delay: 300,
              ),
              _StatCard(
                title: "Today's Bills",
                value: data.stats.todayBillCount.toString(),
                icon: Icons.receipt_long_rounded,
                gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                delay: 400,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Quick Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _QuickStatItem(
                    label: 'Active Products',
                    value: data.quickStats.activeProducts.toString(),
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF6C5CE7),
                  ),
                ),
                Container(width: 1, height: 48, color: Colors.grey[200]),
                Expanded(
                  child: _QuickStatItem(
                    label: 'Total Customers',
                    value: data.quickStats.totalCustomers.toString(),
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

          // Recent Bills
          if (data.recentBills.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_rounded, color: Color(0xFF6C5CE7), size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Bills',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 14),
            ...data.recentBills.asMap().entries.map((e) {
              final i = e.key;
              final bill = e.value;
              final isPaid = bill.status != 'credit';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id)));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Bill number badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              bill.billNumber,
                              style: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
<<<<<<< HEAD
                          const SizedBox(width: 12),
                          // Customer info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.customerName.isNotEmpty ? bill.customerName : 'Walk-in',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
=======
                          child: const Icon(Icons.history_rounded, color: Colors.purple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Recent Bills',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),
                
                const SizedBox(height: 16),
                
                ...data.recentBills.asMap().entries.map((e) {
                  final i = e.key;
                  final bill = e.value;
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
                        onTap: () {
                          final billId = bill['id'];
                          if (billId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BillDetailScreen(billId: billId)),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [theme.colorScheme.primary.withOpacity(0.1), theme.colorScheme.primary.withOpacity(0.2)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
                                ),
                                if (bill.customerShop.isNotEmpty)
                                  Text(bill.customerShop, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                              ],
                            ),
                          ),
                          // Total + status
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_currency.format(bill.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPaid ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPaid ? 'Paid' : 'Credit',
                                  style: TextStyle(
                                    color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          // Time ago
                          Text(bill.timeAgo, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: (650 + (i * 80)).ms).slideX(begin: 0.05);
            }),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final int delay;

  const _StatCard({required this.title, required this.value, required this.icon, required this.gradient, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          Positioned(right: -8, bottom: -8, child: Icon(icon, size: 72, color: Colors.white.withOpacity(0.15))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, fontSize: 12)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: Colors.white, size: 14),
                    ),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: -0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).scale(begin: const Offset(0.9, 0.9));
  }
}

class _QuickStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[500])),
      ],
    );
  }
}
