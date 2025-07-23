class Constants {
  // App Info
  static const String appName = 'SmartPaisa';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String transactionsKey = 'transactions';
  static const String categoriesKey = 'categories';
  static const String budgetsKey = 'budgets';
  static const String settingsKey = 'settings';

  // Default Values
  static const int maxTransactionHistory = 1000;
  static const double defaultBudgetAmount = 10000.0;

  // SMS Parsing
  static const int smsProcessingDelay = 2000; // milliseconds
  static const int maxSmsLength = 500;

  // UI Constants
  static const double cardElevation = 2.0;
  static const double borderRadius = 12.0;
  static const int animationDuration = 300; // milliseconds
}
