import 'package:flutter/material.dart';
import '../ models/transaction.dart';
import '../ models/category.dart';

import '../services/storage_service.dart';
import '../services/category_service.dart';

class TransactionPopup extends StatefulWidget {
  final Transaction transaction;
  final Function(Transaction) onCategorized;

  const TransactionPopup({
    super.key,
    required this.transaction,
    required this.onCategorized,
  });

  @override
  State<TransactionPopup> createState() => _TransactionPopupState();
}

class _TransactionPopupState extends State<TransactionPopup> {
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _noteController = TextEditingController();

  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _noteController.text = widget.transaction.note ?? '';
  }

  Future<void> _loadCategories() async {
    final categories = await StorageService.instance.getCategories();
    final suggestedCategory = await _categoryService.suggestCategory(widget.transaction);

    setState(() {
      _categories = categories;
      _selectedCategory = suggestedCategory;
      _isLoading = false;
    });
  }

  void _saveTransaction() async {
    if (_selectedCategory == null) return;

    final updatedTransaction = widget.transaction.copyWith(
      category: _selectedCategory!.id,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      isCategorized: true,
    );

    // Learn from user's choice
    await _categoryService.learnFromUserChoice(
      widget.transaction.merchant,
      _selectedCategory!.id,
    );

    widget.onCategorized(updatedTransaction);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _snoozeTransaction() {
    Navigator.of(context).pop();
    // TODO: Implement snooze functionality
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.transaction.type == TransactionType.debit
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.transaction.type == TransactionType.debit
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: widget.transaction.type == TransactionType.debit
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categorize Transaction',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${widget.transaction.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: widget.transaction.type == TransactionType.debit
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Transaction Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.transaction.merchant != 'Unknown') ...[
                    Row(
                      children: [
                        const Icon(Icons.store, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Merchant: ${widget.transaction.merchant}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.message, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.transaction.originalMessage,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Category Selection
            Text(
              'Select Category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory?.id == category.id;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = category),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? category.color.withOpacity(0.2)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? category.color
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              category.icon,
                              color: isSelected
                                  ? category.color
                                  : Colors.grey.shade600,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? category.color
                                    : Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Note Field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Add Note (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _snoozeTransaction,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Snooze'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedCategory != null ? _saveTransaction : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}
