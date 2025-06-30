import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/models/produit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:typed_data';

class ProductsManagementScreen extends ConsumerStatefulWidget {
  const ProductsManagementScreen({super.key});

  @override
  ConsumerState<ProductsManagementScreen> createState() =>
      _ProductsManagementScreenState();
}

class _ProductsManagementScreenState
    extends ConsumerState<ProductsManagementScreen> {
  final _searchController = TextEditingController();
  List<Produit> _allProduits = [];
  List<Produit> _filteredProduits = [];
  bool _isLoading = true;
  bool _showPromotionsOnly = false;

  @override
  void initState() {
    super.initState();
    _loadProduits();
    _searchController.addListener(_filterProduits);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProduits() async {
    setState(() => _isLoading = true);
    try {
      // Fetch products along with their promotion status
      final response = await Supabase.instance.client
          .from('produits')
          .select('*, promotions!left(is_active)')
          .order('name');

      setState(() {
        _allProduits =
            response.map((p) {
              final isInPromotion =
                  (p['promotions'] as List).isNotEmpty &&
                  (p['promotions'][0]['is_active'] as bool);
              return Produit.fromJson(p)..isInPromotion = isInPromotion;
            }).toList();
        _filteredProduits = List.from(_allProduits);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: ${e.toString()}')),
        );
      }
    }
  }

  void _filterProduits() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProduits =
          _allProduits.where((produit) {
            final matchesSearch =
                produit.name.toLowerCase().contains(query) ||
                produit.price.toString().contains(query) ||
                produit.quantity.toString().contains(query);

            if (_showPromotionsOnly) {
              return matchesSearch && produit.isInPromotion;
            }
            return matchesSearch;
          }).toList();
    });
  }

  Future<void> _removeFromPromotion(Produit produit) async {
    try {
      // Update the promotion to inactive
      await Supabase.instance.client
          .from('promotions')
          .update({'is_active': false})
          .eq('product_id', produit.id);

      // Refresh the list
      _loadProduits();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${produit.name} retiré des promotions')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showPromotionsOnly
              ? 'Produits en promotion'
              : 'Gestion des Produits',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditProductDialog(context),
            tooltip: 'Ajouter un produit',
          ),
          IconButton(
            icon: Icon(
              Icons.local_offer,
              color: _showPromotionsOnly ? Colors.yellow : null,
            ),
            onPressed: () {
              setState(() {
                _showPromotionsOnly = !_showPromotionsOnly;
                _filterProduits();
              });
            },
            tooltip:
                _showPromotionsOnly
                    ? 'Voir tous les produits'
                    : 'Voir les promotions',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterProduits();
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProduits.isEmpty
                    ? Center(
                      child:
                          _searchController.text.isEmpty
                              ? Text(
                                _showPromotionsOnly
                                    ? 'Aucun produit en promotion'
                                    : 'Aucun produit trouvé',
                              )
                              : const Text(
                                'Aucun résultat pour cette recherche',
                              ),
                    )
                    : ListView.builder(
                      itemCount: _filteredProduits.length,
                      itemBuilder: (context, index) {
                        final produit = _filteredProduits[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading:
                                produit.imageUrl != null
                                    ? Image.network(
                                      produit.imageUrl!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                    : const Icon(Icons.shopping_bag),
                            title: Text(produit.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Prix: ${produit.price} DZD'),
                                Text('Stock: ${produit.quantity}'),
                                if (produit.isInPromotion)
                                  const Text(
                                    'En promotion',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditProductDialog(context, produit);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmation(context, produit);
                                } else if (value == 'promotion') {
                                  _showAddToPromotionDialog(context, produit);
                                } else if (value == 'remove_promotion') {
                                  _removeFromPromotion(produit);
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Modifier'),
                                  ),
                                  if (!produit.isInPromotion)
                                    const PopupMenuItem<String>(
                                      value: 'promotion',
                                      child: Text('Ajouter au promotions'),
                                    ),
                                  if (produit.isInPromotion)
                                    const PopupMenuItem<String>(
                                      value: 'remove_promotion',
                                      child: Text(
                                        'Retirer des promotions',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text(
                                      'Supprimer',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _showAddToPromotionDialog(BuildContext context, Produit produit) {
    final newPriceController = TextEditingController();
    final descriptionController = TextEditingController();

    bool isSaving = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Ajouter au promotions'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(produit.name),
                        subtitle: Text('Prix actuel: ${produit.price} DZD'),
                        leading:
                            produit.imageUrl != null
                                ? Image.network(
                                  produit.imageUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                                : const Icon(Icons.shopping_bag),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: newPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Nouveau prix promotionnel (DZD)*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Entrez un nombre valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description de la promotion',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSaving
                            ? null
                            : () async {
                              // Validate form
                              if (newPriceController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Veuillez entrer un prix promotionnel',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final newPrice = double.tryParse(
                                newPriceController.text,
                              );
                              if (newPrice == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Prix invalide'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setState(() => isSaving = true);

                              try {
                                // Add to promotions table
                                await Supabase.instance.client
                                    .from('promotions')
                                    .insert({
                                      'product_id': produit.id,
                                      'original_price': produit.price,
                                      'promotion_price': newPrice,
                                      'description':
                                          descriptionController.text.isNotEmpty
                                              ? descriptionController.text
                                              : null,
                                      'start_date':
                                          DateTime.now().toIso8601String(),
                                      'is_active': true,
                                    });

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Produit ajouté aux promotions',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => isSaving = false);
                                }
                              }
                            },
                    child:
                        isSaving
                            ? const CircularProgressIndicator()
                            : const Text('Enregistrer la promotion'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // Removed invalid onRefresh block.

  void _showEditProductDialog(BuildContext context, [Produit? produit]) async {
    final nameController = TextEditingController(text: produit?.name ?? '');
    final priceController = TextEditingController(
      text: produit?.price.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: produit?.quantity.toString() ?? '',
    );
    String? imagePath;
    Uint8List? imageBytes;
    bool isUploading = false;
    String? selectedCategory =
        produit?.category?.isNotEmpty == true ? produit!.category : null;
    bool shouldDeleteImage = false;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              const List<String> categories = [
                'Complément alimentaire',
                'matériale médicale',
                'antiseptique',
                'dermo cosmetique',
                'Article bébé',
              ];

              return AlertDialog(
                title: Text(
                  produit == null ? 'Ajouter un produit' : 'Modifier produit',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image preview section
                      if (isUploading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(),
                        )
                      else if (imageBytes != null ||
                          (produit?.imageUrl != null && !shouldDeleteImage))
                        Column(
                          children: [
                            Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  imageBytes != null
                                      ? Image.memory(
                                        imageBytes!,
                                        fit: BoxFit.cover,
                                      )
                                      : produit?.imageUrl != null
                                      ? Image.network(
                                        produit!.imageUrl!,
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            TextButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Supprimer image'),
                                        content: const Text(
                                          'Voulez-vous vraiment supprimer cette image?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('Annuler'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text(
                                              'Supprimer',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                );

                                if (confirm == true) {
                                  setState(() {
                                    imageBytes = null;
                                    imagePath = null;
                                    shouldDeleteImage = true;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Image supprimée'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Supprimer image',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),

                      // Image upload button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: const Text('Choisir une image'),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: false,
                            allowedExtensions: ['jpg', 'jpeg', 'png'],
                          );

                          if (result != null &&
                              result.files.single.path != null) {
                            final file = File(result.files.single.path!);
                            final bytes = await file.readAsBytes();

                            if (bytes.length > 5 * 1024 * 1024) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'L\'image ne doit pas dépasser 5MB',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              return;
                            }

                            setState(() {
                              imagePath = result.files.single.path!;
                              imageBytes = bytes;
                              shouldDeleteImage = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Category dropdown
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value:
                            categories.contains(selectedCategory)
                                ? selectedCategory
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie*',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('catégorie'),
                          ),
                          ...categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }),
                        ],
                        validator:
                            (value) =>
                                value == null
                                    ? 'Ce champ est obligatoire'
                                    : null,
                        onChanged: (value) {
                          setState(() => selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Product form fields
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du produit*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Prix (DZD)*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Entrez un nombre valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantité en stock*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Entrez un nombre valide';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isUploading
                            ? null
                            : () async {
                              // Validate form
                              if (nameController.text.isEmpty ||
                                  priceController.text.isEmpty ||
                                  quantityController.text.isEmpty ||
                                  selectedCategory == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Veuillez remplir tous les champs obligatoires',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setState(() => isUploading = true);
                              String? imageUrl;

                              try {
                                // Handle image deletion if marked for deletion
                                if (shouldDeleteImage &&
                                    produit?.imageUrl != null) {
                                  try {
                                    final oldFileName =
                                        produit!.imageUrl!.split('/').last;
                                    await Supabase.instance.client.storage
                                        .from('paragalien.photos')
                                        .remove([oldFileName]);
                                  } catch (e) {
                                    print('Error deleting old image: $e');
                                  }
                                }

                                // Upload new image if selected
                                if (imageBytes != null) {
                                  // Delete old image if exists
                                  if (produit?.imageUrl != null &&
                                      !shouldDeleteImage) {
                                    try {
                                      final oldFileName =
                                          produit!.imageUrl!.split('/').last;
                                      await Supabase.instance.client.storage
                                          .from('paragalien.photos')
                                          .remove([oldFileName]);
                                    } catch (e) {
                                      print('Error deleting old image: $e');
                                    }
                                  }

                                  // Generate unique filename
                                  final fileName =
                                      '${DateTime.now().millisecondsSinceEpoch}${path.extension(imagePath!)}';

                                  // Upload to Supabase storage
                                  await Supabase.instance.client.storage
                                      .from('paragalien.photos')
                                      .uploadBinary(fileName, imageBytes!);

                                  // Get public URL
                                  imageUrl = Supabase.instance.client.storage
                                      .from('paragalien.photos')
                                      .getPublicUrl(fileName);
                                }

                                // Prepare product data
                                final newProduit = {
                                  'name': nameController.text.trim(),
                                  'Price':
                                      double.tryParse(priceController.text) ??
                                      0,
                                  'Stock ( Unité )':
                                      double.tryParse(
                                        quantityController.text,
                                      ) ??
                                      0,
                                  'image_url':
                                      shouldDeleteImage
                                          ? null
                                          : (imageUrl ?? produit?.imageUrl),
                                  'category': selectedCategory,
                                  'updated_at':
                                      DateTime.now().toIso8601String(),
                                };

                                if (produit == null) {
                                  // Add new product
                                  await Supabase.instance.client
                                      .from('produits')
                                      .insert(newProduit);
                                } else {
                                  // Update existing product
                                  await Supabase.instance.client
                                      .from('produits')
                                      .update(newProduit)
                                      .eq('id', produit.id);
                                }

                                if (mounted) {
                                  Navigator.pop(context);
                                  _loadProduits(); // Refresh the list
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        produit == null
                                            ? 'Produit ajouté avec succès'
                                            : 'Produit mis à jour',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => isUploading = false);
                                }
                              }
                            },
                    child:
                        isUploading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Enregistrer'),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Produit produit) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Supprimer ${produit.name}? Cette action est irréversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  try {
                    await Supabase.instance.client
                        .from('produits')
                        .delete()
                        .eq('id', produit.id);

                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {}); // Refresh the list
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Produit supprimé avec succès'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }
}
