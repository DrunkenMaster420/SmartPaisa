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

    // 1. learned mapping
    final learned = await _getLearnedCategory(txn.merchant);
    if (learned != null) {
      return cats.firstWhere((c) => c.id == learned, orElse: () => cats.first);
    }

    // 2. rule-based guess
    final rule = _ruleBased(txn, cats);
    return rule ?? (cats.isNotEmpty ? cats.first : null);
  }

  Future<void> learnFromUserChoice(String merchant, String categoryId) async {
    final raw = _storage.getSetting<String>(_learningKey, '{}') as String;
    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw);
    } catch (_) {
      map = {};
    }
    map[merchant.toLowerCase()] = categoryId;
    await _storage.saveSetting(_learningKey, jsonEncode(map));
  }

  Future<void> clearLearning() async =>
      _storage.saveSetting(_learningKey, '{}');

  // ---------- Internal ----------
  Future<String?> _getLearnedCategory(String merchant) async {
    final raw = _storage.getSetting<String>(_learningKey, '{}') as String;
    try {
      final map = jsonDecode(raw);
      return (map[merchant.toLowerCase()] as String?) ?? null;
    } catch (_) {
      return null;
    }
  }

  Category? _ruleBased(Transaction t, List<Category> cats) {
    final m = t.merchant.toLowerCase();
    final msg = t.originalMessage.toLowerCase();

    bool has(List<String> keys) =>
        keys.any((k) => m.contains(k) || msg.contains(k));

    Category? byId(String id) =>
        cats.firstWhere((c) => c.id == id, orElse: () => Category(
          id: id,
          name: id,
          icon: Icons.category,
          color: Colors.grey,
        ));

    if (has(['zomato', 'swiggy', 'food', 'restaurant'])) return byId('food');
    if (has(['uber', 'ola', 'taxi', 'fuel', 'petrol'])) return byId('transport');
    if (has(['amazon', 'flipkart', 'myntra', 'shopping'])) return byId('shopping');
    if (has(['netflix', 'hotstar', 'prime', 'movie'])) return byId('entertainment');
    if (has(['electricity', 'recharge', 'bill', 'gas'])) return byId('utilities');
    if (has(['hospital', 'clinic', 'pharmacy'])) return byId('healthcare');
    if (has(['school', 'college', 'course', 'tuition'])) return byId('education');
    if (t.type == TransactionType.credit && has(['salary', 'sal', 'credited'])) {
      return byId('salary');
    }
    return null;
  }
}
