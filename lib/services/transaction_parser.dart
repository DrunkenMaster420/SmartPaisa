import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../ models/transaction.dart';

class TransactionParser {
  // Enhanced bank sender patterns - including empty/null senders
  static final Set<String> _bankSenders = {
    'SBIINB', 'HDFCBK', 'ICICIB', 'AXISBK', 'PNBSMS', 'CBSSBI', 'IOBMSG',
    'SBIMSG', 'CANBNK', 'BOIIND', 'UNIONBK', 'INDSMS', 'KOTAKB', 'YESBNK',
    'RBLBNK', 'IDFCBK', 'SCBIND', 'CITIBK', 'HSBCIN', 'DEUTIN', 'FEDBNK',
    'KARBNK', 'TJSB', 'DCBBNK', 'BANDHAN', 'AUBANK', 'ESAFBNK', 'FINCITI',
    'SBI', 'HDFC', 'ICICI', 'AXIS', 'PNB', 'BOI', 'CANARA', 'UNION',
    'KOTAK', 'YES', 'RBL', 'IDFC', 'SC', 'CITI', 'HSBC', 'DEUTSCHE',
    // Adding Kotak specific patterns
    'KOTAK', 'KOTAKBANK', 'KMB',
    // Adding common numeric bank codes
    '777777', '666666', '555555', '444444'
  };

  // Enhanced bank name patterns in message content
  static final Set<String> _bankNamesInMessage = {
    'kotak bank', 'hdfc bank', 'icici bank', 'sbi bank', 'axis bank',
    'pnb bank', 'canara bank', 'union bank', 'yes bank', 'rbl bank',
    'idfc bank', 'bandhan bank', 'au bank', 'federal bank'
  };

  // UPI sender patterns
  static final Set<String> _upiSenders = {
    'GPAY', 'PHONEPE', 'PAYTM', 'AMAZONP', 'MOBIKW', 'FREECHARGE',
    'BHARATPE', 'CRED', 'RAZORPAY', 'CASHFREE', 'UPIPAY', 'JIOMONEY',
    'AIRTEL', 'OXIGEN', 'PAYPAL', 'WHATSAPP', 'FACEBOOK', 'INSTAMOJO',
    'BILLDESK', 'CCAVENUE', 'PAYU', 'EASEBUZZ', 'ATOM', 'CITRUS',
    'GOOGLEPAY', 'PHONEPAY', 'PAYTMBANK', 'YESBANK', 'SBIUPI'
  };

  // Enhanced amount regex patterns
  static final List<RegExp> _amountPatterns = [
    // Standard patterns
    RegExp(r'(?:Rs\.?\s*|INR\s*|₹\s*)([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:Rs\.?|INR|₹)', caseSensitive: false),

    // UPI specific patterns
    RegExp(r'(?:received|paid|sent)\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'amount\s+(?:of\s+)?(?:Rs\.?\s*|INR\s*|₹\s*)?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // For your specific message format
    RegExp(r'received\s+Rs\.([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
  ];

  // Transaction type patterns
  static final RegExp _debitPattern = RegExp(
      r'\b(debited|debit|paid|spent|withdrawn|purchase|bought|charged|bill|emi|transfer|sent|used)\b',
      caseSensitive: false
  );

  static final RegExp _creditPattern = RegExp(
      r'\b(credited|credit|received|deposited|refund|cashback|salary|bonus|added|reward)\b',
      caseSensitive: false
  );

  // Spam detection patterns
  static final List<RegExp> _spamPatterns = [
    RegExp(r'\b(offer|discount|win|winner|congratulations|lottery|prize|gift|click|download|register|free)\b', caseSensitive: false),
    RegExp(r'\b(otp|verification|verify|code|pin)\b', caseSensitive: false),
  ];

  Transaction? parseTransaction(String message, String sender, int timestamp) {
    try {
      print('🔍 Parsing message from "$sender": ${message.substring(0, message.length > 100 ? 100 : message.length)}...');

      final cleanMessage = _cleanMessage(message);

      // Check if it's a valid transaction message
      if (!_isValidTransactionMessage(cleanMessage, sender)) {
        print('❌ Not a valid transaction message');
        return null;
      }

      print('✅ Valid transaction message detected');

      // Extract amount
      final amount = _extractAmount(cleanMessage);
      if (amount == null || amount <= 0) {
        print('❌ No valid amount found');
        return null;
      }

      print('💰 Amount extracted: ₹$amount');

      // Determine transaction type
      final type = _determineTransactionType(cleanMessage);
      if (type == null) {
        print('❌ Could not determine transaction type');
        return null;
      }

      print('📊 Transaction type: ${type.name}');

      // Extract merchant
      final merchant = _extractMerchant(cleanMessage);
      print('🏪 Merchant: $merchant');

      // Use bank name from message if sender is empty
      final effectiveSender = sender.isEmpty ? _extractBankFromMessage(cleanMessage) : sender;

      // Extract additional details
      final accountNumber = _extractAccountNumber(cleanMessage);
      final referenceNumber = _extractReferenceNumber(cleanMessage);
      final balance = _extractBalance(cleanMessage);

      // Generate unique ID
      final id = _generateTransactionId(cleanMessage, timestamp, effectiveSender);

      final transaction = Transaction(
        id: id,
        amount: amount,
        type: type,
        merchant: merchant,
        sender: effectiveSender,
        dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
        originalMessage: message,
        accountNumber: accountNumber,
        referenceNumber: referenceNumber,
        balance: balance,
      );

      print('🎉 Transaction created successfully: ₹$amount ${type.name} - $merchant');
      return transaction;

    } catch (e) {
      print('❌ Error parsing transaction: $e');
      return null;
    }
  }

  String _cleanMessage(String message) {
    return message
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isValidTransactionMessage(String message, String sender) {
    final lowerMsg = message.toLowerCase();
    final upperSender = sender.toUpperCase();

    print('🔍 Checking sender validity: "$upperSender"');

    // Check if sender is from known financial institutions
    bool isFromBank = _bankSenders.any((bank) => upperSender.contains(bank));
    bool isFromUPI = _upiSenders.any((upi) => upperSender.contains(upi));

    // Check for numeric senders (many banks use 6-digit numbers)
    bool isNumericSender = RegExp(r'^\d{5,6}$').hasMatch(sender);

    // NEW: Check if message contains bank names (for empty/unknown senders)
    bool hasBankInMessage = _bankNamesInMessage.any((bank) => lowerMsg.contains(bank));

    // NEW: Check for UPI reference patterns
    bool hasUpiRef = lowerMsg.contains('upi ref') || lowerMsg.contains('upi id') || lowerMsg.contains('@');

    print('📱 Sender check - Bank: $isFromBank, UPI: $isFromUPI, Numeric: $isNumericSender');
    print('📱 Message check - BankInMsg: $hasBankInMessage, UPIRef: $hasUpiRef');

    // Accept if any of these conditions are met
    bool validSender = isFromBank || isFromUPI || isNumericSender || hasBankInMessage || hasUpiRef;

    if (!validSender) {
      print('❌ Sender not recognized as financial institution');
      return false;
    }

    // Check for spam patterns
    for (final pattern in _spamPatterns) {
      if (pattern.hasMatch(lowerMsg)) {
        print('❌ Message flagged as spam');
        return false;
      }
    }

    // Must contain financial keywords
    final hasFinancialKeywords = RegExp(
        r'\b(rs|rupees|₹|amount|paid|received|debited|credited|transaction|bank|card|account|upi|ac\s|a\/c)\b',
        caseSensitive: false
    ).hasMatch(lowerMsg);

    print('💼 Has financial keywords: $hasFinancialKeywords');

    return hasFinancialKeywords;
  }

  double? _extractAmount(String message) {
    print('💰 Extracting amount from: $message');

    for (final pattern in _amountPatterns) {
      final matches = pattern.allMatches(message);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(amountStr);

        print('🔢 Found potential amount: $amountStr = $amount');

        if (amount != null && amount > 0 && amount < 10000000) { // Reasonable limit
          print('✅ Valid amount found: ₹$amount');
          return amount;
        }
      }
    }

    print('❌ No valid amount found');
    return null;
  }

  TransactionType? _determineTransactionType(String message) {
    final lowerMsg = message.toLowerCase();

    print('📊 Determining transaction type for: $lowerMsg');

    // Check for explicit debit indicators
    if (_debitPattern.hasMatch(lowerMsg)) {
      print('✅ Debit transaction detected');
      return TransactionType.debit;
    }

    // Check for explicit credit indicators
    if (_creditPattern.hasMatch(lowerMsg)) {
      print('✅ Credit transaction detected');
      return TransactionType.credit;
    }

    print('❌ Could not determine transaction type');
    return null;
  }

  String _extractMerchant(String message) {
    final lowerMsg = message.toLowerCase();

    // For UPI transactions, try to extract the sender/receiver
    if (message.contains('@')) {
      final upiMatch = RegExp(r'from\s+([^@\s]+@[^@\s]+)', caseSensitive: false).firstMatch(message);
      if (upiMatch != null) {
        return upiMatch.group(1)?.toUpperCase() ?? 'UPI Transfer';
      }

      final upiMatch2 = RegExp(r'to\s+([^@\s]+@[^@\s]+)', caseSensitive: false).firstMatch(message);
      if (upiMatch2 != null) {
        return upiMatch2.group(1)?.toUpperCase() ?? 'UPI Transfer';
      }
    }

    // Try other merchant extraction patterns
    final patterns = [
      RegExp(r'(?:at|to|from)\s+([A-Z][A-Z0-9\s\-]{2,20})', caseSensitive: false),
      RegExp(r'([A-Z][A-Z0-9\s]{2,20})\s+(?:on|dated)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        String merchant = match.group(1)?.trim() ?? '';
        if (merchant.length > 2 && merchant.length < 30) {
          return merchant.toUpperCase();
        }
      }
    }

    return 'UPI Transfer';
  }

  String _extractBankFromMessage(String message) {
    final lowerMsg = message.toLowerCase();

    // Extract bank name from message content
    for (final bank in _bankNamesInMessage) {
      if (lowerMsg.contains(bank)) {
        return bank.toUpperCase().replaceAll(' BANK', '');
      }
    }

    return 'BANK';
  }

  String? _extractAccountNumber(String message) {
    // Extract account number patterns (usually last 4 digits or X followed by digits)
    final patterns = [
      RegExp(r'A\/C\s*[Xx*]{2,}\s*(\d{3,4})', caseSensitive: false),
      RegExp(r'AC\s*[Xx*]{2,}\s*(\d{3,4})', caseSensitive: false),
      RegExp(r'account\s*[Xx*]{2,}\s*(\d{3,4})', caseSensitive: false),
      RegExp(r'[Xx*]{6,}(\d{4})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final accountNum = match.group(1);
        if (accountNum != null && accountNum.length >= 3) {
          return 'XXXX$accountNum';
        }
      }
    }

    return null;
  }

  String? _extractReferenceNumber(String message) {
    // Extract UPI reference, transaction ID, or reference number
    final patterns = [
      RegExp(r'UPI\s*Ref\s*[:.]?\s*(\w+)', caseSensitive: false),
      RegExp(r'Ref\s*(?:No|#|:)?\s*(\w+)', caseSensitive: false),
      RegExp(r'TXN\s*(?:ID|#|:)?\s*(\w+)', caseSensitive: false),
      RegExp(r'Transaction\s*ID\s*[:.]?\s*(\w+)', caseSensitive: false),
      RegExp(r'UTR\s*[:.]?\s*(\w+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final refNum = match.group(1);
        if (refNum != null && refNum.length >= 6) {
          return refNum;
        }
      }
    }

    return null;
  }

  double? _extractBalance(String message) {
    // Extract balance information (usually at the end of the message)
    final patterns = [
      RegExp(r'(?:balance|bal)\s*[:.]?\s*Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'(?:balance|bal)\s*[:.]?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final balanceStr = match.group(1)?.replaceAll(',', '');
        final balance = double.tryParse(balanceStr ?? '');
        if (balance != null && balance >= 0) {
          return balance;
        }
      }
    }

    return null;
  }

  String _generateTransactionId(String message, int timestamp, String sender) {
    final input = '$message|$timestamp|$sender';
    return sha1.convert(utf8.encode(input)).toString().substring(0, 16);
  }
}
