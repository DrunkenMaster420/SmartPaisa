import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../ models/transaction.dart';

class TransactionParser {
  // Enhanced bank sender patterns
  static final Set<String> _bankSenders = {
    'SBIINB', 'HDFCBK', 'ICICIB', 'ICICIBANK', 'ICICIMSG', 'AXISBK',
    'PNBSMS', 'PNBMSG', 'PNBBANK', 'PNBONE', 'CBSSBI', 'IOBMSG',
    'SBIMSG', 'CANBNK', 'BOIIND', 'UNIONBK', 'INDSMS', 'KOTAKB', 'YESBNK',
    'RBLBNK', 'IDFCBK', 'SCBIND', 'CITIBK', 'HSBCIN', 'DEUTIN', 'FEDBNK',
    'KARBNK', 'TJSB', 'DCBBNK', 'BANDHAN', 'AUBANK', 'ESAFBNK', 'FINCITI',
    'SBI', 'HDFC', 'ICICI', 'AXIS', 'PNB', 'BOI', 'CANARA', 'UNION',
    'KOTAK', 'YES', 'RBL', 'IDFC', 'SC', 'CITI', 'HSBC', 'DEUTSCHE',
    'KOTAK', 'KOTAKBANK', 'KMB', 'STANCHART', 'STANDARD',
    '777777', '666666', '555555', '444444', '123456', '654321'
  };

  // FIXED: Enhanced bank names in message detection
  static final Set<String> _bankNamesInMessage = {
    'kotak bank', 'hdfc bank', 'icici bank', 'sbi bank', 'axis bank',
    'pnb bank', 'pnb one', 'canara bank', 'union bank', 'yes bank', 'rbl bank',
    'idfc bank', 'bandhan bank', 'au bank', 'federal bank', 'stanchart', 'standard chartered',
    'sbi', 'hdfc', 'icici', 'axis', 'kotak', 'pnb', 'yes bank', 'canara',
    'union bank', 'bob', 'bank of baroda', 'indian bank', 'central bank',
    'paypal', 'neft', 'rtgs', 'imps',
    // ADDED: Missing bank variations for StanChart and Kotak
    'stanchart', 'standard chartered', 'kotak bank'
  };

  static final Set<String> _upiSenders = {
    'GPAY', 'PHONEPE', 'PAYTM', 'AMAZONP', 'MOBIKW', 'FREECHARGE',
    'BHARATPE', 'CRED', 'RAZORPAY', 'CASHFREE', 'UPIPAY', 'JIOMONEY',
    'AIRTEL', 'OXIGEN', 'PAYPAL', 'WHATSAPP', 'FACEBOOK', 'INSTAMOJO',
    'BILLDESK', 'CCAVENUE', 'PAYU', 'EASEBUZZ', 'ATOM', 'CITRUS',
    'GOOGLEPAY', 'PHONEPAY', 'PAYTMBANK', 'YESBANK', 'SBIUPI'
  };

  // FIXED: Enhanced amount patterns to capture ALL your missing transactions
  static final List<RegExp> _amountPatterns = [
    // ADDED: PNB specific patterns - fixes Transaction 1 & 2
    RegExp(r'debited\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'credited\s+for\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // ADDED: Kotak UPI pattern - fixes Transaction 4
    RegExp(r'Sent\s+Rs\.([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // ADDED: StanChart payment confirmation - fixes Transaction 3
    RegExp(r'payment\s+of\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // Existing working patterns
    RegExp(r'Credited\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'Debited\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'debited\s+by\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'credited\s+by\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'INR\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+credited', caseSensitive: false),
    RegExp(r'INR\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+debited', caseSensitive: false),
    RegExp(r'debited\s+for\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'credited\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // Generic currency patterns
    RegExp(r'(?:Rs\.?\s*|INR\s*|₹\s*)([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:Rs\.?|INR|₹)', caseSensitive: false),

    // Transaction action patterns
    RegExp(r'(?:received|paid|sent)\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'received\s+Rs\.([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // Amount/payment patterns
    RegExp(r'amount\s+(?:of\s+)?(?:Rs\.?\s*|INR\s*|₹\s*)?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'payment\s+of\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'received\s+your\s+payment\s+of\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // Card transaction patterns
    RegExp(r'spent\s+via.*?Rs\.([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'spent.*?Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'for\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+at', caseSensitive: false),
    RegExp(r'alert:\s*rs\.([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'ALERT:\s*Rs\.([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // UPI patterns
    RegExp(r'transferred\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'transfer\s+of\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'UPI.*?Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // Bank-specific patterns
    RegExp(r'acct\s+[x]+\d+\s+debited\s+for\s+rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'a\/c\s+[x]+\d+\s+(?:is\s+)?credited\s+for\s+inr\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'your\s+a\/c.*?(?:debited|credited).*?(?:Rs\.?\s*|INR\s*)([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

    // Generic transaction patterns (catch-all)
    RegExp(r'Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:debited|credited|paid|received|sent|transferred)', caseSensitive: false),
    RegExp(r'INR\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:debited|credited|paid|received|sent|transferred)', caseSensitive: false),

    // Fallback patterns for any missed formats
    RegExp(r'(?:₹|Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{1,2})?)\b', caseSensitive: false),
    RegExp(r'\b([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:₹|Rs\.?|INR)', caseSensitive: false),
  ];

  static final RegExp _debitPattern = RegExp(
      r'\b(debited|debit|paid|spent|withdrawn|purchase|bought|charged|bill|emi|transfer|sent|used)\b',
      caseSensitive: false
  );

  static final RegExp _creditPattern = RegExp(
      r'\b(credited|credit|received|deposited|refund|cashback|salary|bonus|added|reward|deposit)\b',
      caseSensitive: false
  );

  static final List<RegExp> _paymentConfirmationPatterns = [
    RegExp(r'we\s+have\s+received\s+your\s+payment', caseSensitive: false),
    RegExp(r'payment\s+received', caseSensitive: false),
    RegExp(r'payment\s+successful', caseSensitive: false),
    RegExp(r'payment\s+confirmed', caseSensitive: false),
    RegExp(r'thank\s+you\s+for\s+your\s+payment', caseSensitive: false),
  ];

  static final List<RegExp> _creditCardPatterns = [
    RegExp(r'credit\s+card', caseSensitive: false),
    RegExp(r'debit\s+card', caseSensitive: false),
    RegExp(r'card\s+number\s+ending', caseSensitive: false),
    RegExp(r'card\s+no\s+xx', caseSensitive: false),
    RegExp(r'towards\s+your.*card', caseSensitive: false),
    RegExp(r'cc\s+payment', caseSensitive: false),
    RegExp(r'spent\s+via.*card', caseSensitive: false),
    RegExp(r'using.*card', caseSensitive: false),
    RegExp(r'thank\s+you\s+for\s+using.*card', caseSensitive: false),
  ];

  static final List<RegExp> _spamPatterns = [
    RegExp(r'\b(congrats?|congratulations|exclusive|offer|discount|win|winner|lottery|prize|gift|click|register|free)\b', caseSensitive: false),
    RegExp(r'\b(otp|verification|verify|code|pin)\b', caseSensitive: false),
  ];

  // Debug test method with your specific transactions added
  void debugTestParsing() {
    final testMessages = [
      {
        'message': 'ICICI Bank Acct XX127 debited for Rs 1.00 on 23-Jul-25; ROHIT KUMAR SIN credited. UPI:065659993494. Call 18002662 for dispute. SMS BLOCK 127 to 9215676766.',
        'sender': 'ICICIB',
      },
      {
        'message': 'Your a/c XX7238 is credited for INR 230.00 on 22-07-25 14:46:15 through UPI.Available Bal INR 4033.64 (UPI Ref ID 108522927578).Download PNB ONE-PNB',
        'sender': 'PNBSMS',
      },
      {
        'message': 'Dear Customer, INR 9,883.79 credited to your A/c No XX1647 on 25/07/2025 through NEFT with UTR CITIN25598096738 by PAYPAL PAYMENTS PL-OPGSP COLL AC, INFO: BATCHID:0029 P0803L5TAPF7V9V4ZG       -DNTPP42 62E-SBI',
        'sender': '',
      },
      {
        'message': 'Dear UPI user A/C X1647 debited by 4000.0 on date 23Jul25 trf to UMESH  PRASAD Refno 520426657880. If not u? call 1800111109. -SBI',
        'sender': '',
      },
      {
        'message': 'Your A/C XXXXX4216 Credited INR 50,55000 on 04/07/25 -Deposit by transfer from REMITLY INC. Avl Bal INR 61,601.74-SBI',
        'sender': '',
      },
      // ADDED: Your problematic transactions
      {
        'message': 'A/c XX7238 debited INR 140.00 Dt 08-07-25 13:32:31 thru UPI:555521976490.Bal INR 3730.45 Not u?Fwd this SMS to 9264092640 to block UPI.Download PNB ONE-PNB',
        'sender': '',
      },
      {
        'message': 'Your a/c XX7238 is credited for INR 830.00  on 22-07-25 14:46:15 through UPI.Available Bal INR 4033.64 (UPI Ref ID 108522927578).Download PNB ONE-PNB',
        'sender': '',
      },
      {
        'message': 'We have received your payment of INR 9,506.30 towards your credit card number ending 6231. Thank you (Cheque/ECS Payment subject to realisation)-StanChart',
        'sender': '',
      },
      {
        'message': 'Sent Rs.1.00 from Kotak Bank AC X7353 to rohitsinghchandel420@okaxis on 25-07-25.UPI Ref 520604491926. Not you,',
        'sender': '',
      }
    ];

    print('\n🧪 Testing Transaction Parser...');
    print('=' * 50);

    for (int i = 0; i < testMessages.length; i++) {
      final msg = testMessages[i];
      print('\n--- Test ${i + 1} ---');
      print('Sender: "${msg['sender']}"');
      print('Message: ${msg['message']}');

      final transaction = parseTransaction(
          msg['message']!,
          msg['sender']!,
          DateTime.now().millisecondsSinceEpoch
      );

      if (transaction != null) {
        print('✅ SUCCESS:');
        print('   Amount: ₹${transaction.amount}');
        print('   Type: ${transaction.type.name}');
        print('   Merchant: ${transaction.merchant}');
        print('   Sender: ${transaction.sender}');
        print('   Account: ${transaction.accountNumber ?? 'N/A'}');
        print('   Reference: ${transaction.referenceNumber ?? 'N/A'}');
        print('   Balance: ${transaction.balance != null ? '₹${transaction.balance}' : 'N/A'}');
      } else {
        print('❌ FAILED: Could not parse transaction');

        final cleanMessage = _cleanMessage(msg['message']!);
        print('   📋 Debug Info:');
        print('   - Is valid message: ${_isValidTransactionMessage(cleanMessage, msg['sender']!)}');
        print('   - Amount found: ${_extractAmount(cleanMessage)}');
        print('   - Type found: ${_determineTransactionType(cleanMessage)}');
        print('   - Bank from message: ${_extractBankFromMessage(cleanMessage)}');
        print('   - Has payment confirmation: ${_hasPaymentConfirmation(cleanMessage)}');
        print('   - Has credit card: ${_hasCreditCard(cleanMessage)}');
      }
    }

    print('\n' + '=' * 50);
  }

  List<Transaction> parseMultipleMessages(List<Map<String, dynamic>> messages) {
    List<Transaction> validTransactions = [];

    print('📱 Processing ${messages.length} messages...');

    for (int i = 0; i < messages.length; i++) {
      final messageData = messages[i];
      final message = messageData['message'] ?? '';
      final sender = messageData['sender'] ?? '';
      final timestamp = messageData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

      print('\n🔍 Processing message ${i + 1}/${messages.length}');
      print('📨 Sender: "$sender"');
      print('💬 Message: ${message.substring(0, message.length > 80 ? 80 : message.length)}...');

      final transaction = parseTransaction(message, sender, timestamp);

      if (transaction != null) {
        validTransactions.add(transaction);
        print('✅ Valid transaction found: ₹${transaction.amount} ${transaction.type.name}');
      } else {
        print('❌ Not a valid transaction');
      }
    }

    print('\n📊 Summary: Found ${validTransactions.length} valid transactions out of ${messages.length} messages');
    return validTransactions;
  }

  List<Transaction> parseTestNotifications() {
    final testMessages = [
      {
        'message': 'ICICI Bank Acct XX127 debited for Rs 1.00 on 23-Jul-25; ROHIT KUMAR SIN credited. UPI:065659993494. Call 18002662 for dispute. SMS BLOCK 127 to 9215676766.',
        'sender': 'ICICIB',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'message': 'Your a/c XX7238 is credited for INR 230.00 on 22-07-25 14:46:15 through UPI.Available Bal INR 4033.64 (UPI Ref ID 108522927578).Download PNB ONE-PNB',
        'sender': 'PNBSMS',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'message': 'A/c XX7238 debited INR 180.00 Dt 08-07-25 13:32:31 thru UPI:555521976490.Bal INR 3730.45 Not u?Fwd this SMS to 9264092640 to block UPI.Download PNB ONE-PNB',
        'sender': 'PNBSMS',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'message': 'Dear Customer, INR 9,883.79 credited to your A/c No XX1647 on 25/07/2025 through NEFT with UTR CITIN25598096738 by PAYPAL PAYMENTS PL-OPGSP COLL AC, INFO: BATCHID:0029 P0803L5TAPF7V9V4ZG       -DNTPP42 62E-SBI',
        'sender': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'message': 'Dear UPI user A/C X1647 debited by 4000.0 on date 23Jul25 trf to UMESH  PRASAD Refno 520426657880. If not u? call 1800111109. -SBI',
        'sender': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'message': 'Your A/C XXXXX4216 Credited INR 50,55000 on 04/07/25 -Deposit by transfer from REMITLY INC. Avl Bal INR 61,601.74-SBI',
        'sender': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      // ADDED: Your problematic transactions to test suite
      {
        'message': 'A/c XX7238 debited INR 140.00 Dt 08-07-25 13:32:31 thru UPI:555521976490.Bal INR 3730.45 Not u?Fwd this SMS to 9264092640 to block UPI.Download PNB ONE-PNB',
        'sender': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'message': 'Your a/c XX7238 is credited for INR 830.00  on 22-07-25 14:46:15 through UPI.Available Bal INR 4033.64 (UPI Ref ID 108522927578).Download PNB ONE-PNB',
        'sender': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'message': 'We have received your payment of INR 9,506.30 towards your credit card number ending 6231. Thank you (Cheque/ECS Payment subject to realisation)-StanChart',
        'sender': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'message': 'Sent Rs.1.00 from Kotak Bank AC X7353 to rohitsinghchandel420@okaxis on 25-07-25.UPI Ref 520604491926. Not you,',
        'sender': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    ];

    return parseMultipleMessages(testMessages);
  }

  Transaction? parseTransaction(String message, String sender, int timestamp) {
    try {
      final cleanMessage = _cleanMessage(message);

      if (!_isValidTransactionMessage(cleanMessage, sender)) {
        print('❌ Invalid transaction message - failed validation');
        return null;
      }

      final amount = _extractAmount(cleanMessage);
      if (amount == null || amount <= 0) {
        print('❌ Invalid amount: $amount');
        return null;
      }

      final type = _determineTransactionType(cleanMessage);
      if (type == null) {
        print('❌ Could not determine transaction type');
        return null;
      }

      final merchant = _extractMerchant(cleanMessage);
      final effectiveSender = sender.isEmpty ? _extractBankFromMessage(cleanMessage) : sender;
      final accountNumber = _extractAccountNumber(cleanMessage);
      final referenceNumber = _extractReferenceNumber(cleanMessage);
      final balance = _extractBalance(cleanMessage);
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

      print('✅ Transaction parsed successfully: ₹$amount ${type.name}');
      return transaction;

    } catch (e) {
      print('❌ Error parsing transaction: $e');
      return null;
    }
  }

  String _cleanMessage(String message) {
    return message.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isValidTransactionMessage(String message, String sender) {
    final lowerMsg = message.toLowerCase();
    final upperSender = sender.toUpperCase();

    print('🔍 Validating message...');
    print('   Sender: "$sender"');
    print('   Message length: ${message.length}');

    bool hasBasicKeywords = RegExp(r'\b(rs|rupees|₹|inr|debited|debit|credited|transaction|bank|card|account|upi|ac\s|a\/c|acct|payment|spent|alert|sent|neft|rtgs|imps)\b', caseSensitive: false).hasMatch(lowerMsg);
    print('   Has basic keywords: $hasBasicKeywords');

    if (!hasBasicKeywords) {
      print('❌ No basic transaction keywords found');
      return false;
    }

    bool isFromBank = sender.isNotEmpty && _bankSenders.any((bank) => upperSender.contains(bank));
    print('   Is from known bank sender: $isFromBank');

    bool isFromUPI = sender.isNotEmpty && _upiSenders.any((upi) => upperSender.contains(upi));
    print('   Is from UPI sender: $isFromUPI');

    bool isNumericSender = sender.isNotEmpty && RegExp(r'^\d{5,6}$').hasMatch(sender);
    print('   Is numeric sender: $isNumericSender');

    bool hasBankInMessage = _bankNamesInMessage.any((bank) => lowerMsg.contains(bank));
    print('   Has bank name in message: $hasBankInMessage');

    bool hasUpiRef = lowerMsg.contains('upi ref') || lowerMsg.contains('upi id') || lowerMsg.contains('@') || lowerMsg.contains('upi:');
    print('   Has UPI reference: $hasUpiRef');

    bool isPnbMessage = lowerMsg.contains('pnb one') || lowerMsg.contains('download pnb');
    print('   Is PNB message: $isPnbMessage');

    bool hasTransactionPattern = RegExp(r'\b(credited|debited|sent).*?(inr|rs)\s*[\d.,]+', caseSensitive: false).hasMatch(lowerMsg) ||
        RegExp(r'\b(neft|rtgs|imps).*?(credited|debited)', caseSensitive: false).hasMatch(lowerMsg) ||
        RegExp(r'(credited|debited).*?(neft|rtgs|imps)', caseSensitive: false).hasMatch(lowerMsg);
    print('   Has transaction pattern: $hasTransactionPattern');

    bool hasPaymentConfirmation = _hasPaymentConfirmation(lowerMsg);
    print('   Has payment confirmation: $hasPaymentConfirmation');

    bool hasCreditCard = _hasCreditCard(lowerMsg);
    print('   Has credit card reference: $hasCreditCard');

    bool hasNeftRtgs = lowerMsg.contains('neft') || lowerMsg.contains('rtgs') || lowerMsg.contains('imps');
    print('   Has NEFT/RTGS/IMPS: $hasNeftRtgs');

    bool hasUtrRef = lowerMsg.contains('utr') && RegExp(r'utr\s+[a-z0-9]+', caseSensitive: false).hasMatch(lowerMsg);
    print('   Has UTR reference: $hasUtrRef');

    bool validSender = isFromBank || isFromUPI || isNumericSender || hasBankInMessage || hasUpiRef || isPnbMessage || hasTransactionPattern || hasNeftRtgs;

    if (sender.isEmpty) {
      print('   📝 Empty sender detected - checking message content strength...');

      bool hasBankTransaction = (hasBankInMessage || hasUpiRef || isPnbMessage || hasTransactionPattern || hasNeftRtgs) &&
          (lowerMsg.contains('a/c') || lowerMsg.contains('acct') || lowerMsg.contains('account') ||
              lowerMsg.contains('ac ') || lowerMsg.contains('bank') ||
              lowerMsg.contains('dear customer') || lowerMsg.contains('credited to your') ||
              lowerMsg.contains('dear upi user') || lowerMsg.contains('your a/c'));

      bool hasPaymentTransaction = hasPaymentConfirmation &&
          (
              hasBankInMessage ||
                  isFromBank ||
                  isNumericSender ||
                  lowerMsg.contains('a/c') ||
                  lowerMsg.contains('acct') ||
                  lowerMsg.contains('account') ||
                  lowerMsg.contains('ac ') ||
                  hasNeftRtgs ||
                  hasUtrRef
          );

      bool hasCardTransaction = hasCreditCard &&
          (lowerMsg.contains('spent') || lowerMsg.contains('thank you') ||
              lowerMsg.contains('alert') || lowerMsg.contains('using'));

      bool hasNeftTransaction = hasNeftRtgs &&
          (lowerMsg.contains('credited') || lowerMsg.contains('debited')) &&
          (lowerMsg.contains('a/c') || lowerMsg.contains('account') || lowerMsg.contains('dear customer')) &&
          (hasUtrRef || lowerMsg.contains('by ') || lowerMsg.contains('from '));

      bool hasDirectBankTransaction = (lowerMsg.contains('credited inr') || lowerMsg.contains('debited inr')) &&
          (lowerMsg.contains('a/c') || lowerMsg.contains('account')) &&
          (lowerMsg.contains('deposit') || lowerMsg.contains('transfer') || lowerMsg.contains('from '));

      // ADDED: Kotak UPI specific validation
      bool hasKotakUpi = lowerMsg.contains('sent rs.') && lowerMsg.contains('kotak bank') && lowerMsg.contains('@');

      bool hasStrongIndicators = hasBankTransaction || hasPaymentTransaction || hasCardTransaction || hasNeftTransaction || hasDirectBankTransaction || hasKotakUpi;

      print('   - Bank transaction: $hasBankTransaction');
      print('   - Payment transaction: $hasPaymentTransaction');
      print('   - Card transaction: $hasCardTransaction');
      print('   - NEFT transaction: $hasNeftTransaction');
      print('   - Direct bank transaction: $hasDirectBankTransaction');
      print('   - Kotak UPI transaction: $hasKotakUpi');
      print('   Has strong indicators for empty sender: $hasStrongIndicators');

      validSender = hasStrongIndicators;
    }

    print('   Valid sender overall: $validSender');

    if (!validSender) {
      print('❌ Invalid sender/source');
      return false;
    }

    for (final pattern in _spamPatterns) {
      if (pattern.hasMatch(lowerMsg)) {
        bool isLegitimateBank = isFromBank || isNumericSender ||
            hasBankInMessage || hasUpiRef ||
            hasTransactionPattern || hasCreditCard ||
            hasNeftRtgs || hasUtrRef ||
            lowerMsg.contains('a/c') || lowerMsg.contains('acct') ||
            lowerMsg.contains('ac ') || lowerMsg.contains('sent rs') ||
            lowerMsg.contains('debited') || lowerMsg.contains('credited') ||
            lowerMsg.contains('dear customer') || lowerMsg.contains('dear upi user') ||
            lowerMsg.contains('your a/c');

        if (!isLegitimateBank) {
          print('❌ Detected as spam');
          return false;
        } else {
          print('⚠️ Spam pattern detected but overridden due to legitimate bank content');
        }
      }
    }

    print('✅ Message validation passed');
    return true;
  }

  bool _hasPaymentConfirmation(String message) {
    return _paymentConfirmationPatterns.any((pattern) => pattern.hasMatch(message));
  }

  bool _hasCreditCard(String message) {
    return _creditCardPatterns.any((pattern) => pattern.hasMatch(message));
  }

  double? _extractAmount(String message) {
    for (final pattern in _amountPatterns) {
      final matches = pattern.allMatches(message);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(amountStr);

        if (amount != null && amount > 0 && amount < 10000000) {
          return amount;
        }
      }
    }
    return null;
  }

  TransactionType? _determineTransactionType(String message) {
    final lowerMsg = message.toLowerCase();

    // Check for explicit "credited" patterns FIRST to avoid misclassification
    if (RegExp(r'\bcredited\b', caseSensitive: false).hasMatch(lowerMsg)) {
      print('🔍 Type Detection: Found "credited" keyword - returning CREDIT');
      return TransactionType.credit;
    }

    // Then check for debit patterns
    if (_debitPattern.hasMatch(lowerMsg)) {
      print('🔍 Type Detection: Found debit pattern - returning DEBIT');
      return TransactionType.debit;
    }

    // Check for other credit patterns
    if (_creditPattern.hasMatch(lowerMsg)) {
      print('🔍 Type Detection: Found credit pattern - returning CREDIT');
      return TransactionType.credit;
    }

    // Special case for payment confirmations
    if (_hasPaymentConfirmation(lowerMsg)) {
      print('🔍 Type Detection: Found payment confirmation - returning CREDIT');
      return TransactionType.credit;
    }

    print('🔍 Type Detection: No clear pattern found - returning NULL');
    return null;
  }

  // ENHANCED: Better merchant extraction for all your transaction types
  String _extractMerchant(String message) {
    // ADDED: Kotak UPI specific extraction - "to rohitsinghchandel420@okaxis"
    if (message.toLowerCase().contains('sent rs.') && message.contains('@')) {
      final upiMatch = RegExp(r'to\s+([^@\s]+@[^@\s]+)', caseSensitive: false).firstMatch(message);
      if (upiMatch != null) {
        return upiMatch.group(1)?.toUpperCase() ?? 'UPI Transfer';
      }
    }

    // ADDED: StanChart credit card payment
    if (message.toLowerCase().contains('stanchart') && message.toLowerCase().contains('credit card')) {
      return 'Credit Card Payment';
    }

    // Remitly specific extraction
    if (message.toLowerCase().contains('remitly')) {
      return 'REMITLY INC';
    }

    // UPI transfer merchant extraction for "trf to UMESH PRASAD"
    if (message.toLowerCase().contains('trf to')) {
      final merchantMatch = RegExp(r'trf\s+to\s+([A-Z\s]+?)(?:\s+Refno|\s+Ref|\s+UPI|$)', caseSensitive: false).firstMatch(message);
      if (merchantMatch != null) {
        String merchant = merchantMatch.group(1)?.trim() ?? '';
        if (merchant.length > 2 && merchant.length < 50) {
          return merchant.toUpperCase();
        }
      }
    }

    // Enhanced deposit/transfer extraction
    if (message.toLowerCase().contains('deposit') || message.toLowerCase().contains('transfer')) {
      final transferMatch = RegExp(r'(?:transfer|deposit)\s+(?:from|by)\s+([A-Z][A-Z\s&.]+?)(?:\.|$|Avl)', caseSensitive: false).firstMatch(message);
      if (transferMatch != null) {
        String merchant = transferMatch.group(1)?.trim() ?? '';
        if (merchant.length > 2 && merchant.length < 50) {
          return merchant.toUpperCase();
        }
      }
    }

    if (message.toLowerCase().contains('paypal')) {
      final paypalMatch = RegExp(r'by\s+(PAYPAL[^,]+)', caseSensitive: false).firstMatch(message);
      if (paypalMatch != null) {
        return paypalMatch.group(1)?.trim().toUpperCase() ?? 'PAYPAL';
      }
      return 'PAYPAL';
    }

    if (message.toLowerCase().contains('neft') || message.toLowerCase().contains('rtgs')) {
      final neftMatch = RegExp(r'by\s+([^,]+)', caseSensitive: false).firstMatch(message);
      if (neftMatch != null) {
        String merchant = neftMatch.group(1)?.trim() ?? '';
        if (merchant.length > 3 && merchant.length < 50) {
          return merchant.toUpperCase();
        }
      }
      return 'NEFT Transfer';
    }

    if (_hasCreditCard(message)) {
      final merchantPatterns = [
        RegExp(r'at\s+([A-Z][A-Z0-9\s]+?)(?:\s+on|\s+internet|\s*$)', caseSensitive: false),
        RegExp(r'spent\s+via.*?at\s+([A-Z][A-Z0-9\s]+)', caseSensitive: false),
      ];

      for (final pattern in merchantPatterns) {
        final match = pattern.firstMatch(message);
        if (match != null) {
          String merchant = match.group(1)?.trim() ?? '';
          if (merchant.length > 2) {
            return merchant.toUpperCase();
          }
        }
      }

      final cardMatch = RegExp(r'card\s+(?:number\s+|no\s+)?xx(\d+)', caseSensitive: false).firstMatch(message);
      if (cardMatch != null) {
        return 'Card Transaction - ${cardMatch.group(1)}';
      }

      return 'Card Transaction';
    }

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

    if (message.contains(';')) {
      final merchantMatch = RegExp(r';\s*([A-Z][A-Z\s]+)\s+credited', caseSensitive: false).firstMatch(message);
      if (merchantMatch != null) {
        return merchantMatch.group(1)?.trim().toUpperCase() ?? 'UPI Transfer';
      }
    }

    final patterns = [
      RegExp(r'(?:at|to|from)\s+([A-Z][A-Z0-9\s\-]{2,20})', caseSensitive: false),
      RegExp(r'([A-Z][A-Z0-9\s]{2,20})\s+(?:on|dated)', caseSensitive: false),
      RegExp(r'info:\s*upi-([^-]+)', caseSensitive: false),
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

    if (_hasPaymentConfirmation(message)) {
      return 'Payment Confirmation';
    }

    return 'Transfer';
  }

  String _extractBankFromMessage(String message) {
    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains('-sbi') || lowerMsg.endsWith('sbi')) {
      return 'SBI';
    }

    if (lowerMsg.contains('pnb one') || lowerMsg.contains('download pnb') || lowerMsg.contains('pnb')) {
      return 'PNB';
    }

    if (lowerMsg.contains('icici bank') || lowerMsg.contains('icici')) {
      return 'ICICI';
    }

    if (lowerMsg.contains('hdfc bank') || lowerMsg.contains('hdfc')) {
      return 'HDFC';
    }

    if (lowerMsg.contains('sbi bank') || lowerMsg.contains('sbi')) {
      return 'SBI';
    }

    if (lowerMsg.contains('stanchart') || lowerMsg.contains('standard chartered')) {
      return 'STANCHART';
    }

    // ADDED: Kotak bank detection
    if (lowerMsg.contains('kotak bank') || lowerMsg.contains('kotak')) {
      return 'KOTAK';
    }

    for (final bank in _bankNamesInMessage) {
      if (lowerMsg.contains(bank)) {
        return bank.toUpperCase().replaceAll(' BANK', '').replaceAll(' ', '_');
      }
    }

    if (_hasPaymentConfirmation(lowerMsg)) {
      if (_hasCreditCard(lowerMsg)) {
        return 'CREDIT_CARD';
      }
      return 'PAYMENT_SERVICE';
    }

    if (_hasCreditCard(lowerMsg)) {
      return 'CARD_SERVICE';
    }

    if (lowerMsg.contains('neft') || lowerMsg.contains('rtgs') || lowerMsg.contains('imps')) {
      return 'BANK_TRANSFER';
    }

    if (RegExp(r'a\/c\s+[x]+\d+', caseSensitive: false).hasMatch(lowerMsg)) {
      return 'BANK';
    }

    return 'UNKNOWN';
  }

  // ENHANCED: Better account number extraction for all formats
  String? _extractAccountNumber(String message) {
    final patterns = [
      // ADDED: Kotak specific pattern - "AC X7353"
      RegExp(r'AC\s+([Xx*]{1,}\d{3,4})', caseSensitive: false),

      // Enhanced patterns for SBI format "A/C XXXXX4216"
      RegExp(r'A\/C\s+([Xx*]{3,}\d{3,4})', caseSensitive: false),
      RegExp(r'A\/c\s+No\s+([Xx*]{2,}\d{3,4})', caseSensitive: false),
      RegExp(r'a\/c\s+([Xx*]{2,}\d{3,4})', caseSensitive: false),

      RegExp(r'Your\s+a\/c\s+([Xx*]{2,}\d{3,4})', caseSensitive: false),
      RegExp(r'Acct\s+([Xx*]{2,}\d{3,4})', caseSensitive: false),
      RegExp(r'Account\s+([Xx*]{2,}\d{3,4})', caseSensitive: false),

      RegExp(r'Bank\s+AC\s+([Xx*]{1,}\d{3,4})', caseSensitive: false),

      RegExp(r'A\/C\s*([Xx*]{2,}\s*\d{3,4})', caseSensitive: false),
      RegExp(r'AC\s*([Xx*]{2,}\s*\d{3,4})', caseSensitive: false),
      RegExp(r'account\s*([Xx*]{2,}\s*\d{3,4})', caseSensitive: false),

      RegExp(r'[Xx*]{6,}(\d{4})', caseSensitive: false),
      RegExp(r'[Xx*]{4,}(\d{3,4})', caseSensitive: false),

      // ADDED: Card number patterns - "ending 6231"
      RegExp(r'ending\s+(\d{4})', caseSensitive: false),
      RegExp(r'card\s+number\s+ending\s+(\d{4})', caseSensitive: false),
      RegExp(r'card\s+no\.?\s+[Xx*]{2,}(\d{4})', caseSensitive: false),
      RegExp(r'card\s+[Xx*]{2,}(\d{4})', caseSensitive: false),

      RegExp(r'([Xx*]{2,}\d{3,5})\b', caseSensitive: false),
      RegExp(r'(\*{2,}\d{3,5})\b', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        String accountNum = match.group(1) ?? '';

        accountNum = accountNum.replaceAll(RegExp(r'\s+'), '');

        if (accountNum.startsWith('XX') || accountNum.startsWith('xx')) {
          return accountNum.toUpperCase();
        } else if (accountNum.startsWith('X') || accountNum.startsWith('x')) {
          return accountNum.toUpperCase();
        } else if (accountNum.startsWith('*')) {
          return accountNum.replaceAll('*', 'X');
        } else if (RegExp(r'^\d{3,5}$').hasMatch(accountNum)) {
          return 'XXXX$accountNum';
        } else if (accountNum.length >= 3) {
          return accountNum.toUpperCase();
        }
      }
    }

    return null;
  }

  // ENHANCED: Better reference number extraction
  String? _extractReferenceNumber(String message) {
    final patterns = [
      // ADDED: Kotak UPI reference - "UPI Ref 520604491926"
      RegExp(r'UPI\s+Ref\s+(\d+)', caseSensitive: false),

      RegExp(r'Refno\s+(\d+)', caseSensitive: false),

      RegExp(r'UTR\s+([A-Z0-9]+)', caseSensitive: false),
      RegExp(r'with\s+UTR\s+([A-Z0-9]+)', caseSensitive: false),

      // ADDED: PNB variations
      RegExp(r'\(UPI\s+Ref\s+ID\s+(\d+)\)', caseSensitive: false),
      RegExp(r'UPI:(\d+)', caseSensitive: false),
      RegExp(r'UPI\s+Ref\s+ID\s+(\d+)', caseSensitive: false),
      RegExp(r'UPI\s*Ref\s*[:.]?\s*(\w+)', caseSensitive: false),
      RegExp(r'Ref\s*(?:No|#|:)?\s*(\w+)', caseSensitive: false),
      RegExp(r'TXN\s*(?:ID|#|:)?\s*(\w+)', caseSensitive: false),
      RegExp(r'Transaction\s*ID\s*[:.]?\s*(\w+)', caseSensitive: false),
      RegExp(r'thru\s+UPI:(\d+)', caseSensitive: false),
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
    final patterns = [
      // SBI format "Avl Bal INR 61,601.74"
      RegExp(r'Avl\s+Bal\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),

      RegExp(r'Available\s+Bal\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'\.Bal\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'Bal\s+INR\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'(?:balance|bal)\s*[:.]?\s*Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'(?:balance|bal)\s*[:.]?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'Avl\s+Bal:\s+Rs\s+([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'Available\s+Balance:\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
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
