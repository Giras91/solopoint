import 'package:flutter/material.dart';
import 'category_list_tab.dart';
import 'product_list_tab.dart';
import 'add_edit_category_dialog.dart';
import 'add_edit_product_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'Categories'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProductListTab(),
            CategoryListTab(),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              onPressed: () {
                final tabIndex = DefaultTabController.of(context).index;
                if (tabIndex == 0) {
                  // Add Product
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AddEditProductScreen(),
                    ),
                  );
                } else {
                  // Add Category
                  showDialog(
                    context: context,
                    builder: (context) => const AddEditCategoryDialog(),
                  );
                }
              },
              child: const Icon(Icons.add),
            );
          },
        ),
      ),
    );
  }
}
