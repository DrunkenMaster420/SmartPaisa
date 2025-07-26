// lib/services/category_service.dart
import 'dart:convert';
import '../ models/category.dart';
import '../ models/transaction.dart';
import 'storage_service.dart';
import 'package:flutter/material.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final _storage = StorageService.instance;
  static const _learningKey = 'merchant_category_learning';

  // ---------- Public API ----------
  Future<Category?> suggestCategory(Transaction txn) async {
    final cats = await _storage.getCategories();
    if (cats.isEmpty) return null;

    // 1. Check learned mapping first
    final learned = await _getLearnedCategory(txn.merchant);
    if (learned != null) {
      final category = cats.firstWhere(
            (c) => c.id == learned,
        orElse: () => cats.first,
      );
      print('📚 Using learned category for ${txn.merchant}: ${category.name}');
      return category;
    }

    // 2. Try rule-based categorization
    final rule = _ruleBased(txn, cats);
    if (rule != null) {
      print('🤖 Rule-based category for ${txn.merchant}: ${rule.name}');
      return rule;
    }

    // 3. Default fallback to first category
    print('❓ Using default category for ${txn.merchant}');
    return cats.first;
  }

  Future<void> learnFromUserChoice(String merchant, String categoryId) async {
    try {
      final raw = _storage.getSetting<String>(_learningKey, '{}');
      Map<String, dynamic> map;

      try {
        map = jsonDecode(raw);
      } catch (_) {
        map = {};
      }

      map[merchant.toLowerCase().trim()] = categoryId;
      await _storage.saveSetting(_learningKey, jsonEncode(map));

      print('🎓 Learned: ${merchant.toLowerCase().trim()} -> $categoryId');
    } catch (e) {
      print('❌ Error learning from user choice: $e');
    }
  }

  Future<void> clearLearning() async {
    try {
      await _storage.saveSetting(_learningKey, '{}');
      print('🧹 Cleared all learning data');
    } catch (e) {
      print('❌ Error clearing learning data: $e');
    }
  }

  Future<void> clearCategoryLearning(String categoryId) async {
    try {
      final raw = _storage.getSetting<String>(_learningKey, '{}');
      Map<String, dynamic> map;

      try {
        map = jsonDecode(raw);
      } catch (_) {
        return; // Nothing to clear
      }

      // Remove all entries that point to this category
      map.removeWhere((key, value) => value == categoryId);

      await _storage.saveSetting(_learningKey, jsonEncode(map));
      print('🧹 Cleared learning data for category: $categoryId');
    } catch (e) {
      print('❌ Error clearing category learning: $e');
    }
  }

  Future<Map<String, String>> getAllLearnings() async {
    try {
      final raw = _storage.getSetting<String>(_learningKey, '{}');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.cast<String, String>();
    } catch (e) {
      print('❌ Error getting all learnings: $e');
      return {};
    }
  }

  Future<int> getLearningCount() async {
    try {
      final learnings = await getAllLearnings();
      return learnings.length;
    } catch (e) {
      return 0;
    }
  }

  // ---------- Internal Methods ----------
  Future<String?> _getLearnedCategory(String merchant) async {
    try {
      final raw = _storage.getSetting<String>(_learningKey, '{}');
      final map = jsonDecode(raw) as Map<String, dynamic>;

      final normalizedMerchant = merchant.toLowerCase().trim();
      return map[normalizedMerchant] as String?;
    } catch (e) {
      print('❌ Error getting learned category: $e');
      return null;
    }
  }

  Category? _ruleBased(Transaction t, List<Category> cats) {
    final m = t.merchant.toLowerCase().trim();
    final msg = t.originalMessage.toLowerCase();

    bool hasKeyword(List<String> keywords) =>
        keywords.any((k) => m.contains(k) || msg.contains(k));

    Category? findById(String id) =>
        cats.firstWhere((c) => c.id == id, orElse: () => cats.first);

    // Enhanced rule-based categorization
    try {
      // Food & Dining
      if (hasKeyword([
        'zomato', 'swiggy', 'uber eats', 'dominos', 'pizza', 'mcdonald',
        'kfc', 'food', 'restaurant', 'cafe', 'dining', 'delivery', 'meal'
      ])) {
        return findById('food');
      }

      // Transportation
      if (hasKeyword([
        'uber', 'ola', 'taxi', 'cab', 'fuel', 'petrol', 'diesel', 'gas',
        'metro', 'bus', 'train', 'flight', 'airline', 'booking'
      ])) {
        return findById('transport');
      }

      // Shopping
      if (hasKeyword([
        'amazon', 'flipkart', 'myntra', 'ajio', 'shopping', 'mall',
        'store', 'market', 'purchase', 'buy', 'shop'
      ])) {
        return findById('shopping');
      }

      // Entertainment
      if (hasKeyword([
        'netflix', 'hotstar', 'prime', 'spotify', 'youtube', 'movie',
        'cinema', 'theater', 'entertainment', 'gaming', 'music'
      ])) {
        return findById('entertainment');
      }

      // Utilities & Bills
      if (hasKeyword([
        'electricity', 'water', 'gas', 'internet', 'mobile', 'phone',
        'recharge', 'bill', 'utility', 'bsnl', 'airtel', 'jio', 'vi'
      ])) {
        return findById('utilities');
      }

      // Healthcare
      if (hasKeyword([
        'hospital', 'clinic', 'doctor', 'pharmacy', 'medicine', 'medical',
        'health', 'apollo', 'fortis', 'care', 'diagnostic'
      ])) {
        return findById('healthcare');
      }

      // Education
      if (hasKeyword([
        'school', 'college', 'university', 'course', 'tuition', 'fees',
        'education', 'learning', 'training', 'institute'
      ])) {
        return findById('education');
      }

      // Income/Salary (for credit transactions)
      if (t.type == TransactionType.credit && hasKeyword([
        'salary', 'sal', 'wage', 'income', 'credited', 'deposit', 'payment'
      ])) {
        return findById('salary');
      }

      // Groceries
      if (hasKeyword([
        'grocery', 'mart', 'supermarket', 'vegetables', 'fruits',
        'reliance', 'big bazaar', 'dmart', 'spencer'
      ])) {
        return findById('groceries');
      }

      // Banking/Finance
      if (hasKeyword([
        'bank', 'atm', 'transfer', 'loan', 'emi', 'interest',
        'finance', 'investment', 'insurance'
      ])) {
        return findById('finance');
      }

    } catch (e) {
      print('❌ Error in rule-based categorization: $e');
    }

    return null; // No rule matched
  }

  // Utility method to get category statistics
  Future<Map<String, dynamic>> getCategoryStats() async {
    try {
      final transactions = await _storage.getTransactions();
      final categories = await _storage.getCategories();
      final learnings = await getAllLearnings();

      final stats = <String, dynamic>{};

      for (final category in categories) {
        final categoryTransactions = transactions
            .where((t) => t.category == category.id)
            .toList();

        stats[category.id] = {
          'name': category.name,
          'transactionCount': categoryTransactions.length,
          'totalAmount': categoryTransactions.fold<double>(
              0, (sum, t) => sum + t.amount),
          'isDefault': category.isDefault,
        };
      }

      stats['_meta'] = {
        'totalCategories': categories.length,
        'totalLearnings': learnings.length,
        'defaultCategories': categories.where((c) => c.isDefault).length,
        'customCategories': categories.where((c) => !c.isDefault).length,
      };

      return stats;
    } catch (e) {
      print('❌ Error getting category stats: $e');
      return {};
    }
  }

  // Method to suggest category name based on merchant patterns
  String suggestCategoryName(String merchant) {
    final m = merchant.toLowerCase().trim();

    if (m.contains('food') || m.contains('restaurant')) return 'Food & Dining';
    if (m.contains('fuel') || m.contains('petrol')) return 'Transportation';
    if (m.contains('shopping') || m.contains('store')) return 'Shopping';
    if (m.contains('movie') || m.contains('entertainment')) return 'Entertainment';
    if (m.contains('bill') || m.contains('utility')) return 'Bills & Utilities';
    if (m.contains('health') || m.contains('medical')) return 'Healthcare';
    if (m.contains('education') || m.contains('school')) return 'Education';
    if (m.contains('grocery') || m.contains('mart')) return 'Groceries';

    return 'Miscellaneous';
  }
}
