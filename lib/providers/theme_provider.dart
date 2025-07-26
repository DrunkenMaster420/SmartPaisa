import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;
  ThemeData get lightTheme => _buildLightTheme();
  ThemeData get darkTheme => _buildDarkTheme();
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  Future<void> loadTheme() async {
    _isDarkMode = _storage.getSetting('enable_dark_mode', true);
    print('🎨 Theme loaded: ${_isDarkMode ? 'Dark' : 'Light'} mode');
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storage.saveSetting('enable_dark_mode', _isDarkMode);
    print('🔄 Theme toggled to: ${_isDarkMode ? 'Dark' : 'Light'} mode');

    // Update system UI overlay style
    _updateSystemUIOverlay();

    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      await _storage.saveSetting('enable_dark_mode', _isDarkMode);
      print('🎯 Theme set to: ${_isDarkMode ? 'Dark' : 'Light'} mode');

      // Update system UI overlay style
      _updateSystemUIOverlay();

      notifyListeners();
    }
  }

  void _updateSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      _isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.teal,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card Theme
      cardTheme: const CardThemeData(
        elevation: 2,
        color: Colors.white,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Colors.black54,
        ),
      ),

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF667EEA),
        secondary: Color(0xFF4ECDC4),
        surface: Colors.white,
        background: Color(0xFFF8FAFC),
        error: Color(0xFFFF4757),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        onBackground: Colors.black87,
        onError: Colors.white,
      ),

      // Other theme properties
      dividerColor: Colors.grey.shade300,
      iconTheme: const IconThemeData(color: Colors.black54),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.teal,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0A0E1A),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1F2E),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card Theme
      cardTheme: const CardThemeData(
        elevation: 4,
        color: Color(0xFF1A1F2E),
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF667EEA),
        secondary: Color(0xFF4ECDC4),
        surface: Color(0xFF1A1F2E),
        background: Color(0xFF0A0E1A),
        error: Color(0xFFFF4757),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),

      // Other theme properties
      dividerColor: Colors.white24,
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }
}
