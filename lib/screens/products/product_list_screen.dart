import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final products = await context.read<ProductProvider>().getAllProducts();
    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _allProducts = products;
      _filteredProducts = products;
      _loading = false;
    });
  }

  void _filterProducts() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) {
          return p.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Products Inventory'),
      ),
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.05),
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
                      hintText: 'Search products by name or barcode...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _filterProducts();
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
                    onChanged: (v) => _filterProducts(),
                  ),
                ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              ),

              // Product List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
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
                                  child: Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No products found',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your first product to get started',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().scale(delay: 200.ms)
                        : RefreshIndicator(
                            onRefresh: _loadProducts,
                            color: theme.colorScheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final p = _filteredProducts[index];
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
                                            builder: (_) => ProductFormScreen(product: p),
                                          ),
                                        );
                                        if (result == true) _loadProducts();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Hero(
                                              tag: 'product_icon_${p.id}',
                                              child: Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: p.isActive
                                                        ? [theme.colorScheme.primary.withOpacity(0.8), theme.colorScheme.primary]
                                                        : [Colors.grey[300]!, Colors.grey[400]!],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: [
                                                    if (p.isActive)
                                                      BoxShadow(
                                                        color: theme.colorScheme.primary.withOpacity(0.3),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  Icons.inventory_2_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          p.name,
                                                          style: theme.textTheme.titleMedium?.copyWith(
                                                            fontWeight: FontWeight.bold,
                                                            color: p.isActive ? Colors.grey[900] : Colors.grey[500],
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (!p.isActive)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: const Text(
                                                            'INACTIVE',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        _currency.format(p.price),
                                                        style: TextStyle(
                                                          color: theme.colorScheme.primary,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      if (p.unitType != null && p.unitType!.isNotEmpty) ...[
                                                        Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                                          child: Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
                                                        ),
                                                        Text(
                                                          '/ ${p.unitType}',
                                                          style: TextStyle(
                                                            color: Colors.grey[500],
                                                            fontWeight: FontWeight.w500,
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
                                                  child: Row(children: [Icon(Icons.edit_rounded, size: 20), SizedBox(width: 12), Text('Edit Product')]),
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
                                                      builder: (_) => ProductFormScreen(product: p),
                                                    ),
                                                  );
                                                  if (result == true) _loadProducts();
                                                } else if (val == 'delete') {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                                      title: const Text('Delete Product'),
                                                      content: Text('Are you sure you want to delete "${p.name}"? This action cannot be undone.'),
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
                                                    final deleted = await provider.deleteProduct(p.id);
                                                    if (deleted && mounted) {
                                                      setState(() {
                                                        _allProducts.removeWhere((item) => item.id == p.id);
                                                        _filteredProducts.removeWhere((item) => item.id == p.id);
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
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
          if (result == true) _loadProducts();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Product', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
    );
  }
}
