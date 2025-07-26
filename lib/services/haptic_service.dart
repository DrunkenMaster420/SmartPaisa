import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  static HapticService get instance => _instance;
  HapticService._internal();

  final StorageService _storage = StorageService.instance;
  bool _isEnabled = true;
  bool _isSupported = true;
  bool _isInitialized = false;

  bool get isEnabled => _isEnabled && _isSupported && _isInitialized;
  bool get isSupported => _isSupported;

  Future<void> initialize() async {
    try {
      print('🔄 Initializing HapticService...');

      // Load saved preference
      _isEnabled = _storage.getSetting('enable_haptic_feedback', true);
      print('📱 Haptic feedback enabled in settings: $_isEnabled');

      // Check platform support
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {

        // Test if haptic feedback actually works
        try {
          await HapticFeedback.lightImpact();
          _isSupported = true;
          print('✅ Haptic feedback supported and working');
        } catch (e) {
          _isSupported = false;
          print('❌ Haptic feedback test failed: $e');
        }
      } else {
        _isSupported = false;
        print('❌ Platform does not support haptic feedback');
      }

      _isInitialized = true;
      print('🎉 HapticService initialized - Enabled: $_isEnabled, Supported: $_isSupported');

      // Test haptic on startup if enabled
      if (isEnabled) {
        await lightImpact();
      }

    } catch (e) {
      print('❌ Error initializing HapticService: $e');
      _isSupported = false;
      _isInitialized = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    print('🔧 Setting haptic feedback to: $enabled');
    _isEnabled = enabled;
    await _storage.saveSetting('enable_haptic_feedback', enabled);

    // Test haptic feedback when enabling
    if (enabled && _isSupported) {
      print('🧪 Testing haptic feedback...');
      await heavyImpact();
    }
  }

  Future<void> lightImpact() async {
    if (!isEnabled) {
      print('⚠️ Light haptic skipped - not enabled');
      return;
    }
    try {
      await HapticFeedback.lightImpact();
      print('🟢 Light haptic feedback triggered');
    } catch (e) {
      print('❌ Light haptic feedback failed: $e');
    }
  }

  Future<void> mediumImpact() async {
    if (!isEnabled) {
      print('⚠️ Medium haptic skipped - not enabled');
      return;
    }
    try {
      await HapticFeedback.mediumImpact();
      print('🟡 Medium haptic feedback triggered');
    } catch (e) {
      print('❌ Medium haptic feedback failed: $e');
    }
  }

  Future<void> heavyImpact() async {
    if (!isEnabled) {
      print('⚠️ Heavy haptic skipped - not enabled');
      return;
    }
    try {
      await HapticFeedback.heavyImpact();
      print('🔴 Heavy haptic feedback triggered');
    } catch (e) {
      print('❌ Heavy haptic feedback failed: $e');
    }
  }

  Future<void> selectionClick() async {
    if (!isEnabled) {
      print('⚠️ Selection haptic skipped - not enabled');
      return;
    }
    try {
      await HapticFeedback.selectionClick();
      print('🔵 Selection haptic feedback triggered');
    } catch (e) {
      print('❌ Selection haptic feedback failed: $e');
    }
  }

  Future<void> vibrate() async {
    if (!isEnabled) {
      print('⚠️ Vibrate haptic skipped - not enabled');
      return;
    }
    try {
      await HapticFeedback.vibrate();
      print('📳 Vibrate haptic feedback triggered');
    } catch (e) {
      print('❌ Vibrate haptic feedback failed: $e');
    }
  }

  // Convenience method for testing
  Future<void> testAllHaptics() async {
    if (!isEnabled) {
      print('⚠️ Haptic test skipped - not enabled');
      return;
    }

    print('🧪 Testing all haptic feedback types...');
    await lightImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await mediumImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await selectionClick();
  }
}
