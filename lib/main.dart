// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:smswatcher/smswatcher.dart';
// import 'dart:convert';
// import 'package:crypto/crypto.dart'; // for SHA-1 deduplication
//
// void main() => runApp(const MyApp());
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'SmartPaisa Dashboard',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
//         useMaterial3: true,
//         scaffoldBackgroundColor: Colors.grey.shade100,
//         textTheme: const TextTheme(
//           bodyMedium: TextStyle(fontFamily: 'Segoe UI'),
//         ),
//       ),
//       home: const HomePage(),
//     );
//   }
// }
//
// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   final Smswatcher _smsWatcher = Smswatcher();
//   List<Map<String, dynamic>> _allSms = [];
//   List<_Txn> _txns = [];
//   double _totalDebit = 0, _totalCredit = 0;
//
//   final Set<String> _seenHashes = {};
//
//   @override
//   void initState() {
//     super.initState();
//     _initSms();
//   }
//
//   Future<void> _initSms() async {
//     final status = await Permission.sms.request();
//     if (!status.isGranted) {
//       openAppSettings();
//       return;
//     }
//     final history = await _smsWatcher.getAllSMS() ?? [];
//     _allSms = history.cast<Map<String, dynamic>>();
//     _processTransactions();
//     _smsWatcher.getStreamOfSMS().listen((sms) {
//       _allSms.insert(0, sms);
//       _processTransactions();
//     });
//   }
//
//   void _processTransactions() {
//     final List<_Txn> txns = [];
//     double debit = 0, credit = 0;
//     _seenHashes.clear();
//
//     for (var sms in _allSms) {
//       final body = (sms['body'] as String?)?.trim() ?? '';
//       final addr = sms['address'] as String? ?? '';
//       final date = sms['date'] as int? ?? 0;
//
//       final lower = body.toLowerCase();
//
//       if (lower.contains('emi') ||
//           lower.contains('loan') ||
//           lower.contains('requested') ||
//           lower.contains('reward') ||
//           lower.contains('offer') ||
//           lower.contains('gift') ||
//           lower.contains('coupon')) continue;
//
//       final amtMatch = RegExp(r'(?:₹|rs\.?|inr)\s*([\d,]+\.?\d*)', caseSensitive: false)
//           .firstMatch(body);
//       if (amtMatch == null) continue;
//
//       final amt = double.tryParse(amtMatch.group(1)!.replaceAll(',', '')) ?? 0;
//       final hashInput = '$body|$date';
//       final hash = sha1.convert(utf8.encode(hashInput)).toString();
//       if (_seenHashes.contains(hash)) continue;
//       _seenHashes.add(hash);
//
//       final isDebit = RegExp(r'\b(debited|paid|spent|purchased|sent|used|withdrawn)\b').hasMatch(lower);
//       final isCredit = RegExp(r'\b(credited|received|deposited|refund|cashback|added)\b').hasMatch(lower);
//
//       if (!isDebit && !isCredit) continue;
//
//       if (isDebit) {
//         debit += amt;
//       } else if (isCredit) {
//         credit += amt;
//       }
//
//       txns.add(_Txn(body: body, amount: amt, isDebit: isDebit));
//     }
//
//     setState(() {
//       _txns = txns;
//       _totalDebit = debit;
//       _totalCredit = credit;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final balance = _totalCredit - _totalDebit;
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('SmartPaisa', style: TextStyle(fontWeight: FontWeight.bold)),
//         centerTitle: true,
//         backgroundColor: Colors.teal.shade50,
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: _SummaryCard(
//                     icon: Icons.arrow_upward,
//                     label: 'Debit',
//                     amount: _totalDebit,
//                     color: Colors.red,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _SummaryCard(
//                     icon: Icons.arrow_downward,
//                     label: 'Credit',
//                     amount: _totalCredit,
//                     color: Colors.green,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _SummaryCard(
//                     icon: Icons.account_balance_wallet,
//                     label: 'Balance',
//                     amount: balance,
//                     color: Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(),
//           Expanded(
//             child: _txns.isEmpty
//                 ? const Center(child: Text('No transactions found'))
//                 : ListView.builder(
//               padding: const EdgeInsets.symmetric(horizontal: 8),
//               itemCount: _txns.length,
//               itemBuilder: (_, i) {
//                 final t = _txns[i];
//                 return Card(
//                   elevation: 1.5,
//                   margin: const EdgeInsets.symmetric(vertical: 6),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: ListTile(
//                     leading: CircleAvatar(
//                       backgroundColor:
//                       t.isDebit ? Colors.red.shade100 : Colors.green.shade100,
//                       child: Icon(
//                         t.isDebit ? Icons.arrow_upward : Icons.arrow_downward,
//                         color: t.isDebit ? Colors.red : Colors.green,
//                       ),
//                     ),
//                     title: Text(
//                       '₹${t.amount.toStringAsFixed(2)}',
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     subtitle: Text(
//                       t.body,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _Txn {
//   final String body;
//   final double amount;
//   final bool isDebit;
//   _Txn({required this.body, required this.amount, required this.isDebit});
// }
//
// class _SummaryCard extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final double amount;
//   final Color color;
//   const _SummaryCard({
//     required this.icon,
//     required this.label,
//     required this.amount,
//     required this.color,
//     super.key,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       color: color.withOpacity(0.07),
//       child: Padding(
//         padding: const EdgeInsets.all(14),
//         child: Column(
//           children: [
//             Icon(icon, color: color),
//             const SizedBox(height: 8),
//             Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
//             const SizedBox(height: 6),
//             Text(
//               '₹${amount.toStringAsFixed(2)}',
//               style: TextStyle(
//                 color: color,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:smswatcher/smswatcher.dart';
// import 'dart:convert';
// import 'package:crypto/crypto.dart';
//
// void main() => runApp(const MyApp());
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'SmartPaisa Dashboard',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
//         useMaterial3: true,
//         scaffoldBackgroundColor: Colors.grey.shade100,
//         textTheme: const TextTheme(
//           bodyMedium: TextStyle(fontFamily: 'Segoe UI'),
//         ),
//       ),
//       home: const HomePage(),
//     );
//   }
// }
//
// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   final Smswatcher _smsWatcher = Smswatcher();
//   List<Map<String, dynamic>> _allSms = [];
//   List<Transaction> _transactions = [];
//   double _totalDebit = 0, _totalCredit = 0;
//   final Set<String> _seenHashes = {};
//   final TransactionParser _parser = TransactionParser();
//
//   @override
//   void initState() {
//     super.initState();
//     _initSms();
//   }
//
//   Future<void> _initSms() async {
//     final status = await Permission.sms.request();
//     if (!status.isGranted) {
//       openAppSettings();
//       return;
//     }
//     final history = await _smsWatcher.getAllSMS() ?? [];
//     _allSms = history.cast<Map<String, dynamic>>();
//     _processTransactions();
//     _smsWatcher.getStreamOfSMS().listen((sms) {
//       _allSms.insert(0, sms);
//       _processTransactions();
//     });
//   }
//
//   void _processTransactions() {
//     final List<Transaction> transactions = [];
//     double debit = 0, credit = 0;
//     _seenHashes.clear();
//
//     for (var sms in _allSms) {
//       final body = (sms['body'] as String?)?.trim() ?? '';
//       final address = sms['address'] as String? ?? '';
//       final date = sms['date'] as int? ?? 0;
//
//       // Create hash for deduplication
//       final hashInput = '$body|$date|$address';
//       final hash = sha1.convert(utf8.encode(hashInput)).toString();
//       if (_seenHashes.contains(hash)) continue;
//
//       // Parse transaction from SMS
//       final transaction = _parser.parseTransaction(body, address, date);
//       if (transaction != null) {
//         _seenHashes.add(hash);
//         transactions.add(transaction);
//
//         if (transaction.type == TransactionType.debit) {
//           debit += transaction.amount;
//         } else {
//           credit += transaction.amount;
//         }
//       }
//     }
//
//     setState(() {
//       _transactions = transactions;
//       _totalDebit = debit;
//       _totalCredit = credit;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final balance = _totalCredit - _totalDebit;
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('SmartPaisa', style: TextStyle(fontWeight: FontWeight.bold)),
//         centerTitle: true,
//         backgroundColor: Colors.teal.shade50,
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: _SummaryCard(
//                     icon: Icons.arrow_upward,
//                     label: 'Debit',
//                     amount: _totalDebit,
//                     color: Colors.red,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _SummaryCard(
//                     icon: Icons.arrow_downward,
//                     label: 'Credit',
//                     amount: _totalCredit,
//                     color: Colors.green,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _SummaryCard(
//                     icon: Icons.account_balance_wallet,
//                     label: 'Balance',
//                     amount: balance,
//                     color: Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(),
//           Expanded(
//             child: _transactions.isEmpty
//                 ? const Center(child: Text('No transactions found'))
//                 : ListView.builder(
//               padding: const EdgeInsets.symmetric(horizontal: 8),
//               itemCount: _transactions.length,
//               itemBuilder: (_, i) {
//                 final txn = _transactions[i];
//                 return Card(
//                   elevation: 1.5,
//                   margin: const EdgeInsets.symmetric(vertical: 6),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: ListTile(
//                     leading: CircleAvatar(
//                       backgroundColor: txn.type == TransactionType.debit
//                           ? Colors.red.shade100
//                           : Colors.green.shade100,
//                       child: Icon(
//                         txn.type == TransactionType.debit
//                             ? Icons.arrow_upward
//                             : Icons.arrow_downward,
//                         color: txn.type == TransactionType.debit
//                             ? Colors.red
//                             : Colors.green,
//                       ),
//                     ),
//                     title: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           '₹${txn.amount.toStringAsFixed(2)}',
//                           style: const TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                         if (txn.merchant.isNotEmpty)
//                           Chip(
//                             label: Text(
//                               txn.merchant,
//                               style: const TextStyle(fontSize: 10),
//                             ),
//                             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                           ),
//                       ],
//                     ),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           txn.originalMessage,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           'From: ${txn.sender}',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                     isThreeLine: true,
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Enhanced Transaction Model
// class Transaction {
//   final String id;
//   final double amount;
//   final TransactionType type;
//   final String merchant;
//   final String sender;
//   final DateTime dateTime;
//   final String originalMessage;
//   final String? accountNumber;
//   final String? referenceNumber;
//   final double? balance;
//
//   Transaction({
//     required this.id,
//     required this.amount,
//     required this.type,
//     required this.merchant,
//     required this.sender,
//     required this.dateTime,
//     required this.originalMessage,
//     this.accountNumber,
//     this.referenceNumber,
//     this.balance,
//   });
// }
//
// enum TransactionType { debit, credit }
//
// // Comprehensive Transaction Parser
// class TransactionParser {
//   // Bank sender patterns
//   static final Set<String> _bankSenders = {
//     'SBIINB', 'HDFCBK', 'ICICIB', 'AXISBK', 'PNBSMS', 'CBSSBI', 'IOBMSG',
//     'SBIMSG', 'CANBNK', 'BOIIND', 'UNIONBK', 'INDSMS', 'KOTAKB', 'YESBNK',
//     'RBLBNK', 'IDFCBK', 'SCBIND', 'CITIBK', 'HSBCIN', 'DEUTIN'
//   };
//
//   // UPI sender patterns
//   static final Set<String> _upiSenders = {
//     'GPAY', 'PHONEPE', 'PAYTM', 'AMAZONP', 'MOBIKW', 'FREECHARGE',
//     'BHARATPE', 'CRED', 'RAZORPAY', 'CASHFREE', 'UPIPAY'
//   };
//
//   // Credit card sender patterns
//   static final Set<String> _creditCardSenders = {
//     'HDFCCC', 'ICICCC', 'SBICRD', 'AXISCC', 'CITICC', 'AMEXCC',
//     'SCBCC', 'YESCC', 'KOTAKC', 'HSBC'
//   };
//
//   // Amount regex patterns - comprehensive
//   static final List<RegExp> _amountPatterns = [
//     // Standard Indian currency formats
//     RegExp(r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
//     RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:Rs\.?|INR|₹)', caseSensitive: false),
//     // Amount in words followed by numbers
//     RegExp(r'amount\s+(?:of\s+)?(?:Rs\.?|INR|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
//     // UPI specific patterns
//     RegExp(r'(?:paid|sent|received)\s+(?:Rs\.?|INR|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
//     // Card transaction patterns
//     RegExp(r'(?:purchase|transaction)\s+(?:of\s+)?(?:Rs\.?|INR|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
//   ];
//
//   // Debit keywords
//   static final RegExp _debitPattern = RegExp(
//       r'\b(debited|debit|paid|purchase|spent|withdrawn|sent|used|charged|bill|emi|fee|transferred)\b',
//       caseSensitive: false
//   );
//
//   // Credit keywords
//   static final RegExp _creditPattern = RegExp(
//       r'\b(credited|credit|received|deposited|refund|cashback|interest|salary|bonus|dividend|added|reward)\b',
//       caseSensitive: false
//   );
//
//   // Merchant extraction patterns
//   static final List<RegExp> _merchantPatterns = [
//     // At merchant/to patterns
//     RegExp(r'(?:at|to|from)\s+([A-Z0-9\s\-\*]+?)(?:\s+on|\s+dated|\s+\d|\.|$)', caseSensitive: false),
//     // UPI patterns
//     RegExp(r'(?:to|from)\s+([A-Z0-9\s\-\*]+?)(?:\s+UPI|\s+\d|\.|$)', caseSensitive: false),
//     // Card patterns
//     RegExp(r'(?:POS|Card)\s+([A-Z0-9\s\-\*]+?)(?:\s+on|\s+dated|\.|$)', caseSensitive: false),
//   ];
//
//   // Account number patterns
//   static final RegExp _accountPattern = RegExp(r'(?:A\/C|AC|Account)[\s\*]*(\*+\d{4}|\d{4,16})');
//
//   // Reference number patterns
//   static final RegExp _referencePattern = RegExp(r'(?:Ref|TXN|UTR|RRN)[\s\#\:]*([A-Z0-9]+)');
//
//   // Balance patterns
//   static final RegExp _balancePattern = RegExp(r'(?:balance|bal|available)\s*(?:Rs\.?|INR|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
//
//   // Spam/promotional keywords to exclude
//   static final RegExp _spamPatterns = RegExp(
//       r'\b(offer|discount|cashback offer|reward|gift|coupon|voucher|winner|congratulations|click|download|install|register|sign up|join now|limited time|hurry|free|bonus points|scratch|spin|lucky|contest|survey)\b',
//       caseSensitive: false
//   );
//
//   // OTP and verification patterns to exclude
//   static final RegExp _otpPatterns = RegExp(
//       r'\b(otp|one time password|verification code|verify|authenticate|login|signin|registration|confirmation)\b',
//       caseSensitive: false
//   );
//
//   Transaction? parseTransaction(String message, String sender, int timestamp) {
//     // Clean and normalize message
//     final cleanMessage = _cleanMessage(message);
//
//     // Skip if it's spam, promotional, or OTP message
//     if (_isSpamMessage(cleanMessage)) return null;
//
//     // Extract amount
//     final amount = _extractAmount(cleanMessage);
//     if (amount == null || amount <= 0) return null;
//
//     // Determine transaction type
//     final type = _determineTransactionType(cleanMessage);
//     if (type == null) return null;
//
//     // Extract merchant
//     final merchant = _extractMerchant(cleanMessage);
//
//     // Extract additional details
//     final accountNumber = _extractAccountNumber(cleanMessage);
//     final referenceNumber = _extractReferenceNumber(cleanMessage);
//     final balance = _extractBalance(cleanMessage);
//
//     // Generate unique ID
//     final id = _generateTransactionId(cleanMessage, timestamp);
//
//     return Transaction(
//       id: id,
//       amount: amount,
//       type: type,
//       merchant: merchant,
//       sender: sender,
//       dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
//       originalMessage: message,
//       accountNumber: accountNumber,
//       referenceNumber: referenceNumber,
//       balance: balance,
//     );
//   }
//
//   String _cleanMessage(String message) {
//     return message
//         .replaceAll(RegExp(r'\s+'), ' ')
//         .replaceAll(RegExp(r'[^\w\s₹\.\,\-\*\@\:\#\/]'), ' ')
//         .trim();
//   }
//
//   bool _isSpamMessage(String message) {
//     final lowerMsg = message.toLowerCase();
//
//     // Check for spam patterns
//     if (_spamPatterns.hasMatch(lowerMsg)) return true;
//
//     // Check for OTP patterns
//     if (_otpPatterns.hasMatch(lowerMsg)) return true;
//
//     // Check for common spam keywords
//     final spamKeywords = [
//       'congratulations', 'winner', 'lucky', 'free', 'click here',
//       'download app', 'install app', 'register now', 'limited offer',
//       'expire', 'hurry', 'grab now', 'miss out', 'exclusive'
//     ];
//
//     for (final keyword in spamKeywords) {
//       if (lowerMsg.contains(keyword)) return true;
//     }
//
//     return false;
//   }
//
//   double? _extractAmount(String message) {
//     for (final pattern in _amountPatterns) {
//       final match = pattern.firstMatch(message);
//       if (match != null) {
//         final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
//         final amount = double.tryParse(amountStr);
//         if (amount != null && amount > 0) {
//           return amount;
//         }
//       }
//     }
//     return null;
//   }
//
//   TransactionType? _determineTransactionType(String message) {
//     final lowerMsg = message.toLowerCase();
//
//     // Check for explicit debit indicators
//     if (_debitPattern.hasMatch(lowerMsg)) {
//       return TransactionType.debit;
//     }
//
//     // Check for explicit credit indicators
//     if (_creditPattern.hasMatch(lowerMsg)) {
//       return TransactionType.credit;
//     }
//
//     // Additional context-based detection
//     if (lowerMsg.contains('available balance') && lowerMsg.contains('debited')) {
//       return TransactionType.debit;
//     }
//
//     if (lowerMsg.contains('available balance') && lowerMsg.contains('credited')) {
//       return TransactionType.credit;
//     }
//
//     return null;
//   }
//
//   String _extractMerchant(String message) {
//     for (final pattern in _merchantPatterns) {
//       final match = pattern.firstMatch(message);
//       if (match != null) {
//         String merchant = match.group(1)?.trim() ?? '';
//         // Clean up merchant name
//         merchant = merchant.replaceAll(RegExp(r'\*+'), '');
//         merchant = merchant.replaceAll(RegExp(r'\s+'), ' ');
//         if (merchant.length > 3 && merchant.length < 50) {
//           return merchant.toUpperCase();
//         }
//       }
//     }
//     return 'Unknown';
//   }
//
//   String? _extractAccountNumber(String message) {
//     final match = _accountPattern.firstMatch(message);
//     return match?.group(1);
//   }
//
//   String? _extractReferenceNumber(String message) {
//     final match = _referencePattern.firstMatch(message);
//     return match?.group(1);
//   }
//
//   double? _extractBalance(String message) {
//     final match = _balancePattern.firstMatch(message);
//     if (match != null) {
//       final balanceStr = match.group(1)?.replaceAll(',', '') ?? '';
//       return double.tryParse(balanceStr);
//     }
//     return null;
//   }
//
//   String _generateTransactionId(String message, int timestamp) {
//     final input = '$message|$timestamp';
//     return sha1.convert(utf8.encode(input)).toString().substring(0, 16);
//   }
// }
//
// class _SummaryCard extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final double amount;
//   final Color color;
//
//   const _SummaryCard({
//     required this.icon,
//     required this.label,
//     required this.amount,
//     required this.color,
//     super.key,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       color: color.withOpacity(0.07),
//       child: Padding(
//         padding: const EdgeInsets.all(14),
//         child: Column(
//           children: [
//             Icon(icon, color: color),
//             const SizedBox(height: 8),
//             Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
//             const SizedBox(height: 6),
//             Text(
//               '₹${amount.toStringAsFixed(2)}',
//               style: TextStyle(
//                 color: color,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

/////////////////////////////////////////////////test//////////////
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  runApp(const SmartPaisaApp());
}

class SmartPaisaApp extends StatelessWidget {
  const SmartPaisaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPaisa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ).copyWith(
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
