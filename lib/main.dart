import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/haptic_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services with proper error handling
  try {
    print('🚀 Initializing SmartPaisa App...');
    await StorageService.instance.init();
    print('✅ StorageService initialized');

    await HapticService.instance.initialize();
    print('✅ HapticService initialized');

  } catch (e) {
    print('❌ Error during app initialization: $e');
  }

  runApp(const SmartPaisaApp());
}

class SmartPaisaApp extends StatelessWidget {
  const SmartPaisaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider()..loadTheme(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          print('🎨 Building app with theme: ${themeProvider.isDarkMode ? 'Dark' : 'Light'}');

          return MaterialApp(
            title: 'SmartPaisa',
            debugShowCheckedModeBanner: false,

            // Apply themes globally
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

            // Global theme animation
            themeAnimationDuration: const Duration(milliseconds: 300),
            themeAnimationCurve: Curves.easeInOut,

            home: const HomeScreen(),

            // Optional: Custom page transitions
            builder: (context, child) {
              return AnimatedTheme(
                duration: const Duration(milliseconds: 300),
                data: Theme.of(context),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
