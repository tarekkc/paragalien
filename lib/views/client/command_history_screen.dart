// IMPORTS
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/history_provider.dart';
import '../../models/orderhistory.dart';

class CommandHistoryScreen extends ConsumerWidget {
  final String userId;

  const CommandHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(orderHistoryProvider(userId)),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading orders',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(orderHistoryProvider(userId)),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text('No orders found', style: TextStyle(fontSize: 18)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderHistoryProvider(userId));
              await ref.read(orderHistoryProvider(userId).future);
            },
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder:
                  (context, index) =>
                      _buildOrderCard(context, ref, orders[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    WidgetRef ref,
    OrderHistory order,
  ) {
    final total = order.items.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    final shortId =
        order.id.length > 8
            ? '${order.id.substring(0, 4)}...${order.id.substring(order.id.length - 4)}'
            : order.id;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: ExpansionTile(
        title: Text('Order #$shortId'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, yyyy - hh:mm a').format(order.date),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${NumberFormat.currency(symbol: 'DA ', decimalDigits: 2).format(total)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    order.isApproved ? 'Approved' : 'Pending',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor:
                      order.isApproved ? Colors.green : Colors.orange,
                ),
                Text(
                  '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(),
          if (order.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No items in this order'),
            )
          else
            ...order.items.map(
              (item) => _buildOrderItem(context, ref, order, item),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ORDER TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  NumberFormat.currency(
                    symbol: 'DA ',
                    decimalDigits: 2,
                  ).format(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(
    BuildContext context,
    WidgetRef ref,
    OrderHistory order,
    OrderItem item,
  ) {
    return Dismissible(
      key: Key(item.id),
      direction:
          order.isApproved
              ? DismissDirection.none
              : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (order.isApproved) return false;
        return await _showDeleteConfirmation(context, ref, order.id, item.id);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 53, 53, 53),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              item.quantity.toInt().toString(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            NumberFormat.currency(
              symbol: 'DA ',
              decimalDigits: 2,
            ).format(item.price),
          ),
          trailing:
              order.isApproved
                  ? Text(
                    NumberFormat.currency(
                      symbol: 'DA ',
                      decimalDigits: 2,
                    ).format(item.price * item.quantity),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed:
                            () => _updateQuantity(
                              context,
                              ref,
                              order.id,
                              item.id,
                              item.quantity - 1,
                            ),
                      ),
                      Text(
                        item.quantity.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed:
                            () => _updateQuantity(
                              context,
                              ref,
                              order.id,
                              item.id,
                              item.quantity + 1,
                            ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    String itemId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Item'),
            content: const Text(
              'Are you sure you want to remove this item from your order?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final params = OrderParams(orderId: orderId, userId: userId);
        final notifier = ref.read(orderModificationProvider(params).notifier);
        await notifier.removeItem(itemId);
        await notifier.recalculateOrderTotal();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed successfully')),
        );
        return true;
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        return false;
      }
    }
    return false;
  }

  Future<void> _updateQuantity(
  BuildContext context,
  WidgetRef ref,
  String orderId,
  String itemId,
  double newQuantity,
) async {
  try {
    if (newQuantity <= 0) {
      await _showDeleteConfirmation(context, ref, orderId, itemId);
      return;
    }

    final params = OrderParams(orderId: orderId, userId: userId);
    final notifier = ref.read(orderModificationProvider(params).notifier);
    await notifier.updateItemQuantity(itemId, newQuantity);
    await notifier.recalculateOrderTotal();

    // 🔄 Rafraîchir manuellement l'historique
    ref.invalidate(orderHistoryProvider(userId));
    await ref.read(orderHistoryProvider(userId).future);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}

}
