import 'package:smswatcher/smswatcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../ models/transaction.dart';
import 'transaction_parser.dart';
import 'storage_service.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Smswatcher _smsWatcher = Smswatcher();
  final TransactionParser _parser = TransactionParser();
  final StorageService _storageService = StorageService.instance;

  StreamController<Transaction>? _transactionController;

  bool _isInitialized = false;
  bool _isListening = false;
  DateTime? _appFirstUseDate;
  StreamSubscription? _smsSubscription;

  final Set<String> _processedTransactionIds = <String>{};
  final Set<String> _processedSmsHashes = <String>{};
  final Set<String> _processedMessageBodies = <String>{}; // NEW: Track exact message content
  final Set<String> _processedReferenceNumbers = <String>{}; // NEW: Track reference numbers
  bool _isProcessing = false;
  DateTime? _lastProcessedTime;
  static const Duration _minProcessingInterval = Duration(milliseconds: 2000); // Increased from 1000ms

  bool _processHistoricalSms = true;
  bool _debugMode = true;

  bool get isInitialized => _isInitialized;

  int _getTimestamp(dynamic rawDate) {
    if (rawDate is int) return rawDate;
    if (rawDate is String && RegExp(r'^\d+$').hasMatch(rawDate)) {
      try {
        return int.parse(rawDate);
      } catch (e) {
        print('⚠️ Failed to parse date string: $rawDate');
      }
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  Future<bool> requestPermissions() async {
    print('🔐 Requesting SMS permissions...');

    try {
      final smsStatus = await Permission.sms.request();
      print('📱 SMS Permission Status: $smsStatus');

      final notificationStatus = await Permission.notification.request();
      print('🔔 Notification Permission Status: $notificationStatus');

      if (smsStatus.isDenied || smsStatus.isPermanentlyDenied) {
        if (smsStatus.isPermanentlyDenied) {
          print('⚠️ SMS permission permanently denied. Opening app settings...');
          await openAppSettings();
        }
        return false;
      }

      return smsStatus.isGranted;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Initializing SMS Service...');

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      print('❌ Cannot initialize SMS service without permissions');
      return;
    }

    try {
      _transactionController ??= StreamController<Transaction>.broadcast();

      _processHistoricalSms = _storageService.getSetting<bool>('process_historical_sms', true);
      _debugMode = _storageService.getSetting<bool>('sms_debug_mode', true);

      await _setupAppFirstUseDate();
      await _loadProcessedTransactions();

      if (_debugMode) {
        _parser.debugTestParsing();
      }

      _startSmsListener();

      _isInitialized = true;
      print('✅ SMS Service initialized successfully');
      print('📊 Settings: Historical SMS: $_processHistoricalSms, Debug: $_debugMode');
    } catch (e) {
      print('❌ Error initializing SMS service: $e');
      throw Exception('Failed to initialize SMS service: $e');
    }
  }

  Future<void> _setupAppFirstUseDate() async {
    final savedFirstUseDate = _storageService.getSetting<String>('app_first_use_date', '');
    if (savedFirstUseDate.isEmpty) {
      _appFirstUseDate = DateTime.now();
      await _storageService.saveSetting('app_first_use_date', _appFirstUseDate!.toIso8601String());
      print('📅 App first use date set: $_appFirstUseDate');
    } else {
      try {
        _appFirstUseDate = DateTime.parse(savedFirstUseDate);
        print('📅 App first use date loaded: $_appFirstUseDate');
      } catch (e) {
        _appFirstUseDate = DateTime.now();
        await _storageService.saveSetting('app_first_use_date', _appFirstUseDate!.toIso8601String());
      }
    }
  }

  Future<void> _loadProcessedTransactions() async {
    try {
      _processedTransactionIds.clear();
      _processedSmsHashes.clear();
      _processedMessageBodies.clear();
      _processedReferenceNumbers.clear();

      final existingTransactions = await _storageService.getTransactions();
      for (final transaction in existingTransactions) {
        _processedTransactionIds.add(transaction.id);

        // Cache the exact message body to prevent reprocessing
        _processedMessageBodies.add(transaction.originalMessage.trim());

        // Cache reference numbers to prevent duplicates
        if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
          _processedReferenceNumbers.add(transaction.referenceNumber!);
        }
      }
      print('📝 Loaded ${_processedTransactionIds.length} existing transaction IDs');
      print('📝 Cached ${_processedMessageBodies.length} message bodies for duplicate prevention');
      print('📝 Cached ${_processedReferenceNumbers.length} reference numbers');
    } catch (e) {
      print('❌ Error loading processed transactions: $e');
    }
  }

  // ENHANCED: Multiple duplicate detection methods
  String _generateSmsHash(String body, String address, int timestamp) {
    // Create hash based on content and sender, but with time window for rapid duplicates
    final timeWindow = (timestamp / 5000).floor() * 5000; // 5-second window
    return '${body.trim().hashCode}_${address.hashCode}_$timeWindow';
  }

  String _generateContentHash(String body) {
    // Simple content-based hash for exact duplicate detection
    return body.trim().replaceAll(RegExp(r'\s+'), ' ').hashCode.toString();
  }

  bool _isDuplicateByContent(String messageBody) {
    final cleanBody = messageBody.trim();
    return _processedMessageBodies.contains(cleanBody);
  }

  bool _isDuplicateByReference(String? referenceNumber) {
    if (referenceNumber == null || referenceNumber.isEmpty) return false;
    return _processedReferenceNumbers.contains(referenceNumber);
  }

  void _startSmsListener() {
    if (_isListening) return;

    try {
      print('👂 Starting SMS listener...');

      _smsSubscription?.cancel();

      _smsSubscription = _smsWatcher.getStreamOfSMS().listen(
            (sms) async {
          if (sms != null && !_isProcessing) {
            await _processSmsMessage(sms);
          }
        },
        onError: (error) {
          print('❌ SMS stream error: $error');
          _isListening = false;
          Future.delayed(const Duration(seconds: 3), () {
            if (_isInitialized && !_isListening) {
              print('🔄 Restarting SMS listener...');
              _startSmsListener();
            }
          });
        },
        onDone: () {
          print('⚠️ SMS stream ended');
          _isListening = false;
        },
      );

      _isListening = true;
      print('✅ SMS listener started');
    } catch (e) {
      print('❌ Error starting SMS listener: $e');
      _isListening = false;
    }
  }

  Future<void> _processSmsMessage(Map<String, dynamic> sms) async {
    if (_isProcessing) {
      if (_debugMode) {
        print('⏭️ Skipping SMS - already processing another message');
      }
      return;
    }

    // Enhanced rate limiting
    final now = DateTime.now();
    if (_lastProcessedTime != null &&
        now.difference(_lastProcessedTime!).inMilliseconds < _minProcessingInterval.inMilliseconds) {
      if (_debugMode) {
        print('⏭️ Skipping SMS - rate limited (${now.difference(_lastProcessedTime!).inMilliseconds}ms < ${_minProcessingInterval.inMilliseconds}ms)');
      }
      return;
    }

    _isProcessing = true;
    _lastProcessedTime = now;

    try {
      final body = (sms['body'] as String?)?.trim() ?? '';
      final address = (sms['address'] as String?)?.trim() ?? '';
      final timestamp = _getTimestamp(sms['date']);
      final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      if (body.isEmpty) {
        if (_debugMode) {
          print('⏭️ Skipping empty SMS body');
        }
        return;
      }

      // ENHANCED: Multiple duplicate checks before processing
      if (_isDuplicateByContent(body)) {
        if (_debugMode) {
          print('⏭️ Skipping duplicate SMS (exact content match)');
        }
        return;
      }

      // Check for rapid duplicate processing
      final smsHash = _generateSmsHash(body, address, timestamp);
      if (_processedSmsHashes.contains(smsHash)) {
        if (_debugMode) {
          print('⏭️ Skipping duplicate SMS (hash match)');
        }
        return;
      }

      // Historical filter
      if (!_processHistoricalSms && _appFirstUseDate != null && messageTime.isBefore(_appFirstUseDate!)) {
        if (_debugMode) {
          print('⏭️ Skipping historical SMS: ${messageTime.toString()}');
        }
        return;
      }

      if (_debugMode) {
        print('\n📨 Processing SMS from "$address"');
        print('⏰ Timestamp: ${messageTime.toString()}');
        print('💬 Message: ${body.substring(0, body.length > 100 ? 100 : body.length)}${body.length > 100 ? '...' : ''}');
      }

      final transaction = _parser.parseTransaction(body, address, timestamp);

      if (transaction != null) {
        // ENHANCED: Multiple duplicate checks for transactions
        if (_processedTransactionIds.contains(transaction.id)) {
          _processedSmsHashes.add(smsHash);
          _processedMessageBodies.add(body);
          if (_debugMode) {
            print('⏭️ Transaction already exists (ID match): ${transaction.id}');
          }
          return;
        }

        // Check for duplicate by reference number
        if (_isDuplicateByReference(transaction.referenceNumber)) {
          _processedSmsHashes.add(smsHash);
          _processedMessageBodies.add(body);
          if (_debugMode) {
            print('⏭️ Transaction already exists (reference match): ${transaction.referenceNumber}');
          }
          return;
        }

        print('🎉 NEW transaction: ₹${transaction.amount} ${transaction.type.name} - ${transaction.merchant}');
        print('   📧 Account: ${transaction.accountNumber ?? 'N/A'}');
        print('   🔗 Reference: ${transaction.referenceNumber ?? 'N/A'}');
        print('   💰 Balance: ${transaction.balance != null ? '₹${transaction.balance}' : 'N/A'}');

        // Mark as processed BEFORE saving to prevent race conditions
        _processedTransactionIds.add(transaction.id);
        _processedSmsHashes.add(smsHash);
        _processedMessageBodies.add(body);

        if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
          _processedReferenceNumbers.add(transaction.referenceNumber!);
        }

        await _storageService.saveTransaction(transaction);

        if (_transactionController != null && !_transactionController!.isClosed) {
          _transactionController!.add(transaction);
        }

        print('✅ Transaction saved successfully');
      } else {
        _processedSmsHashes.add(smsHash);
        _processedMessageBodies.add(body);
        if (_debugMode) {
          print('❌ Could not parse transaction from SMS');
        }
      }

    } catch (e) {
      print('❌ Error processing SMS: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<Transaction>> scanHistoricalSMS() async {
    print('🔍 Scanning for historical transactions...');

    try {
      final testTransactions = _parser.parseTestNotifications();

      List<Transaction> newTransactions = [];

      for (final transaction in testTransactions) {
        // Enhanced duplicate checking for historical scan
        bool isDuplicate = _processedTransactionIds.contains(transaction.id) ||
            _isDuplicateByReference(transaction.referenceNumber) ||
            _isDuplicateByContent(transaction.originalMessage);

        if (!isDuplicate) {
          await _storageService.saveTransaction(transaction);
          _processedTransactionIds.add(transaction.id);
          _processedMessageBodies.add(transaction.originalMessage.trim());

          if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
            _processedReferenceNumbers.add(transaction.referenceNumber!);
          }

          newTransactions.add(transaction);
          print('✅ Added historical transaction: ₹${transaction.amount} ${transaction.type.name}');
        }
      }

      print('📊 Found ${newTransactions.length} new historical transactions');
      return newTransactions;

    } catch (e) {
      print('❌ Error scanning historical SMS: $e');
      return [];
    }
  }

  Future<void> testSmsProcessing() async {
    print('\n🧪 Testing SMS processing...');

    final testMessages = [
      {
        'body': 'ICICI Bank Acct XX127 debited for Rs 1.00 on 23-Jul-25; ROHIT KUMAR SIN credited. UPI:065659993494. Call 18002662 for dispute.',
        'address': 'ICICIB',
        'date': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'body': 'Your a/c XX7238 is credited for INR 230.00 on 22-07-25 14:46:15 through UPI.Available Bal INR 4033.64 (UPI Ref ID 108522927578).Download PNB ONE-PNB',
        'address': 'PNBSMS',
        'date': DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      },
      {
        'body': 'A/c XX7238 debited INR 180.00 Dt 08-07-25 13:32:31 thru UPI:555521976490.Bal INR 3730.45 Not u?Fwd this SMS to 9264092640 to block UPI.',
        'address': 'PNBSMS',
        'date': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      }
    ];

    for (int i = 0; i < testMessages.length; i++) {
      print('\n--- Test SMS ${i + 1} ---');
      await _processSmsMessage(testMessages[i]);
    }
  }

  Future<List<Transaction>> getHistoricalTransactions() async {
    if (!_isInitialized) {
      await initialize();
    }

    print('📚 Loading transactions...');

    try {
      final storedTransactions = await _storageService.getTransactions();

      final filteredTransactions = storedTransactions.where((transaction) {
        if (_processHistoricalSms || _appFirstUseDate == null) return true;
        return transaction.dateTime.isAfter(_appFirstUseDate!) ||
            transaction.dateTime.isAtSameMomentAs(_appFirstUseDate!);
      }).toList();

      filteredTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      print('✅ Loaded transactions: ${filteredTransactions.length}/${storedTransactions.length}');
      if (_appFirstUseDate != null) {
        print('   📅 Filter from date: $_appFirstUseDate');
      }

      return filteredTransactions;

    } catch (e) {
      print('❌ Error loading historical transactions: $e');
      return [];
    }
  }

  Stream<Transaction> watchNewTransactions() {
    if (!_isInitialized || _transactionController == null) {
      return Stream.empty();
    }
    return _transactionController!.stream;
  }

  Future<void> setProcessHistoricalSms(bool value) async {
    _processHistoricalSms = value;
    await _storageService.saveSetting('process_historical_sms', value);
    print('📊 Historical SMS processing: $value');
  }

  Future<void> setDebugMode(bool value) async {
    _debugMode = value;
    await _storageService.saveSetting('sms_debug_mode', value);
    print('🐛 Debug mode: $value');
  }

  bool get processHistoricalSms => _processHistoricalSms;
  bool get debugMode => _debugMode;

  // ENHANCED: Clear cache method
  void clearProcessedCache() {
    _processedSmsHashes.clear();
    _processedMessageBodies.clear();
    _processedReferenceNumbers.clear();
    print('🧹 Cleared SMS processing cache');
  }

  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'isListening': _isListening,
      'processedTransactions': _processedTransactionIds.length,
      'processedSmsHashes': _processedSmsHashes.length,
      'processedMessageBodies': _processedMessageBodies.length,
      'processedReferenceNumbers': _processedReferenceNumbers.length,
      'appFirstUseDate': _appFirstUseDate?.toIso8601String(),
      'processHistoricalSms': _processHistoricalSms,
      'debugMode': _debugMode,
    };
  }

  void dispose() {
    _isListening = false;
    _smsSubscription?.cancel();
    _smsSubscription = null;
    _transactionController?.close();
    _transactionController = null;
    _processedTransactionIds.clear();
    _processedSmsHashes.clear();
    _processedMessageBodies.clear();
    _processedReferenceNumbers.clear();
    _isInitialized = false;
  }
}
