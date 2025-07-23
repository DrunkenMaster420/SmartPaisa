import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../ models/transaction.dart';
import '../ models/category.dart';
import '../ models/budget.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  static StorageService get instance => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _initializeDefaultCategories();
  }

  // Transaction Storage
  Future<void> saveTransaction(Transaction transaction) async {
    final transactions = await getTransactions();
    transactions.removeWhere((t) => t.id == transaction.id);
    transactions.add(transaction);

    final jsonList = transactions.map((t) => t.toMap()).toList();
    await _prefs?.setString('transactions', json.encode(jsonList));
  }

  Future<List<Transaction>> getTransactions() async {
    final jsonString = _prefs?.getString('transactions') ?? '[]';
    final jsonList = json.decode(jsonString) as List;
    return jsonList.map((json) => Transaction.fromMap(json)).toList();
  }

  Future<void> deleteTransaction(String id) async {
    final transactions = await getTransactions();
    transactions.removeWhere((t) => t.id == id);

    final jsonList = transactions.map((t) => t.toMap()).toList();
    await _prefs?.setString('transactions', json.encode(jsonList));
  }

  // Category Storage
  Future<void> saveCategory(Category category) async {
    final categories = await getCategories();
    categories.removeWhere((c) => c.id == category.id);
    categories.add(category);

    final jsonList = categories.map((c) => c.toMap()).toList();
    await _prefs?.setString('categories', json.encode(jsonList));
  }

  Future<List<Category>> getCategories() async {
    final jsonString = _prefs?.getString('categories') ?? '[]';
    final jsonList = json.decode(jsonString) as List;
    return jsonList.map((json) => Category.fromMap(json)).toList();
  }

  Future<void> _initializeDefaultCategories() async {
    final categories = await getCategories();
    if (categories.isEmpty) {
      for (final category in DefaultCategories.defaults) {
        await saveCategory(category);
      }
    }
  }

  // Budget Storage
  Future<void> saveBudget(Budget budget) async {
    final budgets = await getBudgets();
    budgets.removeWhere((b) => b.id == budget.id);
    budgets.add(budget);

    final jsonList = budgets.map((b) => b.toMap()).toList();
    await _prefs?.setString('budgets', json.encode(jsonList));
  }

  Future<List<Budget>> getBudgets() async {
    final jsonString = _prefs?.getString('budgets') ?? '[]';
    final jsonList = json.decode(jsonString) as List;
    return jsonList.map((json) => Budget.fromMap(json)).toList();
  }

  // App Settings
  Future<void> saveSetting(String key, dynamic value) async {
    if (value is bool) {
      await _prefs?.setBool(key, value);
    } else if (value is int) {
      await _prefs?.setInt(key, value);
    } else if (value is double) {
      await _prefs?.setDouble(key, value);
    } else if (value is String) {
      await _prefs?.setString(key, value);
    }
  }

  T getSetting<T>(String key, T defaultValue) {
    try {
      if (T == bool) {
        return (_prefs?.getBool(key) ?? defaultValue) as T;
      } else if (T == int) {
        return (_prefs?.getInt(key) ?? defaultValue) as T;
      } else if (T == double) {
        return (_prefs?.getDouble(key) ?? defaultValue) as T;
      } else if (T == String) {
        final value = _prefs?.getString(key);
        // Ensure we return a non-null string
        return (value ?? defaultValue) as T;
      }
      return defaultValue;
    } catch (e) {
      print('❌ Error getting setting $key: $e');
      return defaultValue;
    }
  }

  // Add this method to your existing StorageService class

  Future<DateTime?> getAppFirstUseDate() async {
    final savedDate = getSetting<String>('app_first_use_date', '');
    if (savedDate.isEmpty) return null;

    try {
      return DateTime.parse(savedDate);
    } catch (e) {
      return null;
    }
  }

  Future<List<Transaction>> getTransactionsFromAppStart() async {
    final allTransactions = await getTransactions();
    final appFirstUseDate = await getAppFirstUseDate();

    if (appFirstUseDate == null) return allTransactions;

    return allTransactions.where((transaction) =>
    transaction.dateTime.isAfter(appFirstUseDate) ||
        transaction.dateTime.isAtSameMomentAs(appFirstUseDate)
    ).toList();
  }



  // Clear all data
  Future<void> clearAllData() async {
    await _prefs?.clear();
    await _initializeDefaultCategories();
  }
}
