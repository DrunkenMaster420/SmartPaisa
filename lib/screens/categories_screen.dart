// lib/screens/categories_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ models/category.dart';
import '../ models/transaction.dart';
import '../services/storage_service.dart';
import '../services/category_service.dart';
import '../screens/category_transactions_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with TickerProviderStateMixin {
  final StorageService _storageService = StorageService.instance;
  final CategoryService _categoryService = CategoryService();
  List<Category> _categories = [];
  Map<String, int> _categoryTransactionCounts = {};
  bool _isLoading = true;

  // Animation Controllers with explicit null safety
  AnimationController? _fadeController;
  AnimationController? _scaleController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadCategories();
  }

  void _initializeAnimations() {
    try {
      _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );

      _scaleController = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );

      if (_fadeController != null) {
        _fadeAnimation = CurvedAnimation(
          parent: _fadeController!,
          curve: Curves.easeInOut,
        );
      }

      if (_scaleController != null) {
        _scaleAnimation = Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _scaleController!,
          curve: Curves.elasticOut,
        ));
      }
    } catch (e) {
      print('Error initializing animations: $e');
    }
  }

  @override
  void dispose() {
    try {
      _fadeController?.dispose();
      _scaleController?.dispose();
    } catch (e) {
      print('Error disposing animations: $e');
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    // Small delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;

    try {
      final categories = await _storageService.getCategories();
      final transactions = await _storageService.getTransactions();

      // Count transactions per category
      final counts = <String, int>{};
      for (final transaction in transactions) {
        if (transaction.isCategorized) {
          counts[transaction.category] = (counts[transaction.category] ?? 0) + 1;
        }
      }

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _categoryTransactionCounts = counts;
        _isLoading = false;
      });

      // Start animations safely
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        _fadeController?.forward();
        _scaleController?.forward();
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCategoryDialog([Category? category]) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddCategoryDialog(
        category: category,
        onSaved: (newCategory) async {
          try {
            await _storageService.saveCategory(newCategory);

            // Reset animations safely
            if (mounted) {
              _fadeController?.reset();
              _scaleController?.reset();
              await _loadCategories();
            }

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    category == null
                        ? 'Category "${newCategory.name}" created successfully!'
                        : 'Category "${newCategory.name}" updated successfully!',
                  ),
                  backgroundColor: const Color(0xFF4ECDC4),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          } catch (e) {
            print('Error saving category: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving category: $e'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteCategory(Category category) async {
    if (category.isDefault) {
      _showErrorSnackBar('Cannot delete default categories');
      return;
    }

    final confirmed = await _showDeleteConfirmation(category);
    if (confirmed == true) {
      try {
        HapticFeedback.heavyImpact();

        // Delete the category from storage
        await _storageService.deleteCategory(category.id);

        // Clear any learned associations for this category
        await _categoryService.clearCategoryLearning(category.id);

        if (mounted) {
          _fadeController?.reset();
          _scaleController?.reset();
          await _loadCategories();
          _showSuccessSnackBar('Category "${category.name}" deleted successfully');
        }
      } catch (e) {
        print('Error deleting category: $e');
        if (mounted) {
          _showErrorSnackBar('Error deleting category: $e');
        }
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(Category category) {
    final transactionCount = _categoryTransactionCounts[category.id] ?? 0;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFF1A1F2E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Category',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${category.name}"?',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            if (transactionCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$transactionCount transactions will be uncategorized',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF4ECDC4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Navigate to category transactions screen
  void _navigateToCategoryTransactions(Category category) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryTransactionsScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              backgroundColor: const Color(0xFF0A0E1A),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A1F2E),
                        Color(0xFF0A0E1A),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Organize your transactions',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Material(
                    color: const Color(0xFF4ECDC4),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showAddCategoryDialog(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: _isLoading
                  ? _buildLoadingWidget()
                  : _buildAnimatedContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedContent() {
    // Safe animation wrapper with fallback
    if (_fadeAnimation != null && _scaleAnimation != null) {
      return FadeTransition(
        opacity: _fadeAnimation!,
        child: ScaleTransition(
          scale: _scaleAnimation!,
          child: _buildContent(),
        ),
      );
    } else {
      // Fallback without animations if controllers failed to initialize
      return _buildContent();
    }
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(),
          const SizedBox(height: 24),
          _buildCategoriesList(),
          // Add extra padding at bottom to prevent keyboard overflow
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ECDC4).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading categories...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalTransactions = _categoryTransactionCounts.values
        .fold<int>(0, (sum, count) => sum + count);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667EEA),
            Color(0xFF764BA2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.category,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_categories.length} Categories',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_categories.where((c) => c.isDefault).length} default • ${_categories.where((c) => !c.isDefault).length} custom',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalTransactions categorized transactions',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    if (_categories.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 16),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final category = _categories[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + (index * 100)),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                // Clamp animation value to ensure it's within 0.0-1.0
                final clampedValue = value.clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset((1 - clampedValue) * 50, 0),
                  child: Opacity(
                    opacity: clampedValue,
                    child: child,
                  ),
                );
              },
              child: _buildCategoryCard(category),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Category category) {
    final transactionCount = _categoryTransactionCounts[category.id] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: category.color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: category.color.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToCategoryTransactions(category),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        category.color.withOpacity(0.8),
                        category.color.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: category.color.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    category.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            category.isDefault ? 'Default' : 'Custom',
                            style: TextStyle(
                              fontSize: 12,
                              color: category.isDefault
                                  ? const Color(0xFF4ECDC4)
                                  : Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (transactionCount > 0) ...[
                            Text(
                              ' • $transactionCount transactions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                if (!category.isDefault)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    color: const Color(0xFF2A2F3E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              color: const Color(0xFF4ECDC4),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddCategoryDialog(category);
                      } else if (value == 'delete') {
                        _deleteCategory(category);
                      }
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF4ECDC4),
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.category_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No categories yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first category to organize transactions',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// Updated _AddCategoryDialog with keyboard handling fix
class _AddCategoryDialog extends StatefulWidget {
  final Category? category;
  final Function(Category) onSaved;

  const _AddCategoryDialog({
    this.category,
    required this.onSaved,
    super.key,
  });

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  IconData _selectedIcon = Icons.category;
  Color _selectedColor = const Color(0xFF4ECDC4);

  AnimationController? _dialogController;
  Animation<double>? _dialogAnimation;

  final List<IconData> _availableIcons = [
    Icons.restaurant, Icons.directions_car, Icons.shopping_bag, Icons.movie,
    Icons.flash_on, Icons.local_hospital, Icons.school, Icons.work,
    Icons.trending_up, Icons.home, Icons.fitness_center, Icons.pets,
    Icons.flight, Icons.music_note, Icons.book, Icons.coffee,
    Icons.sports_esports, Icons.beach_access, Icons.business_center,
    Icons.child_care, Icons.local_gas_station, Icons.phone,
  ];

  final List<Color> _availableColors = [
    const Color(0xFF4ECDC4), const Color(0xFF667EEA), const Color(0xFF764BA2),
    const Color(0xFFFF6B6B), const Color(0xFFFECA57), const Color(0xFF6C5CE7),
    const Color(0xFFA29BFE), const Color(0xFFFF7675), const Color(0xFF74B9FF),
    const Color(0xFF00B894), const Color(0xFFE17055), const Color(0xFFFDCB6E),
    const Color(0xFF55A3FF), const Color(0xFFFF6B9D), const Color(0xFF3742FA),
    const Color(0xFF2F3542), const Color(0xFF57606F), const Color(0xFFA4B0BE),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedIcon = widget.category!.icon;
      _selectedColor = widget.category!.color;
    }
  }

  void _initializeAnimations() {
    _dialogController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _dialogAnimation = CurvedAnimation(
      parent: _dialogController!,
      curve: Curves.elasticOut,
    );

    _dialogController?.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dialogController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: _dialogAnimation != null
            ? ScaleTransition(
          scale: _dialogAnimation!,
          child: _buildDialogContent(),
        )
            : _buildDialogContent(),
      ),
    );
  }

  Widget _buildDialogContent() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_selectedColor, _selectedColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _selectedIcon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.category == null ? 'Add Category' : 'Edit Category',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Name Field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'Category Name',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: const Color(0xFF2A2F3E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _selectedColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Icon Selection
            Text(
              'Select Icon',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  final isSelected = icon == _selectedIcon;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedIcon = icon);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: [_selectedColor, _selectedColor.withOpacity(0.7)],
                        )
                            : null,
                        color: isSelected ? null : const Color(0xFF2A2F3E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _selectedColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Color Selection
            Text(
              'Select Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                final isSelected = color == _selectedColor;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedColor = color);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.8)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nameController.text.trim().isEmpty ? null : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedColor,
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

  void _saveCategory() {
    if (_nameController.text.trim().isEmpty) return;

    HapticFeedback.heavyImpact();

    final category = Category(
      id: widget.category?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      icon: _selectedIcon,
      color: _selectedColor,
      isDefault: widget.category?.isDefault ?? false,
    );

    widget.onSaved(category);
    Navigator.of(context).pop();
  }
}
