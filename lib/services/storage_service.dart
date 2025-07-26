// lib/services/storage_service.dart
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
    try {
      _prefs = await SharedPreferences.getInstance();
      await _initializeDefaultCategories();
      await _setAppFirstUseDate();
      print('✅ StorageService initialized successfully');
    } catch (e) {
      print('❌ Error initializing StorageService: $e');
      throw Exception('Failed to initialize storage service');
    }
  }

  Future<void> _setAppFirstUseDate() async {
    try {
      final existingDate = getSetting<String>('app_first_use_date', '');
      if (existingDate.isEmpty) {
        await saveSetting('app_first_use_date', DateTime.now().toIso8601String());
        print('📅 App first use date set: ${DateTime.now()}');
      }
    } catch (e) {
      print('❌ Error setting app first use date: $e');
    }
  }

  // ---------- Transaction Storage ----------
  Future<void> saveTransaction(Transaction transaction) async {
    try {
      final transactions = await getTransactions();
      transactions.removeWhere((t) => t.id == transaction.id);
      transactions.add(transaction);

      // Sort by date (newest first)
      transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      final jsonList = transactions.map((t) => t.toMap()).toList();
      await _prefs?.setString('transactions', json.encode(jsonList));

      print('✅ Transaction saved: ${transaction.merchant} - ₹${transaction.amount}');
    } catch (e) {
      print('❌ Error saving transaction: $e');
      throw Exception('Failed to save transaction');
    }
  }

  Future<List<Transaction>> getTransactions() async {
    try {
      final jsonString = _prefs?.getString('transactions') ?? '[]';
      final jsonList = json.decode(jsonString) as List;
      final transactions = jsonList.map((json) => Transaction.fromMap(json)).toList();

      // Ensure sorted by date (newest first)
      transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      return transactions;
    } catch (e) {
      print('❌ Error getting transactions: $e');
      return [];
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      final transactions = await getTransactions();
      final initialCount = transactions.length;

      transactions.removeWhere((t) => t.id == id);

      if (transactions.length < initialCount) {
        final jsonList = transactions.map((t) => t.toMap()).toList();
        await _prefs?.setString('transactions', json.encode(jsonList));
        print('✅ Transaction deleted: $id');
      } else {
        print('⚠️ Transaction not found for deletion: $id');
      }
    } catch (e) {
      print('❌ Error deleting transaction: $e');
      throw Exception('Failed to delete transaction');
    }
  }

  Future<List<Transaction>> getTransactionsByCategory(String categoryId) async {
    try {
      final allTransactions = await getTransactions();
      return allTransactions.where((t) => t.category == categoryId).toList();
    } catch (e) {
      print('❌ Error getting transactions by category: $e');
      return [];
    }
  }

  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    try {
      final allTransactions = await getTransactions();
      return allTransactions.where((t) =>
      t.dateTime.isAfter(startDate) && t.dateTime.isBefore(endDate)
      ).toList();
    } catch (e) {
      print('❌ Error getting transactions by date range: $e');
      return [];
    }
  }

  // ---------- Category Storage ----------
  Future<void> saveCategory(Category category) async {
    try {
      final categories = await getCategories();
      categories.removeWhere((c) => c.id == category.id);
      categories.add(category);

      // Sort categories (default first, then alphabetically)
      categories.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return a.name.compareTo(b.name);
      });

      final jsonList = categories.map((c) => c.toMap()).toList();
      await _prefs?.setString('categories', json.encode(jsonList));

      print('✅ Category saved: ${category.name}');
    } catch (e) {
      print('❌ Error saving category: $e');
      throw Exception('Failed to save category');
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final jsonString = _prefs?.getString('categories') ?? '[]';
      final jsonList = json.decode(jsonString) as List;
      final categories = jsonList.map((json) => Category.fromMap(json)).toList();

      // Ensure sorted (default first, then alphabetically)
      categories.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return a.name.compareTo(b.name);
      });

      return categories;
    } catch (e) {
      print('❌ Error getting categories: $e');
      return [];
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      final categories = await getCategories();
      final initialCount = categories.length;

      // Don't allow deletion of default categories
      final categoryToDelete = categories.firstWhere(
            (c) => c.id == categoryId,
        orElse: () => throw Exception('Category not found'),
      );

      if (categoryToDelete.isDefault) {
        throw Exception('Cannot delete default category');
      }

      categories.removeWhere((category) => category.id == categoryId);

      if (categories.length < initialCount) {
        final jsonList = categories.map((c) => c.toMap()).toList();
        await _prefs?.setString('categories', json.encode(jsonList));

        // Update all transactions that use this category to uncategorized
        await _uncategorizeTransactions(categoryId);

        print('✅ Category deleted: $categoryId');
      } else {
        print('⚠️ Category not found for deletion: $categoryId');
      }
    } catch (e) {
      print('❌ Error deleting category: $e');
      throw Exception('Failed to delete category: $e');
    }
  }

  Future<void> _uncategorizeTransactions(String categoryId) async {
    try {
      final transactions = await getTransactions();
      bool hasChanges = false;

      for (int i = 0; i < transactions.length; i++) {
        if (transactions[i].category == categoryId) {
          transactions[i] = transactions[i].copyWith(
            category: 'uncategorized',
            isCategorized: false,
          );
          hasChanges = true;
        }
      }

      if (hasChanges) {
        final jsonList = transactions.map((t) => t.toMap()).toList();
        await _prefs?.setString('transactions', json.encode(jsonList));
        print('✅ Uncategorized transactions for deleted category: $categoryId');
      }
    } catch (e) {
      print('❌ Error uncategorizing transactions: $e');
    }
  }

  Future<void> _initializeDefaultCategories() async {
    try {
      final categories = await getCategories();
      if (categories.isEmpty) {
        for (final category in DefaultCategories.defaults) {
          await saveCategory(category);
        }
        print('✅ Default categories initialized');
      }
    } catch (e) {
      print('❌ Error initializing default categories: $e');
    }
  }

  // ---------- Budget Storage ----------
  Future<void> saveBudget(Budget budget) async {
    try {
      final budgets = await getBudgets();
      budgets.removeWhere((b) => b.id == budget.id);
      budgets.add(budget);

      final jsonList = budgets.map((b) => b.toMap()).toList();
      await _prefs?.setString('budgets', json.encode(jsonList));

      print('✅ Budget saved: ${budget.id}');
    } catch (e) {
      print('❌ Error saving budget: $e');
      throw Exception('Failed to save budget');
    }
  }

  Future<List<Budget>> getBudgets() async {
    try {
      final jsonString = _prefs?.getString('budgets') ?? '[]';
      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => Budget.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error getting budgets: $e');
      return [];
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      final budgets = await getBudgets();
      budgets.removeWhere((b) => b.id == budgetId);

      final jsonList = budgets.map((b) => b.toMap()).toList();
      await _prefs?.setString('budgets', json.encode(jsonList));

      print('✅ Budget deleted: $budgetId');
    } catch (e) {
      print('❌ Error deleting budget: $e');
      throw Exception('Failed to delete budget');
    }
  }

  // ---------- App Settings ----------
  Future<void> saveSetting(String key, dynamic value) async {
    try {
      if (value is bool) {
        await _prefs?.setBool(key, value);
      } else if (value is int) {
        await _prefs?.setInt(key, value);
      } else if (value is double) {
        await _prefs?.setDouble(key, value);
      } else if (value is String) {
        await _prefs?.setString(key, value);
      } else {
        throw Exception('Unsupported setting type: ${value.runtimeType}');
      }
      print('✅ Setting saved: $key');
    } catch (e) {
      print('❌ Error saving setting $key: $e');
      throw Exception('Failed to save setting');
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
        return (value ?? defaultValue) as T;
      }
      return defaultValue;
    } catch (e) {
      print('❌ Error getting setting $key: $e');
      return defaultValue;
    }
  }

  Future<void> deleteSetting(String key) async {
    try {
      await _prefs?.remove(key);
      print('✅ Setting deleted: $key');
    } catch (e) {
      print('❌ Error deleting setting $key: $e');
    }
  }

  // ---------- App Data Management ----------
  Future<DateTime?> getAppFirstUseDate() async {
    try {
      final savedDate = getSetting<String>('app_first_use_date', '');
      if (savedDate.isEmpty) return null;
      return DateTime.parse(savedDate);
    } catch (e) {
      print('❌ Error getting app first use date: $e');
      return null;
    }
  }

  Future<List<Transaction>> getTransactionsFromAppStart() async {
    try {
      final allTransactions = await getTransactions();
      final appFirstUseDate = await getAppFirstUseDate();

      if (appFirstUseDate == null) return allTransactions;

      return allTransactions.where((transaction) =>
      transaction.dateTime.isAfter(appFirstUseDate) ||
          transaction.dateTime.isAtSameMomentAs(appFirstUseDate)
      ).toList();
    } catch (e) {
      print('❌ Error getting transactions from app start: $e');
      return [];
    }
  }

  // ---------- Data Statistics ----------
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final transactions = await getTransactions();
      final categories = await getCategories();
      final budgets = await getBudgets();

      return {
        'transactions': {
          'total': transactions.length,
          'categorized': transactions.where((t) => t.isCategorized).length,
          'uncategorized': transactions.where((t) => !t.isCategorized).length,
          'credits': transactions.where((t) => t.type == TransactionType.credit).length,
          'debits': transactions.where((t) => t.type == TransactionType.debit).length,
        },
        'categories': {
          'total': categories.length,
          'default': categories.where((c) => c.isDefault).length,
          'custom': categories.where((c) => !c.isDefault).length,
        },
        'budgets': {
          'total': budgets.length,
        },
        'storage': {
          'version': '1.0',
          'lastUpdate': DateTime.now().toIso8601String(),
        }
      };
    } catch (e) {
      print('❌ Error getting storage stats: $e');
      return {};
    }
  }

  // ---------- Data Management ----------
  Future<void> clearAllData() async {
    try {
      await _prefs?.clear();
      await _initializeDefaultCategories();
      await _setAppFirstUseDate();
      print('✅ All data cleared and reinitialized');
    } catch (e) {
      print('❌ Error clearing all data: $e');
      throw Exception('Failed to clear data');
    }
  }

  Future<void> clearTransactions() async {
    try {
      await _prefs?.setString('transactions', '[]');
      print('✅ All transactions cleared');
    } catch (e) {
      print('❌ Error clearing transactions: $e');
      throw Exception('Failed to clear transactions');
    }
  }

  Future<void> clearCustomCategories() async {
    try {
      final categories = await getCategories();
      final defaultCategories = categories.where((c) => c.isDefault).toList();

      final jsonList = defaultCategories.map((c) => c.toMap()).toList();
      await _prefs?.setString('categories', json.encode(jsonList));

      print('✅ Custom categories cleared');
    } catch (e) {
      print('❌ Error clearing custom categories: $e');
      throw Exception('Failed to clear custom categories');
    }
  }

  // ---------- Backup & Restore ----------
  Future<Map<String, dynamic>> exportData() async {
    try {
      final transactions = await getTransactions();
      final categories = await getCategories();
      final budgets = await getBudgets();

      return {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'data': {
          'transactions': transactions.map((t) => t.toMap()).toList(),
          'categories': categories.map((c) => c.toMap()).toList(),
          'budgets': budgets.map((b) => b.toMap()).toList(),
        }
      };
    } catch (e) {
      print('❌ Error exporting data: $e');
      throw Exception('Failed to export data');
    }
  }

  Future<void> importData(Map<String, dynamic> data) async {
    try {
      if (data['version'] != '1.0') {
        throw Exception('Unsupported data version');
      }

      final importData = data['data'] as Map<String, dynamic>;

      // Import transactions
      if (importData.containsKey('transactions')) {
        final transactionMaps = importData['transactions'] as List;
        final transactions = transactionMaps
            .map((json) => Transaction.fromMap(json))
            .toList();

        final jsonList = transactions.map((t) => t.toMap()).toList();
        await _prefs?.setString('transactions', json.encode(jsonList));
      }

      // Import categories
      if (importData.containsKey('categories')) {
        final categoryMaps = importData['categories'] as List;
        final categories = categoryMaps
            .map((json) => Category.fromMap(json))
            .toList();

        final jsonList = categories.map((c) => c.toMap()).toList();
        await _prefs?.setString('categories', json.encode(jsonList));
      }

      // Import budgets
      if (importData.containsKey('budgets')) {
        final budgetMaps = importData['budgets'] as List;
        final budgets = budgetMaps
            .map((json) => Budget.fromMap(json))
            .toList();

        final jsonList = budgets.map((b) => b.toMap()).toList();
        await _prefs?.setString('budgets', json.encode(jsonList));
      }

      print('✅ Data imported successfully');
    } catch (e) {
      print('❌ Error importing data: $e');
      throw Exception('Failed to import data: $e');
    }
  }
}
