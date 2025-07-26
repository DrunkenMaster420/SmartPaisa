import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sms_service.dart';
import '../services/storage_service.dart';
import '../ models/transaction.dart';
import '../widgets/transaction_popup.dart';
import 'dashboard_screen.dart';
import 'categories_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  /* ────────────────────── Services ────────────────────── */
  final _sms = SmsService();
  final _store = StorageService.instance;

  /* ────────────────────── Animation ───────────────────── */
  late final AnimationController _fadeCtl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final AnimationController _pulseCtl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))
    ..repeat(reverse: true);
  late final Animation<double> _fade = CurvedAnimation(parent: _fadeCtl, curve: Curves.easeOut);
  late final Animation<double> _pulse =
  Tween(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _pulseCtl, curve: Curves.easeInOut));

  /* ────────────────────── Data cache ───────────────────── */
  List<Transaction> _all = [];
  List<Transaction> _recent = [];
  double _spent = 0, _received = 0;
  int _selectedTab = 0;

  /* ────────────────────── Filters ──────────────────────── */
  String _mainFilter = 'All';
  String _cardFilter = 'All';
  final _mainOptions = ['All', 'UPI', 'Card'];
  final _cardOptions = ['All', 'Debit Card', 'Credit Card'];

  /* ────────────────────── Lifecycle ────────────────────── */
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  @override
  void dispose() {
    _fadeCtl.dispose();
    _pulseCtl.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    try {
      await _sms.initialize();
      await _loadData();

      _sms.watchNewTransactions().listen((t) {
        _all.insert(0, t);
        _applyFilters();
        if (mounted) setState(() {});
      });

    } catch (e) {
      print('❌ Error initializing app: $e');
    }
  }

  /* ────────────────────── Helpers ──────────────────────── */
  bool _isDebitCard(Transaction t) =>
      t.originalMessage.toLowerCase().contains('debit card') ||
          t.originalMessage.toLowerCase().contains(' dc ') ||
          t.originalMessage.toLowerCase().contains('debit ');

  bool _isCreditCard(Transaction t) =>
      t.originalMessage.toLowerCase().contains('credit card') ||
          t.originalMessage.toLowerCase().contains(' cc ') ||
          t.originalMessage.toLowerCase().contains('credit ');

  Color _filterColor(String f) => switch (f) {
    'UPI' => const Color(0xFF4ECDC4),
    'Card' => const Color(0xFF667EEA),
    _ => const Color(0xFF764BA2)
  };

  IconData _filterIcon(String f) => switch (f) {
    'UPI' => Icons.account_balance_wallet,
    'Card' => Icons.credit_card,
    _ => Icons.dashboard
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  /* ────────────────────── Data load & filter ───────────── */
  Future<void> _loadData() async {
    _all = await _sms.getHistoricalTransactions();
    _applyFilters();
    if (mounted) setState(() {});
  }

  void _applyFilters() {
    Iterable<Transaction> list = _all;

    switch (_mainFilter) {
      case 'UPI':
        list = list.where((t) =>
        t.originalMessage.toLowerCase().contains('upi') ||
            t.merchant.toLowerCase().contains('upi'));
        break;
      case 'Card':
        list = list.where((t) =>
        _isDebitCard(t) || _isCreditCard(t));
        if (_cardFilter == 'Debit Card') list = list.where(_isDebitCard);
        if (_cardFilter == 'Credit Card') list = list.where(_isCreditCard);
        break;
    }

    _recent = list.take(5).toList();

    _spent = 0;
    _received = 0;
    for (final t in list) {
      if (t.type == TransactionType.debit) {
        _spent += t.amount;
      } else {
        _received += t.amount;
      }
    }
  }

  /* ────────────────────── UI BUILD ─────────────────────── */
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _selectedTab == 0
          ? _homeBody()
          : _selectedTab == 1
          ? const DashboardScreen()
          : _selectedTab == 2
          ? const CategoriesScreen()
          : _selectedTab == 3
          ? const ReportsScreen()
          : const SettingsScreen(),
      bottomNavigationBar: _bottomNav(),
    );
  }

  /* --------------------- Home tab ---------------------- */
  Widget _homeBody() => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      _appBar(),
      SliverToBoxAdapter(
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _mainFilterBar(),
                if (_mainFilter == 'Card') const SizedBox(height: 12),
                if (_mainFilter == 'Card') _cardSubFilterBar(),
                const SizedBox(height: 24),
                _balanceCard(),
                const SizedBox(height: 24),
                _quickStats(),
                const SizedBox(height: 24),
                _recentActivity(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      )
    ],
  );

  SliverAppBar _appBar() => SliverAppBar(
    expandedHeight: 100,
    backgroundColor: Colors.transparent,
    elevation: 0,
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1F2E), Color(0xFF0A0E1A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SmartPaisa',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5)),
                      Text('Smart Finance Tracking',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /* --------------------- Filter bars ------------------- */
  Widget _mainFilterBar() => _glassBar(
    options: _mainOptions,
    selected: _mainFilter,
    onTap: (f) {
      setState(() {
        _mainFilter = f;
        if (f != 'Card') _cardFilter = 'All';
        _applyFilters();
      });
    },
  );

  Widget _cardSubFilterBar() => _glassBar(
    options: _cardOptions,
    selected: _cardFilter,
    height: 50,
    onTap: (f) {
      setState(() {
        _cardFilter = f;
        _applyFilters();
      });
    },
  );

  Widget _glassBar({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onTap,
    double height = 60,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.1)),
      ),
      child: Row(
        children: options.map((opt) {
          final sel = opt == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(opt);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: sel
                      ? LinearGradient(
                      colors: [_filterColor(opt), _filterColor(opt).withOpacity(.7)])
                      : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(opt,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? Colors.white : Colors.white.withOpacity(.6))),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /* --------------------- Cards & lists ------------------ */
  Widget _balanceCard() {
    final bal = _received - _spent;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) =>
          Transform.scale(scale: _pulse.value, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_filterColor(_mainFilter), _filterColor(_mainFilter).withOpacity(.8)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _filterColor(_mainFilter).withOpacity(.35),
              blurRadius: 28,
              offset: const Offset(0, 14),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_mainFilter == 'All' ? '' : _mainFilter} Balance',
                    style:
                    TextStyle(color: Colors.white.withOpacity(.9), fontSize: 16)),
                Icon(_filterIcon(_mainFilter), color: Colors.white),
              ],
            ),
            const SizedBox(height: 16),
            Text('₹${bal.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('From ${_recent.length} txns',
                style: TextStyle(color: Colors.white.withOpacity(.7))),
          ],
        ),
      ),
    );
  }

  Widget _quickStats() => Row(
    children: [
      Expanded(
          child: _statCard('Spent', _spent, Colors.red, Icons.arrow_upward)),
      const SizedBox(width: 16),
      Expanded(
          child: _statCard(
              'Received', _received, Colors.green, Icons.arrow_downward)),
    ],
  );

  Widget _statCard(String title, double amount, Color c, IconData ic) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1F2E),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration:
          BoxDecoration(color: c.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(ic, color: c, size: 16),
        ),
        Text(title, style: TextStyle(color: Colors.white.withOpacity(.6))),
      ]),
      const SizedBox(height: 12),
      Text('₹${amount.toStringAsFixed(0)}',
          style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _recentActivity() {
    if (_recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_filterIcon(_mainFilter), size: 40, color: Colors.white.withOpacity(.3)),
          const SizedBox(height: 16),
          Text('No transactions', style: TextStyle(color: Colors.white.withOpacity(.7))),
          const SizedBox(height: 8),
          Text('Your transactions will appear here automatically',
              style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 12)),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Recent Activity',
              style: TextStyle(color: Colors.white.withOpacity(.9), fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recent.length,
          separatorBuilder: (_, __) =>
              Divider(indent: 20, endIndent: 20, color: Colors.white.withOpacity(.05)),
          itemBuilder: (_, i) => _txnTile(_recent[i]),
        ),
      ]),
    );
  }

  Widget _txnTile(Transaction t) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.type == TransactionType.debit
            ? Colors.red.withOpacity(.12)
            : Colors.green.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
          t.type == TransactionType.debit ? Icons.arrow_upward : Icons.arrow_downward,
          color: t.type == TransactionType.debit ? Colors.red : Colors.green,
          size: 16),
    ),
    title: Text(t.merchant,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white.withOpacity(.9))),
    subtitle: Text(_timeAgo(t.dateTime), style: TextStyle(color: Colors.white54)),
    trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(
        '${t.type == TransactionType.debit ? '-' : '+'}₹${t.amount.toStringAsFixed(0)}',
        style: TextStyle(
            color: t.type == TransactionType.debit ? Colors.red : Colors.green,
            fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Wrap(spacing: 4, children: [
        if (!t.isCategorized)
          _tag('Uncat', Colors.red),
        if (_isDebitCard(t))
          _tag('Debit', const Color(0xFF667EEA)),
        if (_isCreditCard(t))
          _tag('Credit', const Color(0xFF764BA2)),
      ]),
    ]),
    onTap: () {
      HapticFeedback.selectionClick();
      _showPopup(t);
    },
  );

  Widget _tag(String txt, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration:
    BoxDecoration(color: c.withOpacity(.15), borderRadius: BorderRadius.circular(4)),
    child: Text(txt, style: TextStyle(fontSize: 8, color: c, fontWeight: FontWeight.w500)),
  );

  void _showPopup(Transaction t) {
    showDialog(
        context: context,
        builder: (_) => TransactionPopup(
          transaction: t,
          onCategorized: (newT) async {
            await _store.saveTransaction(newT);
            await _loadData();
          },
        ));
  }

  /* --------------------- BottomNav ---------------------- */
  Widget _bottomNav() => Container(
    decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 20)]),
    child: BottomNavigationBar(
      currentIndex: _selectedTab,
      onTap: (i) => setState(() => _selectedTab = i),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: const Color(0xFF667EEA),
      unselectedItemColor: Colors.white54,
      selectedFontSize: 12,
      unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    ),
  );
}
