import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ models/transaction.dart';
import '../ models/category.dart';
import '../services/storage_service.dart';
import '../services/category_service.dart';
import '../widgets/charts/pie_chart_widget.dart';
import '../widgets/charts/bar_chart_widget.dart';
import '../widgets/transaction_popup.dart';
import '../utils/helpers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  final StorageService _storageService = StorageService.instance;
  final CategoryService _categoryService = CategoryService();

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  // Data variables
  List<Transaction> _transactions = [];
  List<Transaction> _uncategorizedTransactions = [];
  List<Category> _categories = [];
  Map<String, double> _categoryTotals = {};
  Map<String, int> _categoryTransactionCounts = {};
  double _totalSpent = 0;
  double _totalReceived = 0;
  bool _isLoading = true;
  String _selectedPeriod = 'This Month';
  DateTime? _appFirstUsedDate;

  // Filter states
  String _trendFilter = 'Weekly';
  String _categoryFilter = 'All';
  String _categorizationFilter = 'All';

  // Performance optimization
  DateTime? _lastDataUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 3);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAppFirstUsedDate();
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeAppFirstUsedDate() async {
    try {
      final savedDate = _storageService.getSetting<String>('app_first_use_date', '');

      if (savedDate.isNotEmpty) {
        _appFirstUsedDate = DateTime.parse(savedDate);
        print('📅 App first used date loaded: $_appFirstUsedDate');
      }
    } catch (e) {
      print('❌ Error loading app first used date: $e');
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Check cache validity
    if (!forceRefresh &&
        _lastDataUpdate != null &&
        DateTime.now().difference(_lastDataUpdate!) < _cacheValidDuration &&
        _transactions.isNotEmpty) {
      print('⚡ Using cached dashboard data');
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Load data in parallel
      final futures = await Future.wait([
        _storageService.getTransactions(),
        _storageService.getCategories(),
      ]);

      final allTransactions = futures[0] as List<Transaction>;
      final categories = futures[1] as List<Category>;

      // Filter transactions from app first used date
      final filteredTransactions = _filterTransactionsFromAppStart(allTransactions);

      // Filter by selected period
      final periodFilteredTransactions = _filterTransactionsByPeriod(filteredTransactions);

      // Calculate metrics
      final metrics = _calculateMetricsEfficiently(periodFilteredTransactions);

      if (!mounted) return;

      setState(() {
        _transactions = periodFilteredTransactions;
        _categories = categories;
        _categoryTotals = metrics['categoryTotals'] as Map<String, double>;
        _categoryTransactionCounts = metrics['categoryCounts'] as Map<String, int>;
        _totalSpent = metrics['totalSpent'] as double;
        _totalReceived = metrics['totalReceived'] as double;
        _uncategorizedTransactions = _transactions.where((t) => !t.isCategorized).toList();
        _isLoading = false;
        _lastDataUpdate = DateTime.now();
      });

      // Start animations
      _startContentAnimations();

      print('✅ Dashboard data loaded: ${_transactions.length} transactions');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      print('❌ Error loading dashboard data: $e');
    }
  }

  void _startContentAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _scaleController.forward();
    });
    _pulseController.repeat(reverse: true);
  }

  List<Transaction> _filterTransactionsFromAppStart(List<Transaction> allTransactions) {
    if (_appFirstUsedDate == null) return allTransactions;

    return allTransactions.where((transaction) =>
    transaction.dateTime.isAfter(_appFirstUsedDate!) ||
        transaction.dateTime.isAtSameMomentAs(_appFirstUsedDate!)
    ).toList();
  }

  Map<String, dynamic> _calculateMetricsEfficiently(List<Transaction> transactions) {
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};
    double totalSpent = 0;
    double totalReceived = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.debit) {
        totalSpent += transaction.amount;
        categoryTotals[transaction.category] =
            (categoryTotals[transaction.category] ?? 0) + transaction.amount;
        categoryCounts[transaction.category] =
            (categoryCounts[transaction.category] ?? 0) + 1;
      } else {
        totalReceived += transaction.amount;
      }
    }

    return {
      'categoryTotals': categoryTotals,
      'categoryCounts': categoryCounts,
      'totalSpent': totalSpent,
      'totalReceived': totalReceived,
    };
  }

  List<Transaction> _filterTransactionsByPeriod(List<Transaction> allTransactions) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
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
        startDate = DateTime(now.year, now.month, 1);
    }

    return allTransactions.where((t) =>
    t.dateTime.isAfter(startDate) &&
        t.dateTime.isBefore(now.add(const Duration(days: 1)))
    ).toList();
  }

  void _changePeriod() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                    'Select Time Period',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ...['Today', 'This Week', 'This Month', 'Last 3 Months', 'This Year']
                      .map((period) => _buildPeriodOption(period))
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

  Widget _buildPeriodOption(String period) {
    final isSelected = _selectedPeriod == period;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedPeriod = period);
            Navigator.pop(context);

            // Reset animations and reload
            _fadeController.reset();
            _slideController.reset();
            _scaleController.reset();
            _loadData(forceRefresh: true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF667EEA).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF667EEA).withOpacity(0.3)
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
                        ? const Color(0xFF667EEA).withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPeriodIcon(period),
                    color: isSelected
                        ? const Color(0xFF667EEA)
                        : Colors.white.withOpacity(0.6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF667EEA)
                          : Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF667EEA),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPeriodIcon(String period) {
    switch (period) {
      case 'Today': return Icons.today;
      case 'This Week': return Icons.view_week;
      case 'This Month': return Icons.calendar_month;
      case 'Last 3 Months': return Icons.calendar_view_month;
      case 'This Year': return Icons.calendar_today;
      default: return Icons.date_range;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _isLoading
          ? _buildLoadingWidget()
          : SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: const Color(0xFF667EEA),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Modern App Bar
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                snap: false,
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
                        padding: EdgeInsets.symmetric(
                          horizontal: Helpers.getResponsivePadding(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_appFirstUsedDate != null)
                              Text(
                                'Since ${Helpers.formatDate(_appFirstUsedDate!)}',
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
                  // Period Selector
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _changePeriod,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.date_range,
                                size: 16,
                                color: const Color(0xFF667EEA).withOpacity(0.9),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedPeriod,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF667EEA).withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Refresh Button
                  IconButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _loadData(forceRefresh: true);
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Grid Overview (instead of carousel)
                        _buildGridOverview(),

                        const SizedBox(height: 24),

                        // Uncategorized Alert
                        if (_uncategorizedTransactions.isNotEmpty)
                          _buildUncategorizedAlert(),

                        const SizedBox(height: 24),

                        // Spending Analysis with Filters
                        _buildSpendingAnalysis(),

                        const SizedBox(height: 24),

                        // Enhanced Category Breakdown
                        _buildEnhancedCategoryBreakdown(),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
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
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your financial insights...',
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

  // REPLACE CAROUSEL WITH GRID
  Widget _buildGridOverview() {
    final balance = _totalReceived - _totalSpent;
    final avgDailySpending = _calculateAverageDailySpending();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Helpers.getResponsivePadding(context),
          ),
          child: Text(
            'Financial Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Helpers.getResponsivePadding(context),
          ),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildSummaryCard(
                  'Total Spent',
                  _totalSpent,
                  Icons.trending_up,
                  const Color(0xFFFF4757),
                  '${_transactions.where((t) => t.type == TransactionType.debit).length} transactions',
                ),
                _buildSummaryCard(
                  'Total Received',
                  _totalReceived,
                  Icons.trending_down,
                  const Color(0xFF2ED573),
                  '${_transactions.where((t) => t.type == TransactionType.credit).length} transactions',
                ),
                _buildSummaryCard(
                  'Net Balance',
                  balance,
                  Icons.account_balance_wallet,
                  balance >= 0 ? const Color(0xFF667EEA) : const Color(0xFFFF4757),
                  balance >= 0 ? 'Surplus' : 'Deficit',
                ),
                _buildSummaryCard(
                  'Daily Average',
                  avgDailySpending,
                  Icons.calendar_today,
                  const Color(0xFF7A82FF),
                  'Spending per day',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String label,
      double amount,
      IconData icon,
      Color color,
      String subtitle,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.abs().toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUncategorizedAlert() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Helpers.getResponsivePadding(context),
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF4757).withOpacity(0.15),
            const Color(0xFFFF4757).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF4757).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4757).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Color(0xFFFF4757),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Required',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_uncategorizedTransactions.length} transactions need categorization',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFFFF4757),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showBulkCategorization(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Text(
                  'Categorize',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingAnalysis() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Helpers.getResponsivePadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spending Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              // Filter Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['Split', 'Trend'].map((filter) {
                    final isSelected = _trendFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _trendFilter = filter);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF667EEA)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _trendFilter == 'Split'
                ? _buildPieChartSection()
                : _buildTrendChartSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    if (_categoryTotals.isEmpty) {
      return _buildEmptyAnalysis();
    }

    return Container(
      key: const ValueKey('pie_chart'),
      height: 300,
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
        child: Row(
          children: [
            // Pie Chart
            Expanded(
              flex: 3,
              child: PieChartWidget(
                categoryTotals: _categoryTotals,
                categories: _categories,
              ),
            ),

            const SizedBox(width: 20),

            // Legend
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: _categoryTotals.entries.take(5).map((entry) {
                        final category = _categories.firstWhere(
                              (c) => c.id == entry.key,
                          orElse: () => Category(
                            id: entry.key,
                            name: entry.key,
                            icon: Icons.category,
                            color: Colors.grey,
                          ),
                        );
                        final percentage = _totalSpent > 0
                            ? (entry.value / _totalSpent * 100)
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: category.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: category.color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChartSection() {
    return Container(
      key: const ValueKey('trend_chart'),
      height: 300,
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
            Text(
              'Spending Trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BarChartWidget(
                weeklyData: _calculateTrendData(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAnalysis() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No spending data',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start making transactions to see analysis',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedCategoryBreakdown() {
    final sortedCategories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Helpers.getResponsivePadding(context),
      ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Category Breakdown',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (_uncategorizedTransactions.isNotEmpty)
                  Material(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _showBulkCategorization,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.category,
                              color: Color(0xFF667EEA),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Categorize All',
                              style: TextStyle(
                                color: const Color(0xFF667EEA),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (sortedCategories.isEmpty)
            _buildEmptyCategoryBreakdown()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: sortedCategories.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.white.withOpacity(0.05),
                indent: 20,
                endIndent: 20,
              ),
              itemBuilder: (context, index) {
                final entry = sortedCategories[index];
                final category = _categories.firstWhere(
                      (c) => c.id == entry.key,
                  orElse: () => Category(
                    id: entry.key,
                    name: entry.key,
                    icon: Icons.category,
                    color: Colors.grey,
                  ),
                );

                final percentage = _totalSpent > 0
                    ? (entry.value / _totalSpent * 100).clamp(0, 100)
                    : 0.0;
                final transactionCount = _categoryTransactionCounts[entry.key] ?? 0;

                return _buildEnhancedCategoryItem(
                  category,
                  entry.value.toDouble(),
                  percentage.toDouble(), // FIX: Convert to double
                  transactionCount,
                  index,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCategoryItem(
      Category category,
      double amount,
      double percentage,
      int count,
      int index,
      ) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + (index * 50)),
      curve: Curves.easeOutBack,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Category Icon with Gradient Background
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    category.color.withOpacity(0.8),
                    category.color.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: category.color.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
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

            // Category Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: category.color,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt,
                            size: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$count transaction${count != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Animated Progress Bar
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 500 + (index * 100)),
                        curve: Curves.easeOutCubic,
                        height: 8,
                        width: MediaQuery.of(context).size.width * 0.6 * (percentage / 100),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              category.color,
                              category.color.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: category.color.withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategoryBreakdown() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
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
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start categorizing your transactions',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkCategorization() {
    if (_uncategorizedTransactions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
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

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Categorize Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      '${_uncategorizedTransactions.length} items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Transaction List
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _uncategorizedTransactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final transaction = _uncategorizedTransactions[index];
                    return _buildUncategorizedTransactionItem(transaction);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUncategorizedTransactionItem(Transaction transaction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: transaction.type == TransactionType.debit
                    ? [const Color(0xFFFF4757), const Color(0xFFFF4757).withOpacity(0.7)]
                    : [const Color(0xFF2ED573), const Color(0xFF2ED573).withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              transaction.type == TransactionType.debit
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              color: Colors.white,
              size: 16,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchant,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${transaction.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: transaction.type == TransactionType.debit
                            ? const Color(0xFFFF4757)
                            : const Color(0xFF2ED573),
                      ),
                    ),
                    Text(
                      ' • ${Helpers.formatDate(transaction.dateTime)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Material(
            color: const Color(0xFF667EEA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _categorizeTransaction(transaction),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Categorize',
                  style: TextStyle(
                    color: const Color(0xFF667EEA),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _categorizeTransaction(Transaction transaction) {
    Navigator.pop(context); // Close bulk categorization sheet

    showDialog(
      context: context,
      builder: (context) => TransactionPopup(
        transaction: transaction,
        onCategorized: (categorizedTransaction) async {
          await _storageService.saveTransaction(categorizedTransaction);

          // Learn from categorization
          await _categoryService.learnFromUserChoice(
            categorizedTransaction.merchant,
            categorizedTransaction.category,
          );

          // Refresh data
          _loadData(forceRefresh: true);
        },
      ),
    );
  }

  // Helper methods
  double _calculateAverageDailySpending() {
    if (_transactions.isEmpty || _appFirstUsedDate == null) return 0.0;

    final debitTransactions = _transactions.where((t) => t.type == TransactionType.debit).toList();
    if (debitTransactions.isEmpty) return 0.0;

    final daysSinceFirstUse = DateTime.now().difference(_appFirstUsedDate!).inDays + 1;
    return daysSinceFirstUse > 0 ? _totalSpent / daysSinceFirstUse : 0.0;
  }

  Map<String, double> _calculateTrendData() {
    final trendData = <String, double>{};
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = '${date.day}/${date.month}';
      trendData[dayKey] = 0;

      for (final transaction in _transactions) {
        if (transaction.type == TransactionType.debit &&
            transaction.dateTime.day == date.day &&
            transaction.dateTime.month == date.month &&
            transaction.dateTime.year == date.year) {
          trendData[dayKey] = (trendData[dayKey] ?? 0) + transaction.amount;
        }
      }
    }

    return trendData;
  }
}
