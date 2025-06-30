import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/providers/commande_provider.dart';
import 'package:paragalien/providers/produit_provider.dart';
import 'command_history_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/servises/sendnotification.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class CommandeTab extends ConsumerStatefulWidget {
  final String userId;

  const CommandeTab({super.key, required this.userId});

  @override
  ConsumerState<CommandeTab> createState() => _CommandeTabState();
}

class _CommandeTabState extends ConsumerState<CommandeTab> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduits = ref.watch(selectedProduitsProvider);
    final total = selectedProduits.fold(
      0.0,
      (sum, item) => sum + (item.produit.price * item.quantity),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Commande'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _navigateToHistory(context),
            tooltip: 'Voir historique des commandes',
          ),
          if (selectedProduits.isNotEmpty && !_isSubmitting)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _submitOrder(ref),
              tooltip: 'Soumettre la commande',
            ),
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: selectedProduits.isEmpty
          ? const Center(child: Text('Aucun produit sélectionné'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      // Products list
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: selectedProduits.length,
                        itemBuilder: (context, index) {
                          return _buildSelectedProductItem(
                            selectedProduits[index],
                            ref,
                          );
                        },
                      ),

                      // Note input field
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: 'Ajouter une note (optionnel)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: const Color.fromARGB(255, 19, 19, 19),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                // Total price bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color.fromARGB(224, 31, 39, 37),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${total.toStringAsFixed(2)} DZD',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectedProductItem(
    SelectedProduct selectedProduct,
    WidgetRef ref,
  ) {
    final produit = selectedProduct.produit;
    final displayedQuantity = selectedProduct.quantity.truncate();
    final totalPrice = (produit.price * selectedProduct.quantity)
        .toStringAsFixed(2);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Product name (centered)
            Text(
              produit.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Price, quantity and total (spaced evenly)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${produit.price} DA'),
                Text(
                  '$displayedQuantity',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 34, 173, 39),
                  ),
                ),
                Text('$totalPrice DA'),
              ],
            ),
            const SizedBox(height: 8),
            // Edit and delete buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  onPressed: () => _showQuantityDialog(selectedProduct, ref),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => ref
                      .read(selectedProduitsProvider.notifier)
                      .remove(produit),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuantityDialog(
    SelectedProduct selectedProduct,
    WidgetRef ref,
  ) async {
    final produit = selectedProduct.produit;
    final controller = TextEditingController(
      text: selectedProduct.quantity.toStringAsFixed(
        selectedProduct.quantity.truncateToDouble() == selectedProduct.quantity
            ? 0
            : 1,
      ),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier quantité pour: ${produit.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Nouvelle quantité',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Quantité actuelle: ${selectedProduct.quantity}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final newQuantity =
                    double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
                if (newQuantity > 0 && newQuantity <= produit.quantity) {
                  final updatedProduct = selectedProduct.copyWith(
                    quantity: newQuantity,
                  );
                  ref
                      .read(selectedProduitsProvider.notifier)
                      .updateProduct(updatedProduct);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Veuillez entrer une quantité valide (0-${produit.quantity})',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitOrder(WidgetRef ref) async {
    if (_isSubmitting) return;

    final selectedProduits = ref.read(selectedProduitsProvider);
    final note = _noteController.text.trim();
    final notifier = ref.read(commandeNotifierProvider);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation de commande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Voulez-vous confirmer la commande ?'),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(note),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Submit order with timeout
      await notifier
          .submitOrderWithNotes(selectedProduits, widget.userId, note)
          .timeout(const Duration(seconds: 15));

      // Calculate order details for notification
      final totalItems = selectedProduits.fold(
        0,
        (sum, item) => sum + item.quantity.toInt(),
      );
      final totalPrice = selectedProduits.fold(
        0.0,
        (sum, item) => sum + (item.produit.price * item.quantity),
      );

      // Send notification to admins
      await OneSignalService.sendOrderNotification(
        userId: widget.userId,
        orderItems: selectedProduits.map((sp) => sp.toMap()).toList(),
        totalPrice: totalPrice,
        totalItems: totalItems,
        clientNote: note.isNotEmpty ? note : null,
      );

      // Clear cart
      ref.read(selectedProduitsProvider.notifier).clear();
      _noteController.clear();

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande soumise avec succès ! Les administrateurs ont été notifiés.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La commande a pris trop de temps. Veuillez réessayer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la soumission: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Order submission error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommandHistoryScreen(userId: widget.userId),
      ),
    );
  }
}