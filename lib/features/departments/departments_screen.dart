import 'package:flutter/material.dart';

import '../../widgets/app_snack_bar.dart';

class DepartmentsScreen extends StatelessWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Departments')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Departments',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Department DB tables and APIs are not ready yet. This page is reserved for department listing, search, add, and edit workflows.',
                        style: TextStyle(color: Colors.black),
                      ),
                      const SizedBox(height: 24),
                      _DepartmentPlaceholderItem(
                        name: 'Dispatch',
                        onEdit: () => _showPlaceholder(context),
                      ),
                      _DepartmentPlaceholderItem(
                        name: 'Warehouse',
                        onEdit: () => _showPlaceholder(context),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showPlaceholder(context),
                        icon: const Icon(Icons.add_business),
                        label: const Text('Add Department'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context) {
    showAppSnackBar(
      context,
      message: 'Department APIs and DB tables are not ready yet.',
      type: AppSnackBarType.warning,
    );
  }
}

class _DepartmentPlaceholderItem extends StatelessWidget {
  const _DepartmentPlaceholderItem({required this.name, required this.onEdit});

  final String name;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name, style: const TextStyle(color: Colors.black)),
      subtitle: const Text(
        'Placeholder',
        style: TextStyle(color: Colors.black),
      ),
      trailing: IconButton(
        tooltip: 'Edit department',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}
