import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_config.dart';
import '../../providers/inventory_provider.dart';
import '../../models/product.dart';
import '../../models/variant.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _skuController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minStockController = TextEditingController();

  bool _isLoading = false;
  bool _showAdvanced = false;
  String? _imageUrl;
  File? _imageFile;
  String? _selectedVendorId;
  Product? _existingProduct;

  // Variant attributes
  final Map<String, String> _variantAttributes = {};
  final _attributeKeyController = TextEditingController();
  final _attributeValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    final provider = context.read<InventoryProvider>();
    final product = await provider.getProduct(widget.productId!);

    if (product != null && mounted) {
      setState(() {
        _existingProduct = product;
        _nameController.text = product.name;
        _descriptionController.text = product.description ?? '';
        _categoryController.text = product.category ?? '';
        _imageUrl = product.imageUrl;
        _selectedVendorId = product.vendorId;

        // Load first variant data
        if (product.variants.isNotEmpty) {
          final variant = product.variants.first;
          _skuController.text = variant.sku;
          _salePriceController.text = variant.salePrice.toString();
          _purchasePriceController.text = variant.purchasePrice?.toString() ?? '';
          _quantityController.text = variant.quantity.toString();
          _minStockController.text = variant.minStockLevel?.toString() ?? '';
          _variantAttributes.addAll(variant.attributes);
        }
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _skuController.dispose();
    _salePriceController.dispose();
    _purchasePriceController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _attributeKeyController.dispose();
    _attributeValueController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppConfig.errorColor),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      final provider = context.read<InventoryProvider>();
      final success = await provider.deleteProduct(widget.productId!);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: AppConfig.successColor,
          ),
        );
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${provider.error}'),
            backgroundColor: AppConfig.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<InventoryProvider>();

      // Upload image if new one selected
      String? uploadedImageUrl = _imageUrl;
      if (_imageFile != null) {
        uploadedImageUrl = await provider.uploadImage(_imageFile);
        if (uploadedImageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      // Create variant
      final variant = Variant(
        id: _existingProduct?.variants.first.id ?? '',
        productId: widget.productId ?? '',
        sku: _skuController.text,
        attributes: _variantAttributes,
        salePrice: double.parse(_salePriceController.text),
        purchasePrice: _purchasePriceController.text.isNotEmpty
            ? double.parse(_purchasePriceController.text)
            : null,
        quantity: int.parse(_quantityController.text),
        minStockLevel: _minStockController.text.isNotEmpty
            ? int.parse(_minStockController.text)
            : null,
      );

      // Create product
      final product = Product(
        id: widget.productId ?? '',
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        category: _categoryController.text.isNotEmpty
            ? _categoryController.text
            : null,
        imageUrl: uploadedImageUrl,
        vendorId: _selectedVendorId,
        variants: [variant],
      );

      bool success;
      if (widget.productId != null) {
        success = await provider.updateProduct(widget.productId!, product);
      } else {
        success = await provider.createProduct(product);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productId != null
                ? 'Product updated successfully'
                : 'Product created successfully'),
            backgroundColor: AppConfig.successColor,
          ),
        );
        context.pop();
      } else if (mounted) {
        throw Exception(provider.error ?? 'Failed to save product');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppConfig.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId != null ? 'Edit Product' : 'Add Product'),
        actions: widget.productId != null
            ? [
                IconButton(
                  icon: const Icon(Icons.inventory),
                  onPressed: () {
                    context.push('/inventory/stock-adjustment/${widget.productId}');
                  },
                  tooltip: 'Adjust Stock',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteProduct,
                  tooltip: 'Delete Product',
                ),
              ]
            : null,
      ),
      body: _isLoading && _existingProduct == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic section header
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product name (required)
                    CustomTextField(
                      controller: _nameController,
                      label: 'Product Name *',
                      hint: 'e.g., Blue T-Shirt',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Sale price (required)
                    CustomTextField(
                      controller: _salePriceController,
                      label: 'Sale Price *',
                      hint: '0.00',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Sale price is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Quantity (required)
                    CustomTextField(
                      controller: _quantityController,
                      label: 'Quantity *',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Quantity is required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Enter a valid quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // SKU (required)
                    CustomTextField(
                      controller: _skuController,
                      label: 'SKU *',
                      hint: 'e.g., BLU-TSH-001',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'SKU is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Advanced section toggle
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showAdvanced = !_showAdvanced;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              _showAdvanced
                                  ? Icons.arrow_drop_down
                                  : Icons.arrow_right,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Advanced Options',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Advanced section
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),

                      // Product image
                      const Text(
                        'Product Image',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppConfig.secondaryBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _imageFile!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : _imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        _imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_photo_alternate, size: 50),
                                                SizedBox(height: 8),
                                                Text('Tap to select image'),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate, size: 50),
                                          SizedBox(height: 8),
                                          Text('Tap to select image'),
                                        ],
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      CustomTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Product description...',
                      ),
                      const SizedBox(height: 16),

                      // Category
                      CustomTextField(
                        controller: _categoryController,
                        label: 'Category',
                        hint: 'e.g., Clothing',
                      ),
                      const SizedBox(height: 16),

                      // Vendor
                      Consumer<InventoryProvider>(
                        builder: (context, provider, child) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vendor',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedVendorId,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                hint: const Text('Select vendor'),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('No vendor'),
                                  ),
                                  ...provider.vendors.map((vendor) {
                                    return DropdownMenuItem(
                                      value: vendor.id,
                                      child: Text(vendor.name),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedVendorId = value;
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Purchase price
                      CustomTextField(
                        controller: _purchasePriceController,
                        label: 'Purchase Price',
                        hint: '0.00',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Min stock level
                      CustomTextField(
                        controller: _minStockController,
                        label: 'Low Stock Alert Level',
                        hint: 'e.g., 10',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Variant attributes
                      const Text(
                        'Variant Attributes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ..._variantAttributes.entries.map((entry) {
                            return Chip(
                              label: Text('${entry.key}: ${entry.value}'),
                              onDeleted: () {
                                setState(() {
                                  _variantAttributes.remove(entry.key);
                                });
                              },
                            );
                          }),
                          ActionChip(
                            label: const Text('+ Add Attribute'),
                            onPressed: _showAddAttributeDialog,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Save button
                    CustomButton(
                      text: widget.productId != null ? 'Update Product' : 'Create Product',
                      onPressed: _saveProduct,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showAddAttributeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Attribute'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _attributeKeyController,
                decoration: const InputDecoration(
                  labelText: 'Attribute Name',
                  hintText: 'e.g., Size, Color',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _attributeValueController,
                decoration: const InputDecoration(
                  labelText: 'Attribute Value',
                  hintText: 'e.g., Large, Red',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_attributeKeyController.text.isNotEmpty &&
                    _attributeValueController.text.isNotEmpty) {
                  setState(() {
                    _variantAttributes[_attributeKeyController.text] =
                        _attributeValueController.text;
                  });
                  _attributeKeyController.clear();
                  _attributeValueController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
