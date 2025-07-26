// lib/screens/category_transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ models/category.dart';
import '../ models/transaction.dart';
import '../services/storage_service.dart';
import '../widgets/transaction_card.dart';
import '../utils/helpers.dart';

class CategoryTransactionsScreen extends StatefulWidget {
  final Category category;

  const CategoryTransactionsScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryTransactionsScreen> createState() => _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState extends State<CategoryTransactionsScreen>
    with TickerProviderStateMixin {
  final StorageService _storageService = StorageService.instance;
  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  String _selectedPeriod = 'All Time';
  String _selectedType = 'All'; // All, Credit, Debit

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTransactions();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final allTransactions = await _storageService.getTransactions();

      // Filter transactions by category
      final categoryTransactions = allTransactions
          .where((t) => t.category == widget.category.id)
          .toList();

      // Sort by date (newest first)
      categoryTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (mounted) {
        setState(() {
          _allTransactions = categoryTransactions;
          _filteredTransactions = _applyFilters(categoryTransactions);
          _isLoading = false;
        });
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      print('Error loading transactions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Transaction> _applyFilters(List<Transaction> transactions) {
    var filtered = List<Transaction>.from(transactions);

    // Apply period filter
    if (_selectedPeriod != 'All Time') {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Last 3 Months':
          startDate = DateTime(now.year, now.month - 2, 1);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(1970);
      }

      filtered = filtered.where((t) => t.dateTime.isAfter(startDate)).toList();
    }

    // Apply type filter
    if (_selectedType == 'Credit') {
      filtered = filtered.where((t) => t.type == TransactionType.credit).toList();
    } else if (_selectedType == 'Debit') {
      filtered = filtered.where((t) => t.type == TransactionType.debit).toList();
    }

    return filtered;
  }

  void _updateFilters() {
    setState(() {
      _filteredTransactions = _applyFilters(_allTransactions);
    });
  }

  void _showFilterOptions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Transactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Period Filter
                  Text(
                    'Time Period',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...['All Time', 'This Week', 'This Month', 'Last 3 Months', 'This Year']
                      .map((period) => _buildFilterOption(
                    period,
                    _selectedPeriod == period,
                    Icons.date_range,
                        () {
                      setState(() => _selectedPeriod = period);
                      _updateFilters();
                    },
                  ))
                      .toList(),

                  const SizedBox(height: 24),

                  // Type Filter
                  Text(
                    'Transaction Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...['All', 'Credit', 'Debit']
                      .map((type) => _buildFilterOption(
                    type,
                    _selectedType == type,
                    type == 'Credit' ? Icons.trending_up :
                    type == 'Debit' ? Icons.trending_down : Icons.swap_horiz,
                        () {
                      setState(() => _selectedType = type);
                      _updateFilters();
                    },
                  ))
                      .toList(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, bool isSelected, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? widget.category.color.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? widget.category.color.withOpacity(0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.category.color.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? widget.category.color
                        : Colors.white.withOpacity(0.6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? widget.category.color
                          : Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: widget.category.color,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _filteredTransactions
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final creditAmount = _filteredTransactions
        .where((t) => t.type == TransactionType.credit)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final debitAmount = _filteredTransactions
        .where((t) => t.type == TransactionType.debit)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTransactions,
          color: widget.category.color,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 280,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF0A0E1A),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.category.color.withOpacity(0.8),
                          widget.category.color.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Category Icon
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                widget.category.icon,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Category Name
                            Text(
                              widget.category.name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Stats Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard('Total', '₹${totalAmount.toStringAsFixed(2)}'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard('In', '₹${creditAmount.toStringAsFixed(2)}'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard('Out', '₹${debitAmount.toStringAsFixed(2)}'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Transaction Count
                            Text(
                              '${_filteredTransactions.length} transactions • ${_selectedPeriod}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showFilterOptions,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.tune,
                            color: Colors.white,
                            size: 20,
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
                    : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildTransactionsList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
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
              gradient: LinearGradient(
                colors: [
                  widget.category.color,
                  widget.category.color.withOpacity(0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.category.color.withOpacity(0.3),
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
            'Loading transactions...',
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

  Widget _buildTransactionsList() {
    if (_filteredTransactions.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Summary
          if (_selectedPeriod != 'All Time' || _selectedType != 'All')
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.category.color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    color: widget.category.color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtered: $_selectedPeriod${_selectedType != 'All' ? ' • $_selectedType' : ''}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          _selectedPeriod = 'All Time';
                          _selectedType = 'All';
                        });
                        _updateFilters();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: widget.category.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Transactions Header
          Text(
            'Transactions (${_filteredTransactions.length})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),

          // Transaction List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredTransactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final transaction = _filteredTransactions[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset((1 - value) * 50, 0),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: TransactionCard(
                  transaction: transaction,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // You can navigate to transaction details here if needed
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.category.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.category.icon,
              size: 48,
              color: widget.category.color.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedPeriod == 'All Time' && _selectedType == 'All'
                ? 'No transactions yet'
                : 'No matching transactions',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedPeriod == 'All Time' && _selectedType == 'All'
                ? 'Transactions in this category will appear here'
                : 'Try adjusting your filters to see more results',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedPeriod != 'All Time' || _selectedType != 'All') ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedPeriod = 'All Time';
                  _selectedType = 'All';
                });
                _updateFilters();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.category.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
