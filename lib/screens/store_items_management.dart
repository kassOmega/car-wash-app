import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store_item.dart';
import '../services/firebase_service.dart';

class StoreItemsManagement extends StatefulWidget {
  const StoreItemsManagement({super.key});

  @override
  _StoreItemsManagementState createState() => _StoreItemsManagementState();
}

class _StoreItemsManagementState extends State<StoreItemsManagement> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();

  bool _isLoading = false;
  bool _showForm = false;
  StoreItem? _editingItem;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _stockController.clear();
    _minStockController.clear();
    _editingItem = null;
    setState(() => _showForm = false);
  }

  void _editItem(StoreItem item) {
    _nameController.text = item.name;
    _descriptionController.text = item.description;
    _priceController.text = item.sellingPrice.toStringAsFixed(0);
    _stockController.text = item.currentStock.toString();
    _minStockController.text = item.minimumStock.toString();
    _editingItem = item;
    setState(() => _showForm = true);
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);

        final item = StoreItem(
          id: _editingItem?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          description: _descriptionController.text,
          sellingPrice: double.parse(_priceController.text),
          currentStock: int.parse(_stockController.text),
          minimumStock: int.parse(_minStockController.text),
          createdAt: _editingItem?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (_editingItem != null) {
          await firebaseService.updateStoreItem(item);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Item updated successfully!'),
                backgroundColor: Colors.green),
          );
        } else {
          await firebaseService.addStoreItem(item);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Item added successfully!'),
                backgroundColor: Colors.green),
          );
        }

        _clearForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving item: $e'),
              backgroundColor: Colors.red),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final shouldDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);
        await firebaseService.deleteStoreItem(itemId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Item deleted successfully!'),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting item: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildItemForm() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editingItem != null ? 'Edit Item' : 'Add New Item',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Item Name *'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter item name' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                          labelText: 'Selling Price *', prefixText: 'ETB '),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter price';
                        if (double.tryParse(value) == null) {
                          return 'Please enter valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: InputDecoration(labelText: 'Current Stock *'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter stock';
                        if (int.tryParse(value) == null) {
                          return 'Please enter valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _minStockController,
                decoration: InputDecoration(labelText: 'Minimum Stock *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter minimum stock';
                  if (int.tryParse(value) == null) {
                    return 'Please enter valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveItem,
                      child: Text(
                          _editingItem != null ? 'Update Item' : 'Add Item'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearForm,
                      child: Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Store Items'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (!_showForm)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => setState(() => _showForm = true),
              tooltip: 'Add New Item',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_showForm) _buildItemForm(),
            if (_showForm) SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<StoreItem>>(
                stream: Provider.of<FirebaseService>(context).getStoreItems(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No store items found'),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() => _showForm = true),
                            child: Text('Add First Item'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isLowStock = item.currentStock <= item.minimumStock;

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        color: isLowStock ? Colors.orange[50] : null,
                        child: ListTile(
                          leading: Icon(Icons.inventory_2,
                              color: isLowStock ? Colors.orange : Colors.blue),
                          title: Text(item.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.description),
                              SizedBox(height: 4),
                              Text(
                                  'Stock: ${item.currentStock} (Min: ${item.minimumStock})'),
                              Text(
                                  'Price: ETB ${item.sellingPrice.toStringAsFixed(0)}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editItem(item),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteItem(item.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
