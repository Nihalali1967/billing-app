import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _searchController = TextEditingController();
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    final customers = await context.read<CustomerProvider>().fetchAll();
    customers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) {
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((c) {
          final nameMatch = c.name.toLowerCase().contains(query);
          final shopMatch = c.shopName?.toLowerCase().contains(query) ?? false;
          final mobileMatch = c.mobile.contains(query);
          return nameMatch || shopMatch || mobileMatch;
        }).toList();
        // Sort: items starting with query first
        _filteredCustomers.sort((a, b) {
          final aStarts = a.name.toLowerCase().startsWith(query) ||
              (a.shopName?.toLowerCase().startsWith(query) ?? false);
          final bStarts = b.name.toLowerCase().startsWith(query) ||
              (b.shopName?.toLowerCase().startsWith(query) ?? false);
          if (aStarts && !bStarts) return -1;
          if (!aStarts && bStarts) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.tertiary.withOpacity(0.05),
              ),
            ),
          ),
          
          Column(
            children: [
              // Premium Search Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or shop...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _filterCustomers();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (v) => _filterCustomers(),
                  ),
                ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredCustomers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.people_outline_rounded, size: 64, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No customers found',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your first customer to get started',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().scale(delay: 200.ms)
                        : RefreshIndicator(
                            onRefresh: _loadCustomers,
                            color: theme.colorScheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: _filteredCustomers.length,
                              itemBuilder: (context, index) {
                                final c = _filteredCustomers[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CustomerFormScreen(customer: c),
                                          ),
                                        );
                                        if (result == true) {
                                          _loadCustomers();
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Hero(
                                              tag: 'customer_avatar_${c.id}',
                                              child: Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [theme.colorScheme.secondary.withOpacity(0.8), theme.colorScheme.secondary],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: theme.colorScheme.secondary.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    c.name[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.name,
                                                    style: theme.textTheme.titleMedium?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey[900],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.phone_rounded, size: 14, color: Colors.grey[500]),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        c.mobile,
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontWeight: FontWeight.w500,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      if (c.shopName != null && c.shopName!.isNotEmpty) ...[
                                                        Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                                          child: Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
                                                        ),
                                                        Icon(Icons.store_rounded, size: 14, color: Colors.grey[500]),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            c.shopName!,
                                                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton(
                                              icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(children: [Icon(Icons.edit_rounded, size: 20), SizedBox(width: 12), Text('Edit')]),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(children: [Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red[400]), const SizedBox(width: 12), Text('Delete', style: TextStyle(color: Colors.red[400]))]),
                                                ),
                                              ],
                                              onSelected: (val) async {
                                                if (val == 'edit') {
                                                  final result = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => CustomerFormScreen(customer: c),
                                                    ),
                                                  );
                                                  if (result == true) _loadCustomers();
                                                } else if (val == 'delete') {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                                      title: const Text('Delete Customer'),
                                                      content: Text('Are you sure you want to delete "${c.name}"?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, false),
                                                          child: const Text('Cancel'),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                          child: const Text('Delete'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    final deleted = await provider.deleteCustomer(c.id);
                                                    if (deleted && mounted) {
                                                      setState(() {
                                                        _allCustomers.removeWhere((item) => item.id == c.id);
                                                        _filteredCustomers.removeWhere((item) => item.id == c.id);
                                                      });
                                                    }
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                              },
                            ),
                          ),
              ),
              
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
          );
          if (result == true) _loadCustomers();
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New Customer', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
    );
  }
}
