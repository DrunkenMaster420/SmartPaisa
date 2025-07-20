import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smswatcher/smswatcher.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPaisa Transactions',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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
  List<Map<String, dynamic>> _messages = [];

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
    // Fetch existing SMS history, defaulting to empty list if null
    final history = await _smsWatcher.getAllSMS() ?? <Map<String, dynamic>>[];
    setState(() => _messages = history);
    // Listen for incoming SMS via the correct stream method
    _smsWatcher.getStreamOfSMS().listen((sms) {
      setState(() => _messages.insert(0, sms));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SmartPaisa Transactions')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final sms = _messages[index];
          final body = sms['body'] as String? ?? '';
          final lower = body.toLowerCase();
          if (!lower.contains('debited') && !lower.contains('credited')) {
            return const SizedBox.shrink();
          }
          final match = RegExp(r'(?:\u20B9|Rs\.?|INR)\s*([\d,]+\.?\d*)')
              .firstMatch(body);
          final amount = match?.group(1)?.replaceAll(',', '') ?? '0';
          final type = lower.contains('debited') ? 'Debit' : 'Credit';
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(
                type == 'Debit' ? Icons.arrow_upward : Icons.arrow_downward,
                color: type == 'Debit' ? Colors.red : Colors.green,
              ),
              title: Text('$type: ₹$amount'),
              subtitle: Text(body),
            ),
          );
        },
      ),
    );
  }
}
