import 'dart:convert';

/// Categorises a transaction as either money **debited** from
/// the user’s account/wallet or **credited** to it.
enum TransactionType { debit, credit }

/// Immutable data-model that represents a single financial transaction
/// detected from an SMS or push-notification.
///
/// The class:
/// • is null-safe
/// • supports deep copy (`copyWith`)
/// • can be serialised to/from Map ⇄ JSON
/// • overrides `==`/`hashCode` for fast list diffs & deduplication
class Transaction {
  final String id;                    // 16-char SHA-1 digest
  final double amount;                // Positive amount only
  final TransactionType type;         // debit | credit
  final String merchant;              // Parsed vendor (UPS, AMAZON, …)
  final String sender;                // Original SMS “address”
  final DateTime dateTime;            // Local device time
  final String originalMessage;       // Raw SMS content

  // Optional parsed fields
  final String? accountNumber;        // Masked or last-4 digits
  final String? referenceNumber;      // UTR / RRN / Txn-Id
  final double? balance;              // Post-txn balance if present

  // User metadata
  final String category;              // Category-id (default: “Uncategorized”)
  final String? note;                 // Optional user note
  final List<String> tags;            // Free-form tags/labels
  final bool isCategorized;           // Whether user confirmed category

  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.sender,
    required this.dateTime,
    required this.originalMessage,
    this.accountNumber,
    this.referenceNumber,
    this.balance,
    this.category = 'Uncategorized',
    this.note,
    this.tags = const [],
    this.isCategorized = false,
  });

  /* ----------------------- utility helpers ----------------------- */

  /// Returns **true** when `type == TransactionType.debit`.
  bool get isDebit => type == TransactionType.debit;

  /// Returns **true** when `type == TransactionType.credit`.
  bool get isCredit => type == TransactionType.credit;

  /// Copy-constructor with selective overrides (immutability friendly).
  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? merchant,
    String? sender,
    DateTime? dateTime,
    String? originalMessage,
    String? accountNumber,
    String? referenceNumber,
    double? balance,
    String? category,
    String? note,
    List<String>? tags,
    bool? isCategorized,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      sender: sender ?? this.sender,
      dateTime: dateTime ?? this.dateTime,
      originalMessage: originalMessage ?? this.originalMessage,
      accountNumber: accountNumber ?? this.accountNumber,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      balance: balance ?? this.balance,
      category: category ?? this.category,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      isCategorized: isCategorized ?? this.isCategorized,
    );
  }

  /* --------------------------- JSON ------------------------------ */

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'type': type.index,
    'merchant': merchant,
    'sender': sender,
    'dateTime': dateTime.millisecondsSinceEpoch,
    'originalMessage': originalMessage,
    'accountNumber': accountNumber,
    'referenceNumber': referenceNumber,
    'balance': balance,
    'category': category,
    'note': note,
    'tags': tags,
    'isCategorized': isCategorized,
  };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id'] as String? ?? '',
    amount: (map['amount'] as num? ?? 0).toDouble(),
    type: TransactionType.values[map['type'] as int? ?? 0],
    merchant: map['merchant'] as String? ?? '',
    sender: map['sender'] as String? ?? '',
    dateTime: DateTime.fromMillisecondsSinceEpoch(
        map['dateTime'] as int? ?? 0),
    originalMessage: map['originalMessage'] as String? ?? '',
    accountNumber: map['accountNumber'] as String?,
    referenceNumber: map['referenceNumber'] as String?,
    balance:
    (map['balance'] as num?)?.toDouble(), // null-safe conversion
    category: map['category'] as String? ?? 'Uncategorized',
    note: map['note'] as String?,
    tags: List<String>.from(map['tags'] as List? ?? const []),
    isCategorized: map['isCategorized'] as bool? ?? false,
  );

  String toJson() => jsonEncode(toMap());

  factory Transaction.fromJson(String source) =>
      Transaction.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /* -------------------- equality & hashing ----------------------- */

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Transaction &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Transaction($id, ₹$amount, $type, ${merchant.isEmpty ? 'N/A' : merchant})';
}
