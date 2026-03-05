import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/user_provider.dart';
import 'user_form_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<UserProvider>().fetch());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    context.read<UserProvider>().fetch(search: _searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('User Management'),
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
                color: theme.colorScheme.secondary.withOpacity(0.05),
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
                      hintText: 'Search users...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _search();
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
                    onChanged: (v) => setState(() {}),
                    onSubmitted: (_) => _search(),
                  ),
                ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              ),

              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.group_off_rounded, size: 64, color: theme.colorScheme.secondary),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No users found',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().scale(delay: 200.ms)
                        : RefreshIndicator(
                            onRefresh: () => provider.fetch(search: _searchController.text.trim()),
                            color: theme.colorScheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: provider.users.length,
                              itemBuilder: (context, index) {
                                final u = provider.users[index];
                                final isAdmin = u.role == 'admin';
                                
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
                                    border: Border.all(
                                      color: isAdmin ? Colors.purple.withOpacity(0.1) : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Hero(
                                          tag: 'user_avatar_${u.id}',
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: u.isActive
                                                    ? isAdmin
                                                        ? [Colors.purple[400]!, Colors.purple[600]!]
                                                        : [theme.colorScheme.primary.withOpacity(0.8), theme.colorScheme.primary]
                                                    : [Colors.grey[300]!, Colors.grey[400]!],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                if (u.isActive)
                                                  BoxShadow(
                                                    color: (isAdmin ? Colors.purple : theme.colorScheme.primary).withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                u.name[0].toUpperCase(),
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
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      u.name,
                                                      style: theme.textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                        color: u.isActive ? Colors.grey[900] : Colors.grey[500],
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (!u.isActive)
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
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isAdmin ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded, size: 12, color: isAdmin ? Colors.purple[700] : Colors.blue[700]),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          u.role.toUpperCase(),
                                                          style: TextStyle(color: isAdmin ? Colors.purple[700] : Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text('@${u.username}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.phone_rounded, size: 12, color: Colors.grey[400]),
                                                  const SizedBox(width: 4),
                                                  Text(u.mobile, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
                                              child: Row(children: [Icon(Icons.edit_rounded, size: 20), SizedBox(width: 12), Text('Edit User')]),
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
                                                  builder: (_) => UserFormScreen(user: u),
                                                ),
                                              );
                                              if (result == true) provider.fetch();
                                            } else if (val == 'delete') {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                                  title: const Text('Delete User'),
                                                  content: Text('Are you sure you want to delete "${u.name}"?'),
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
                                                await provider.deleteUser(u.id);
                                              }
                                            }
                                          },
                                        ),
                                      ],
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
            MaterialPageRoute(builder: (_) => const UserFormScreen()),
          );
          if (result == true) provider.fetch();
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New User', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
    );
  }
}
