import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/views/admin/orders_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/views/admin/products_mangment.dart';
import 'package:paragalien/views/admin/manage_users.dart';

class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: const OrdersScreen(), // Shows all orders by default
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(child: Text('Admin Menu')),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('All Orders'),
              onTap: () {
                Navigator.pop(context);
                // Already on OrdersScreen
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              onTap: () {
                // Implement user management
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminUsersScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.article),
              title: const Text('Manage Products'),
              onTap: () {
                // Implement user management
                // In your admin menu or navigation
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductsManagementScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
