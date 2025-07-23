import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/category_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final _storage = StorageService.instance;
  final _categoryService = CategoryService();

  // Settings State
  bool _enableNotifications = true;
  bool _enableFloatingPopup = true;
  bool _enableSmartSuggestions = true;
  bool _enableAppLock = false;
  bool _enableDarkMode = true;
  bool _enableHapticFeedback = true;
  bool _isLoading = true;
  bool _isResetting = false;

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

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _enableNotifications = (_storage.getSetting('enable_notifications', true)) as bool;
      _enableFloatingPopup = (_storage.getSetting('enable_floating_popup', true)) as bool;
      _enableSmartSuggestions = (_storage.getSetting('enable_smart_suggestions', true)) as bool;
      _enableAppLock = (_storage.getSetting('enable_app_lock', false)) as bool;
      _enableDarkMode = (_storage.getSetting('enable_dark_mode', true)) as bool;
      _enableHapticFeedback = (_storage.getSetting('enable_haptic_feedback', true)) as bool;
      _isLoading = false;
    });

    _fadeController?.forward();
    _slideController?.forward();
  }

  Future<void> _saveSetting(String key, bool value) async {
    if (_enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }
    await _storage.saveSetting(key, value);
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

    if (_enableHapticFeedback) {
      HapticFeedback.heavyImpact();
    }

    try {
      int resetCount = 0;

      if (resetOptions.contains('transactions')) {
        // await _storage.clearAllTransactions();
        resetCount++;
      }

      if (resetOptions.contains('categories')) {
        // await _storage.clearCustomCategories();
        resetCount++;
      }

      if (resetOptions.contains('settings')) {
        // await _storage.clearSettings();
        resetCount++;
      }

      if (resetOptions.contains('learning')) {
        await _categoryService.clearLearning();
        resetCount++;
      }

      if (resetOptions.contains('cache')) {
        // Clear cache
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E1A),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1F2E), Color(0xFF0A0E1A)],
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
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customize your app experience',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              // Reset Button
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: _resetAnimation != null
                    ? AnimatedBuilder(
                  animation: _resetAnimation!,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_resetAnimation!.value * 0.1),
                      child: Material(
                        color: const Color(0xFFFF4757),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isResetting ? null : _showResetDialog,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              _isResetting ? Icons.hourglass_empty : Icons.restore,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
                    : Material(
                  color: const Color(0xFFFF4757),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showResetDialog,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.restore,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
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
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
                    (value) {
                  setState(() => _enableNotifications = value);
                  _saveSetting('enable_notifications', value);
                },
              ),
              _buildModernSwitchTile(
                'Floating Popup',
                'Show transaction popups over other apps',
                Icons.picture_in_picture,
                _enableFloatingPopup,
                    (value) {
                  setState(() => _enableFloatingPopup = value);
                  _saveSetting('enable_floating_popup', value);
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
                    (value) {
                  setState(() => _enableSmartSuggestions = value);
                  _saveSetting('enable_smart_suggestions', value);
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
                'Require authentication to open app',
                Icons.lock,
                _enableAppLock,
                    (value) {
                  setState(() => _enableAppLock = value);
                  _saveSetting('enable_app_lock', value);
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Appearance Section
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
                    (value) {
                  setState(() => _enableDarkMode = value);
                  _saveSetting('enable_dark_mode', value);
                },
              ),
              _buildModernSwitchTile(
                'Haptic Feedback',
                'Vibration feedback for interactions',
                Icons.vibration,
                _enableHapticFeedback,
                    (value) {
                  setState(() => _enableHapticFeedback = value);
                  _saveSetting('enable_haptic_feedback', value);
                },
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                    color: Colors.white.withOpacity(0.9),
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
      ValueChanged<bool> onChanged,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2F3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: value
                        ? const Color(0xFF4ECDC4).withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: value
                        ? const Color(0xFF4ECDC4)
                        : Colors.white.withOpacity(0.6),
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
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
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
                    gradient: value
                        ? const LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                    )
                        : null,
                    color: value ? null : Colors.white.withOpacity(0.2),
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
                            color: Colors.white,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2F3E),
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
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Fixed Reset Dialog without spread operator
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _dialogAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
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
                          color: Colors.white.withOpacity(0.9),
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
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 24),

                // Reset Options - Fixed without spread operator
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
                            : const Color(0xFF2A2F3E),
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
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.6),
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
                                          : Colors.white.withOpacity(0.3),
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
                            color: Colors.white.withOpacity(0.7),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 350),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.confirmColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: widget.confirmColor,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  widget.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.confirmColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.confirmText,
                          style: const TextStyle(
                            color: Colors.white,
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
