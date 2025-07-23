import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../ models/transaction.dart';
import '../ models/category.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  final StorageService _storageService = StorageService.instance;

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  DateTimeRange? _selectedDateRange;
  String? _selectedCategory;
  bool _isLoading = true;
  bool _isExporting = false;

  // Animation Controllers with proper disposal checks
  AnimationController? _fadeController;
  AnimationController? _slideController;
  AnimationController? _scaleController;
  AnimationController? _exportController;

  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _scaleAnimation;
  Animation<double>? _exportAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // Default to current month
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    _loadData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _exportController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Safe animation initialization with null checks
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController!,
      curve: Curves.bounceOut,
    );

    _exportAnimation = CurvedAnimation(
      parent: _exportController!,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _scaleController?.dispose();
    _exportController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    // Add slight delay for smooth animation
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final transactions = await _storageService.getTransactions();
    final categories = await _storageService.getCategories();

    if (!mounted) return;

    setState(() {
      _transactions = _filterTransactions(transactions);
      _categories = categories;
      _isLoading = false;
    });

    // Start animations safely
    _fadeController?.forward();
    _slideController?.forward();
    _scaleController?.forward();
  }

  List<Transaction> _filterTransactions(List<Transaction> allTransactions) {
    var filtered = allTransactions.where((t) {
      if (_selectedDateRange != null) {
        return t.dateTime.isAfter(_selectedDateRange!.start) &&
            t.dateTime.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }
      return true;
    }).toList();

    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered.where((t) => t.category == _selectedCategory).toList();
    }

    return filtered..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  void _selectDateRange() async {
    HapticFeedback.mediumImpact();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4ECDC4),
              surface: Color(0xFF1A1F2E),
              background: Color(0xFF0A0E1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDateRange = picked;
      });

      // Reset animations safely
      _fadeController?.reset();
      _slideController?.reset();
      _scaleController?.reset();

      await _loadData();
    }
  }

  void _exportData() async {
    if (_isExporting || !mounted) return;

    setState(() => _isExporting = true);
    _exportController?.forward();

    HapticFeedback.mediumImpact();

    try {
      final csvData = _generateCSV();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/transactions_report.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: 'Transaction Report');

      if (mounted) {
        _showSuccessSnackBar('Report exported successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error exporting data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
        _exportController?.reverse();
      }
    }
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

  String _generateCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Date,Amount,Type,Category,Merchant,Note');

    for (final transaction in _transactions) {
      final category = _categories.firstWhere(
            (c) => c.id == transaction.category,
        orElse: () => Category(
          id: 'unknown',
          name: 'Unknown',
          icon: Icons.category,
          color: Colors.grey,
        ),
      );

      buffer.writeln(
          '${Helpers.formatDate(transaction.dateTime)},'
              '${transaction.amount},'
              '${transaction.type.name},'
              '${category.name},'
              '${transaction.merchant},'
              '${transaction.note ?? ""}'
      );
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
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
                          'Reports',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Analyze your financial data',
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
                child: _exportAnimation != null
                    ? AnimatedBuilder(
                  animation: _exportAnimation!,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _exportAnimation!.value * 6.28,
                      child: Material(
                        color: const Color(0xFF4ECDC4),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isExporting ? null : _exportData,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              _isExporting ? Icons.hourglass_empty : Icons.share,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
                    : Material(
                  color: const Color(0xFF4ECDC4),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _exportData,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.share,
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
                : _fadeAnimation != null && _slideAnimation != null
                ? FadeTransition(
              opacity: _fadeAnimation!,
              child: SlideTransition(
                position: _slideAnimation!,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildModernFilters(),
                      const SizedBox(height: 24),
                      _scaleAnimation != null
                          ? ScaleTransition(
                        scale: _scaleAnimation!,
                        child: _buildModernSummary(),
                      )
                          : _buildModernSummary(),
                      const SizedBox(height: 24),
                      _buildModernTransactionList(),
                    ],
                  ),
                ),
              ),
            )
                : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildModernFilters(),
                  const SizedBox(height: 24),
                  _buildModernSummary(),
                  const SizedBox(height: 24),
                  _buildModernTransactionList(),
                ],
              ),
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
            'Generating your reports...',
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

  Widget _buildModernFilters() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Color(0xFF4ECDC4),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Date Range Selector
            Material(
              color: const Color(0xFF2A2F3E),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _selectDateRange,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Color(0xFF4ECDC4)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDateRange != null
                              ? '${Helpers.formatDate(_selectedDateRange!.start)} - ${Helpers.formatDate(_selectedDateRange!.end)}'
                              : 'Select Date Range',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Category Dropdown
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2F3E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: const Color(0xFF2A2F3E),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.category, color: Color(0xFF4ECDC4)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                style: const TextStyle(color: Colors.white),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ..._categories.map((category) => DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(category.icon, color: category.color, size: 20),
                        const SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  )),
                ],
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedCategory = value;
                  });

                  // Reset animations safely
                  _fadeController?.reset();
                  _slideController?.reset();
                  _scaleController?.reset();

                  _loadData();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSummary() {
    final debitTotal = _transactions
        .where((t) => t.type == TransactionType.debit)
        .fold(0.0, (sum, t) => sum + t.amount);

    final creditTotal = _transactions
        .where((t) => t.type == TransactionType.credit)
        .fold(0.0, (sum, t) => sum + t.amount);

    final netAmount = creditTotal - debitTotal;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Color(0xFF667EEA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildModernSummaryCard(
                    'Total Spent',
                    debitTotal,
                    const Color(0xFFFF4757),
                    Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernSummaryCard(
                    'Total Received',
                    creditTotal,
                    const Color(0xFF2ED573),
                    Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernSummaryCard(
                    'Net Amount',
                    netAmount,
                    netAmount >= 0 ? const Color(0xFF2ED573) : const Color(0xFFFF4757),
                    Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSummaryCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2F3E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTransactionList() {
    if (_transactions.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF764BA2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Color(0xFF764BA2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Transactions (${_transactions.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: _transactions.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.05),
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              return _buildModernTransactionItem(_transactions[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernTransactionItem(Transaction transaction) {
    final category = _categories.firstWhere(
          (c) => c.id == transaction.category,
      orElse: () => Category(
        id: 'unknown',
        name: 'Unknown',
        icon: Icons.category,
        color: Colors.grey,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Category Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [category.color, category.color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
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
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      transaction.merchant,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      '${transaction.type == TransactionType.debit ? '-' : '+'}₹${transaction.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: transaction.type == TransactionType.debit
                            ? const Color(0xFFFF4757)
                            : const Color(0xFF2ED573),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: category.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      Helpers.formatDate(transaction.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaction.note!,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
              Icons.search_off,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters to see more results',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
