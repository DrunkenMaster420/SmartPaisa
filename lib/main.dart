import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smswatcher/smswatcher.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart'; // for SHA-1 deduplication

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPaisa Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey.shade100,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Segoe UI'),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Smswatcher _smsWatcher = Smswatcher();
  List<Map<String, dynamic>> _allSms = [];
  List<_Txn> _txns = [];
  double _totalDebit = 0, _totalCredit = 0;

  final Set<String> _seenHashes = {};

  @override
  void initState() {
    super.initState();
    _initSms();
  }

  Future<void> _initSms() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      openAppSettings();
      return;
    }
    final history = await _smsWatcher.getAllSMS() ?? [];
    _allSms = history.cast<Map<String, dynamic>>();
    _processTransactions();
    _smsWatcher.getStreamOfSMS().listen((sms) {
      _allSms.insert(0, sms);
      _processTransactions();
    });
  }

  void _processTransactions() {
    final List<_Txn> txns = [];
    double debit = 0, credit = 0;
    _seenHashes.clear();

    for (var sms in _allSms) {
      final body = (sms['body'] as String?)?.trim() ?? '';
      final addr = sms['address'] as String? ?? '';
      final date = sms['date'] as int? ?? 0;

      final lower = body.toLowerCase();

      if (lower.contains('emi') ||
          lower.contains('loan') ||
          lower.contains('requested') ||
          lower.contains('reward') ||
          lower.contains('offer') ||
          lower.contains('gift') ||
          lower.contains('coupon')) continue;

      final amtMatch = RegExp(r'(?:₹|rs\.?|inr)\s*([\d,]+\.?\d*)', caseSensitive: false)
          .firstMatch(body);
      if (amtMatch == null) continue;

      final amt = double.tryParse(amtMatch.group(1)!.replaceAll(',', '')) ?? 0;
      final hashInput = '$body|$date';
      final hash = sha1.convert(utf8.encode(hashInput)).toString();
      if (_seenHashes.contains(hash)) continue;
      _seenHashes.add(hash);

      final isDebit = RegExp(r'\b(debited|paid|spent|purchased|sent|used|withdrawn)\b').hasMatch(lower);
      final isCredit = RegExp(r'\b(credited|received|deposited|refund|cashback|added)\b').hasMatch(lower);

      if (!isDebit && !isCredit) continue;

      if (isDebit) {
        debit += amt;
      } else if (isCredit) {
        credit += amt;
      }

      txns.add(_Txn(body: body, amount: amt, isDebit: isDebit));
    }

    setState(() {
      _txns = txns;
      _totalDebit = debit;
      _totalCredit = credit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = _totalCredit - _totalDebit;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartPaisa', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade50,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.arrow_upward,
                    label: 'Debit',
                    amount: _totalDebit,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.arrow_downward,
                    label: 'Credit',
                    amount: _totalCredit,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.account_balance_wallet,
                    label: 'Balance',
                    amount: balance,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _txns.isEmpty
                ? const Center(child: Text('No transactions found'))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _txns.length,
              itemBuilder: (_, i) {
                final t = _txns[i];
                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      t.isDebit ? Colors.red.shade100 : Colors.green.shade100,
                      child: Icon(
                        t.isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                        color: t.isDebit ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(
                      '₹${t.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      t.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Txn {
  final String body;
  final double amount;
  final bool isDebit;
  _Txn({required this.body, required this.amount, required this.isDebit});
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final Color color;
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withOpacity(0.07),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}