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
  bool _isProcessing = false;

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

      if (smsStatus.isDenied || smsStatus.isPermanentlyDenied) {
        if (smsStatus.isPermanentlyDenied) {
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

      // Get or set app first use date (NEVER RESET)
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

      await _loadProcessedTransactions();
      _startSmsListener();

      _isInitialized = true;
      print('✅ SMS Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing SMS service: $e');
      throw Exception('Failed to initialize SMS service: $e');
    }
  }

  Future<void> _loadProcessedTransactions() async {
    try {
      _processedTransactionIds.clear();
      final existingTransactions = await _storageService.getTransactions();
      for (final transaction in existingTransactions) {
        _processedTransactionIds.add(transaction.id);
      }
      print('📝 Loaded ${_processedTransactionIds.length} existing transaction IDs');
    } catch (e) {
      print('❌ Error loading processed transactions: $e');
    }
  }

  String _generateSmsHash(String body, String address, int timestamp) {
    return '${body.hashCode}_${address.hashCode}_$timestamp';
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
              _startSmsListener();
            }
          });
        },
        onDone: () {
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
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final body = (sms['body'] as String?)?.trim() ?? '';
      final address = (sms['address'] as String?)?.trim() ?? '';
      final timestamp = _getTimestamp(sms['date']);
      final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      if (body.isEmpty) return;

      // Only process messages AFTER app first use date
      if (_appFirstUseDate != null && messageTime.isBefore(_appFirstUseDate!)) {
        return;
      }

      final smsHash = _generateSmsHash(body, address, timestamp);
      if (_processedSmsHashes.contains(smsHash)) return;

      print('📨 Processing SMS from "$address"');

      final transaction = _parser.parseTransaction(body, address, timestamp);

      if (transaction != null) {
        if (_processedTransactionIds.contains(transaction.id)) {
          _processedSmsHashes.add(smsHash);
          return;
        }

        print('🎉 NEW transaction: ₹${transaction.amount} ${transaction.type.name} - ${transaction.merchant}');

        _processedTransactionIds.add(transaction.id);
        _processedSmsHashes.add(smsHash);

        await _storageService.saveTransaction(transaction);

        if (_transactionController != null && !_transactionController!.isClosed) {
          _transactionController!.add(transaction);
        }
      } else {
        _processedSmsHashes.add(smsHash);
      }

    } catch (e) {
      print('❌ Error processing SMS: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<Transaction>> getHistoricalTransactions() async {
    if (!_isInitialized) {
      await initialize();
    }

    print('📚 Loading transactions from app first use date only...');

    try {
      // Get stored transactions
      final storedTransactions = await _storageService.getTransactions();

      // Filter transactions from app first use date only
      final filteredTransactions = storedTransactions.where((transaction) {
        if (_appFirstUseDate == null) return true;
        return transaction.dateTime.isAfter(_appFirstUseDate!) ||
            transaction.dateTime.isAtSameMomentAs(_appFirstUseDate!);
      }).toList();

      filteredTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      print('✅ Filtered transactions: ${filteredTransactions.length}/${storedTransactions.length}');
      print('   📅 From date: $_appFirstUseDate');

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

  void dispose() {
    _isListening = false;
    _smsSubscription?.cancel();
    _smsSubscription = null;
    _transactionController?.close();
    _transactionController = null;
    _processedTransactionIds.clear();
    _processedSmsHashes.clear();
    _isInitialized = false;
  }
}
