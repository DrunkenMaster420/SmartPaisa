import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../services/storage_service.dart';
import '../services/category_service.dart';
import '../services/haptic_service.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final _storage = StorageService.instance;
  final _categoryService = CategoryService();
  final _hapticService = HapticService.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Settings State
  bool _enableNotifications = true;
  bool _enableFloatingPopup = true;
  bool _enableSmartSuggestions = true;
  bool _enableAppLock = false;
  bool _enableDarkMode = true;
  bool _enableHapticFeedback = true;
  bool _isLoading = true;
  bool _isResetting = false;
  bool _biometricsAvailable = false;

  // Animation Controllers
  AnimationController? _fadeController;
  AnimationController? _slideController;
  AnimationController? _resetController;

  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkBiometrics();
    _loadSettings();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _resetController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.elasticOut,
    ));

    _resetAnimation = CurvedAnimation(
      parent: _resetController!,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _resetController?.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _biometricsAvailable = isAvailable && isDeviceSupported;
      });
    } catch (e) {
      print('Error checking biometrics: $e');
      setState(() => _biometricsAvailable = false);
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _enableNotifications = _storage.getSetting('enable_notifications', true);
      _enableFloatingPopup = _storage.getSetting('enable_floating_popup', true);
      _enableSmartSuggestions = _storage.getSetting('enable_smart_suggestions', true);
      _enableAppLock = _storage.getSetting('enable_app_lock', false);
      _enableDarkMode = _storage.getSetting('enable_dark_mode', true);
      _enableHapticFeedback = _storage.getSetting('enable_haptic_feedback', true);
      _isLoading = false;
    });

    _fadeController?.forward();
    _slideController?.forward();
  }

  Future<void> _saveSetting(String key, bool value) async {
    await _hapticService.selectionClick();
    await _storage.saveSetting(key, value);
  }

  // FIXED: DARK MODE FUNCTIONALITY WITH THEME PROVIDER
  Future<void> _toggleDarkMode(bool value) async {
    await _hapticService.mediumImpact();

    setState(() => _enableDarkMode = value);

    // Use ThemeProvider to actually change the theme
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setTheme(value);

    if (mounted) {
      _showSuccessSnackBar(
          value ? 'Dark mode enabled' : 'Light mode enabled'
      );
    }
  }

  // FIXED: HAPTIC FEEDBACK FUNCTIONALITY WITH HAPTIC SERVICE
  Future<void> _toggleHapticFeedback(bool value) async {
    setState(() => _enableHapticFeedback = value);

    // Use HapticService to handle haptic feedback
    await _hapticService.setEnabled(value);

    if (mounted) {
      _showSuccessSnackBar(
          value ? 'Haptic feedback enabled' : 'Haptic feedback disabled'
      );
    }
  }

  // APP LOCK FUNCTIONALITY (unchanged)
  Future<void> _toggleAppLock(bool value) async {
    if (!_biometricsAvailable) {
      _showErrorSnackBar('Biometric authentication not available on this device');
      return;
    }

    if (value) {
      try {
        final bool authenticated = await _localAuth.authenticate(
          localizedReason: 'Enable app lock to secure your financial data',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );

        if (authenticated) {
          setState(() => _enableAppLock = true);
          await _saveSetting('enable_app_lock', true);
          await _hapticService.heavyImpact();
          _showSuccessSnackBar('App lock enabled successfully');
        } else {
          _showErrorSnackBar('Authentication failed. App lock not enabled.');
        }
      } catch (e) {
        _showErrorSnackBar('Error enabling app lock: $e');
      }
    } else {
      try {
        final bool authenticated = await _localAuth.authenticate(
          localizedReason: 'Authenticate to disable app lock',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );

        if (authenticated) {
          setState(() => _enableAppLock = false);
          await _saveSetting('enable_app_lock', false);
          await _hapticService.lightImpact();
          _showSuccessSnackBar('App lock disabled');
        } else {
          _showErrorSnackBar('Authentication failed. App lock remains enabled.');
        }
      } catch (e) {
        _showErrorSnackBar('Error disabling app lock: $e');
      }
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ResetDialog(
        onReset: _performReset,
      ),
    );
  }

  Future<void> _performReset(Set<String> resetOptions) async {
    setState(() => _isResetting = true);
    _resetController?.forward();

    await _hapticService.heavyImpact();

    try {
      int resetCount = 0;

      if (resetOptions.contains('transactions')) {
        await _storage.clearTransactions();
        resetCount++;
      }

      if (resetOptions.contains('categories')) {
        await _storage.clearCustomCategories();
        resetCount++;
      }

      if (resetOptions.contains('settings')) {
        await _storage.saveSetting('enable_notifications', true);
        await _storage.saveSetting('enable_floating_popup', true);
        await _storage.saveSetting('enable_smart_suggestions', true);
        await _storage.saveSetting('enable_app_lock', false);
        await _storage.saveSetting('enable_dark_mode', true);
        await _storage.saveSetting('enable_haptic_feedback', true);
        resetCount++;
      }

      if (resetOptions.contains('learning')) {
        await _categoryService.clearLearning();
        resetCount++;
      }

      if (resetOptions.contains('cache')) {
        resetCount++;
      }

      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        _showSuccessSnackBar('Successfully reset $resetCount data types!');
        if (resetOptions.contains('settings')) {
          await _loadSettings();
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error resetting data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
        _resetController?.reverse();
      }
    }
  }

  void _confirmClearLearning() {
    showDialog(
      context: context,
      builder: (context) => _ModernAlertDialog(
        title: 'Clear Learning Data',
        content: 'This will remove all remembered merchant-category mappings. The app will need to re-learn your preferences.',
        confirmText: 'Clear',
        confirmColor: const Color(0xFFFF4757),
        onConfirm: () async {
          await _categoryService.clearLearning();
          if (mounted) {
            _showSuccessSnackBar('Learning data cleared successfully!');
          }
        },
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF4ECDC4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use theme from ThemeProvider
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern App Bar with dynamic colors
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1A1F2E), const Color(0xFF0A0E1A)]
                        : [Colors.white, const Color(0xFFF8F9FA)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customize your app experience',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content with dynamic theming
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingWidget()
                : _fadeAnimation != null && _slideAnimation != null
                ? FadeTransition(
              opacity: _fadeAnimation!,
              child: SlideTransition(
                position: _slideAnimation!,
                child: _buildContent(),
              ),
            )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading settings...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Notifications Section
          _buildSettingsSection(
            'Notifications',
            Icons.notifications,
            const Color(0xFF4ECDC4),
            [
              _buildModernSwitchTile(
                'Push Notifications',
                'Receive alerts for new transactions',
                Icons.notifications_active,
                _enableNotifications,
                    (value) async {
                  setState(() => _enableNotifications = value);
                  await _saveSetting('enable_notifications', value);
                },
              ),
              _buildModernSwitchTile(
                'Floating Popup',
                'Show transaction popups over other apps',
                Icons.picture_in_picture,
                _enableFloatingPopup,
                    (value) async {
                  setState(() => _enableFloatingPopup = value);
                  await _saveSetting('enable_floating_popup', value);
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Smart Features Section
          _buildSettingsSection(
            'Smart Features',
            Icons.psychology,
            const Color(0xFF667EEA),
            [
              _buildModernSwitchTile(
                'Smart Suggestions',
                'AI-powered category suggestions',
                Icons.auto_awesome,
                _enableSmartSuggestions,
                    (value) async {
                  setState(() => _enableSmartSuggestions = value);
                  await _saveSetting('enable_smart_suggestions', value);
                },
              ),
              _buildActionTile(
                'Clear Learning Data',
                'Reset AI learning patterns',
                Icons.psychology_outlined,
                const Color(0xFF667EEA),
                _confirmClearLearning,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Security Section
          _buildSettingsSection(
            'Security & Privacy',
            Icons.security,
            const Color(0xFF764BA2),
            [
              _buildModernSwitchTile(
                'App Lock',
                _biometricsAvailable
                    ? 'Require biometric authentication to open app'
                    : 'Biometric authentication not available',
                _biometricsAvailable ? Icons.lock : Icons.lock_outline,
                _enableAppLock,
                _biometricsAvailable ? _toggleAppLock : null,
                isDisabled: !_biometricsAvailable,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Appearance Section - FIXED
          _buildSettingsSection(
            'Appearance',
            Icons.palette,
            const Color(0xFFFF9F43),
            [
              _buildModernSwitchTile(
                'Dark Mode',
                'Use dark theme throughout the app',
                Icons.dark_mode,
                _enableDarkMode,
                _toggleDarkMode,
              ),
              _buildModernSwitchTile(
                'Haptic Feedback',
                _hapticService.isSupported
                    ? 'Vibration feedback for interactions'
                    : 'Haptic feedback not supported on this device',
                Icons.vibration,
                _enableHapticFeedback,
                _hapticService.isSupported ? _toggleHapticFeedback : null,
                isDisabled: !_hapticService.isSupported,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Data Management Section
          _buildSettingsSection(
            'Data Management',
            Icons.storage,
            const Color(0xFFFF4757),
            [
              _buildActionTile(
                'Reset App Data',
                'Selectively reset different data types',
                Icons.restore,
                const Color(0xFFFF4757),
                _showResetDialog,
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
      String title,
      IconData icon,
      Color color,
      List<Widget> children,
      ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernSwitchTile(
      String title,
      String subtitle,
      IconData icon,
      bool value,
      Future<void> Function(bool)? onChanged, {
        bool isDisabled = false,
      }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? (isDisabled ? const Color(0xFF2A2F3E).withOpacity(0.5) : const Color(0xFF2A2F3E))
            : (isDisabled ? Colors.grey.shade100 : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isDisabled || onChanged == null
              ? null
              : () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: value && !isDisabled
                        ? const Color(0xFF4ECDC4).withOpacity(0.1)
                        : theme.dividerColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: value && !isDisabled
                        ? const Color(0xFF4ECDC4)
                        : theme.iconTheme.color?.withOpacity(isDisabled ? 0.3 : 0.6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.titleMedium?.color?.withOpacity(isDisabled ? 0.5 : 1.0),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(isDisabled ? 0.3 : 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: value && !isDisabled
                        ? const LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                    )
                        : null,
                    color: value && !isDisabled
                        ? null
                        : theme.dividerColor.withOpacity(isDisabled ? 0.1 : 0.2),
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        left: value ? 22 : 2,
                        top: 2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isDisabled
                                ? Colors.white.withOpacity(0.5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2F3E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.iconTheme.color?.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Keep the same dialog classes but update colors to use theme
class _ResetDialog extends StatefulWidget {
  final Function(Set<String>) onReset;

  const _ResetDialog({required this.onReset});

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> with TickerProviderStateMixin {
  final Set<String> _selectedOptions = {};
  late AnimationController _dialogController;
  late Animation<double> _dialogAnimation;

  final Map<String, Map<String, dynamic>> _resetOptions = {
    'transactions': {
      'title': 'All Transactions',
      'subtitle': 'Delete all transaction history',
      'icon': Icons.receipt_long,
      'color': const Color(0xFFFF4757),
    },
    'categories': {
      'title': 'Custom Categories',
      'subtitle': 'Remove user-created categories',
      'icon': Icons.category,
      'color': const Color(0xFF667EEA),
    },
    'settings': {
      'title': 'App Settings',
      'subtitle': 'Reset all preferences to default',
      'icon': Icons.settings,
      'color': const Color(0xFF764BA2),
    },
    'learning': {
      'title': 'Learning Data',
      'subtitle': 'Clear ML categorization patterns',
      'icon': Icons.psychology,
      'color': const Color(0xFF4ECDC4),
    },
    'cache': {
      'title': 'App Cache',
      'subtitle': 'Clear temporary files and data',
      'icon': Icons.storage,
      'color': const Color(0xFFFF9F43),
    },
  };

  @override
  void initState() {
    super.initState();
    _dialogController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _dialogAnimation = CurvedAnimation(
      parent: _dialogController,
      curve: Curves.elasticOut,
    );
    _dialogController.forward();
  }

  @override
  void dispose() {
    _dialogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _dialogAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4757), Color(0xFFFF6B6B)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Reset Data',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  'Select which data you want to reset. This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 24),

                // Reset Options
                Column(
                  children: _resetOptions.entries.map((entry) {
                    final key = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedOptions.contains(key);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (option['color'] as Color).withOpacity(0.1)
                            : (isDark ? const Color(0xFF2A2F3E) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? (option['color'] as Color).withOpacity(0.3)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isSelected) {
                                _selectedOptions.remove(key);
                              } else {
                                _selectedOptions.add(key);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (option['color'] as Color).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    option['icon'] as IconData,
                                    color: option['color'] as Color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option['title'] as String,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: theme.textTheme.titleMedium?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? option['color'] as Color
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? option['color'] as Color
                                          : theme.dividerColor.withOpacity(0.3),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedOptions.isEmpty
                            ? null
                            : () {
                          HapticFeedback.heavyImpact();
                          Navigator.of(context).pop();
                          widget.onReset(_selectedOptions);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4757),
                          disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Reset ${_selectedOptions.length > 0 ? '(${_selectedOptions.length})' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Modern Alert Dialog
class _ModernAlertDialog extends StatefulWidget {
  final String title;
  final String content;
  final String confirmText;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ModernAlertDialog({
    required this.title,
    required this.content,
    required this.confirmText,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  State<_ModernAlertDialog> createState() => _ModernAlertDialogState();
}

class _ModernAlertDialogState extends State<_ModernAlertDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [widget.confirmColor, widget.confirmColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  widget.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.confirmColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.confirmText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
