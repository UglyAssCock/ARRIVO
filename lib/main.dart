import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'services.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ArrivoApp());
}

class ArrivoApp extends StatefulWidget {
  const ArrivoApp({super.key});

  @override
  State<ArrivoApp> createState() => _ArrivoAppState();
}

class _ArrivoAppState extends State<ArrivoApp> with WidgetsBindingObserver {
  List<PackageItem> _packages = [];
  String _lang = 'en';
  String _themeMode = 'light';
  bool _onboardingDone = true;
  bool _notificationsEnabled = true;
  bool _isPremium = false;
  bool _isLoading = true;
  Timer? _backgroundTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSilentUpdates();
    }
  }

  Future<void> _initializeApp() async {
    final pkgs = await StorageService.loadPackages();
    final lang = await StorageService.loadLanguage();
    final theme = await StorageService.loadThemeMode();
    final onboarded = await StorageService.isOnboardingComplete();
    final notif = await StorageService.loadNotificationsEnabled();
    final premium = await StorageService.loadIsPremium();

    if (mounted) {
      setState(() {
        _packages = pkgs;
        _lang = lang;
        _themeMode = theme;
        _onboardingDone = onboarded;
        _notificationsEnabled = notif;
        _isPremium = premium;
        _isLoading = false;
      });
    }

    await NotificationService.requestPermission();

    // Periodic background refresh while app is alive
    _backgroundTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _checkSilentUpdates();
    });
  }

  Future<void> _checkSilentUpdates() async {
    if (!_notificationsEnabled || _packages.isEmpty) return;
    // Check if any package is arriving soon
    final arriving = _packages.where(
      (p) => !p.isArchived && p.status == PackageStatus.arrivingSoon,
    );
    if (arriving.isNotEmpty) {
      final first = arriving.first;
      await NotificationService.showNotification(
        id: 100,
        title: 'Arrivo: ${first.customName}',
        body: 'Status update: ${first.eta}',
      );
    }
  }

  int get _activePackageCount =>
      _packages.where((p) => !p.isArchived).length;

  ThemeMode get _resolvedThemeMode {
    if (_themeMode == 'dark') return ThemeMode.dark;
    if (_themeMode == 'system') return ThemeMode.system;
    return ThemeMode.light;
  }

  Future<void> _updateLanguage(String newLang) async {
    setState(() => _lang = newLang);
    await StorageService.saveLanguage(newLang);
  }

  Future<void> _updateTheme(String newTheme) async {
    setState(() => _themeMode = newTheme);
    await StorageService.saveThemeMode(newTheme);
  }

  Future<void> _updateNotifications(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    await StorageService.saveNotificationsEnabled(enabled);
  }

  Future<void> _updatePremium(bool value) async {
    setState(() => _isPremium = value);
    await StorageService.saveIsPremium(value);
  }

  Future<void> _savePackagesList(List<PackageItem> updated) async {
    setState(() => _packages = updated);
    await StorageService.savePackages(updated);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrivo',
      debugShowCheckedModeBanner: false,
      themeMode: _resolvedThemeMode,
      locale: Locale(_lang),
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: ArrivoColors.lightBlueBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ArrivoColors.primaryBlue,
          primary: ArrivoColors.primaryBlue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1628),
        colorScheme: ColorScheme.fromSeed(
          seedColor: ArrivoColors.primaryBlue,
          primary: ArrivoColors.primaryBlue,
          brightness: Brightness.dark,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: AppStrings.directionOf(_lang),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : !_onboardingDone
              ? OnboardingScreen(
                  lang: _lang,
                  onLanguageChanged: _updateLanguage,
                  onFinish: () async {
                    await StorageService.setOnboardingComplete();
                    setState(() => _onboardingDone = true);
                  },
                )
              : MainNavigationShell(
                  packages: _packages,
                  lang: _lang,
                  themeMode: _themeMode,
                  notificationsEnabled: _notificationsEnabled,
                  isPremium: _isPremium,
                  activePackageCount: _activePackageCount,
                  onPackagesChanged: _savePackagesList,
                  onLanguageChanged: _updateLanguage,
                  onThemeChanged: _updateTheme,
                  onNotificationsChanged: _updateNotifications,
                  onPremiumChanged: _updatePremium,
                ),
    );
  }
}

/// 1. ONBOARDING SCREEN (3 slides + Language Picker for Arabic, French, English)
class OnboardingScreen extends StatefulWidget {
  final String lang;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onFinish;

  const OnboardingScreen({
    super.key,
    required this.lang,
    required this.onLanguageChanged,
    required this.onFinish,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final slides = [
      (
        Icons.public_rounded,
        AppStrings.tr(widget.lang, 'onboarding_1_title'),
        AppStrings.tr(widget.lang, 'onboarding_1_desc'),
      ),
      (
        Icons.qr_code_scanner_rounded,
        AppStrings.tr(widget.lang, 'onboarding_2_title'),
        AppStrings.tr(widget.lang, 'onboarding_2_desc'),
      ),
      (
        Icons.notifications_active_rounded,
        AppStrings.tr(widget.lang, 'onboarding_3_title'),
        AppStrings.tr(widget.lang, 'onboarding_3_desc'),
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0052FF),
              Color(0xFF002E9E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Language Picker Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ArrivoLogoHeader(scale: 0.78),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          _langChip('EN', 'en'),
                          _langChip('FR', 'fr'),
                          _langChip('عربي', 'ar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (idx) => setState(() => _page = idx),
                  itemBuilder: (context, index) {
                    final item = slides[index];
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: index == 0
                                ? const IsometricPackageBox(
                                    size: 110,
                                    withSpeedLines: true,
                                  )
                                : Icon(
                                    item.$1,
                                    size: 86,
                                    color: Colors.white,
                                  ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            item.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.$3,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 16,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Page dots + Next/Get Started buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: widget.onFinish,
                      child: Text(
                        AppStrings.tr(widget.lang, 'skip'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _page == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _page == i ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ArrivoColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () {
                        if (_page < slides.length - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        } else {
                          widget.onFinish();
                        }
                      },
                      child: Text(
                        _page == slides.length - 1
                            ? AppStrings.tr(widget.lang, 'get_started')
                            : AppStrings.tr(widget.lang, 'next'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langChip(String title, String code) {
    final selected = widget.lang == code;
    return GestureDetector(
      onTap: () => widget.onLanguageChanged(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? ArrivoColors.primaryBlue : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// MAIN SHELL WITH HOME, TRACK, HISTORY, PROFILE & FLOATING '+' BUTTON
class MainNavigationShell extends StatefulWidget {
  final List<PackageItem> packages;
  final String lang;
  final String themeMode;
  final bool notificationsEnabled;
  final bool isPremium;
  final int activePackageCount;
  final ValueChanged<List<PackageItem>> onPackagesChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onPremiumChanged;

  const MainNavigationShell({
    super.key,
    required this.packages,
    required this.lang,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.isPremium,
    required this.activePackageCount,
    required this.onPackagesChanged,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.onPremiumChanged,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;
  bool _isAddingLoading = false;
  final TextEditingController _homeSearchCtrl = TextEditingController();

  void _openPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumPaywallScreen(
          isPremium: widget.isPremium,
          activeCount: widget.activePackageCount,
          onUnlockDemoPremium: () {
            widget.onPremiumChanged(true);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Arrivo Premium unlocked! Unlimited packages active.'),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openBarcodeScanner({bool autoTrack = true}) async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scannedCode != null && scannedCode.trim().isNotEmpty && mounted) {
      if (autoTrack) {
        _openAddPackageDialog(prefillNumber: scannedCode.trim());
      } else {
        _homeSearchCtrl.text = scannedCode.trim();
      }
    }
  }

  void _openAddPackageDialog({String? prefillNumber}) {
    // Check Free Plan Limit (5 active packages)
    if (!widget.isPremium && widget.activePackageCount >= 5) {
      _openPaywall();
      return;
    }

    final numberCtrl = TextEditingController(text: prefillNumber ?? '');
    final nameCtrl = TextEditingController();
    String selectedCarrier = 'auto';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final detected = CarrierRegistry.detectCarrier(numberCtrl.text);
            return Container(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 22,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF17223B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.tr(widget.lang, 'add_package'),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!widget.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ArrivoColors.chipBlueBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Free Plan: ${widget.activePackageCount}/5',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ArrivoColors.primaryBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: numberCtrl,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(widget.lang, 'search_hint'),
                      hintText: 'e.g. YAL-99281DZ or TRK123456789',
                      prefixIcon: const Icon(Icons.qr_code_2_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Paste',
                            icon: const Icon(Icons.content_paste_rounded),
                            onPressed: () async {
                              final data =
                                  await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                numberCtrl.text = data!.text!.trim();
                                setSheetState(() {});
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Scan Barcode',
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              color: ArrivoColors.primaryBlue,
                            ),
                            onPressed: () async {
                              final code =
                                  await Navigator.of(ctx).push<String>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const BarcodeScannerScreen(),
                                ),
                              );
                              if (code != null && code.isNotEmpty) {
                                numberCtrl.text = code;
                                setSheetState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  if (numberCtrl.text.trim().isNotEmpty &&
                      selectedCarrier == 'auto') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: ArrivoColors.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Auto-detected: ${detected.name} (${detected.region})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: ArrivoColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(widget.lang, 'custom_name'),
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedCarrier,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(widget.lang, 'carrier'),
                      prefixIcon: const Icon(Icons.local_shipping_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: CarrierRegistry.carriers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} • ${c.region}'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selectedCarrier = val);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArrivoColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.track_changes_rounded),
                      label: Text(
                        AppStrings.tr(widget.lang, 'track_now'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: () {
                        final rawNum = numberCtrl.text.trim();
                        if (rawNum.isEmpty) return;
                        Navigator.of(ctx).pop();
                        _submitNewPackage(
                          trackingNumber: rawNum,
                          customName: nameCtrl.text.trim(),
                          carrierId: selectedCarrier,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitNewPackage({
    required String trackingNumber,
    required String customName,
    required String carrierId,
  }) async {
    if (!widget.isPremium && widget.activePackageCount >= 5) {
      _openPaywall();
      return;
    }

    setState(() => _isAddingLoading = true);

    try {
      final newPkg = await TrackingApiService.fetchTrackingInfo(
        trackingNumber: trackingNumber,
        customName: customName,
        selectedCarrierId: carrierId,
      );

      final updated = [newPkg, ...widget.packages];
      widget.onPackagesChanged(updated);

      if (widget.notificationsEnabled) {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          title: 'Package Added: ${newPkg.customName}',
          body: '#${newPkg.trackingNumber} • ${newPkg.eta}',
        );
      }
    } on FormatException {
      if (mounted) {
        _showNotFoundDialog(trackingNumber);
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingLoading = false);
      }
    }
  }

  void _showNotFoundDialog(String trackingNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.tr(widget.lang, 'not_found_title'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Code: #$trackingNumber',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ArrivoColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(AppStrings.tr(widget.lang, 'not_found_desc')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ArrivoColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _openAddPackageDialog(prefillNumber: trackingNumber);
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _handleCardMenuAction(PackageItem pkg, String action) {
    if (action == 'rename') {
      final ctrl = TextEditingController(text: pkg.customName);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename Package'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Package Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = widget.packages
                    .map((p) => p.id == pkg.id
                        ? p.copyWith(customName: ctrl.text.trim())
                        : p)
                    .toList();
                widget.onPackagesChanged(updated);
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else if (action == 'share') {
      Share.share(
        'Arrivo Package Tracking:\n${pkg.customName} (#${pkg.trackingNumber})\nStatus: ${pkg.status.name}\nETA: ${pkg.eta}',
      );
    } else if (action == 'archive') {
      final updated = widget.packages
          .map((p) =>
              p.id == pkg.id ? p.copyWith(isArchived: !p.isArchived) : p)
          .toList();
      widget.onPackagesChanged(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pkg.isArchived ? 'Restored from Archive' : 'Moved to Archive',
          ),
        ),
      );
    } else if (action == 'delete') {
      final updated =
          widget.packages.where((p) => p.id != pkg.id).toList();
      widget.onPackagesChanged(updated);
    }
  }

  void _openPackageDetails(PackageItem pkg) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PackageDetailsScreen(
          package: pkg,
          lang: widget.lang,
          onUpdatePackage: (updatedPkg) {
            final list = widget.packages
                .map((p) => p.id == updatedPkg.id ? updatedPkg : p)
                .toList();
            widget.onPackagesChanged(list);
          },
          onDeletePackage: () {
            final list =
                widget.packages.where((p) => p.id != pkg.id).toList();
            widget.onPackagesChanged(list);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.info_rounded, color: ArrivoColors.primaryBlue, size: 28),
            SizedBox(width: 10),
            Text('About Arrivo', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Arrivo v1.0.0 (com.arrivo.app)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track your local Algerian & international packages anytime, anywhere. Supports Yalidine, ZR Express, Algérie Poste/EMS, DHL, Aramex, AliExpress, Temu, and Shein.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ArrivoColors.chipBlueBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                TrackingApiService.isLiveApiConfigured
                    ? AppStrings.tr(widget.lang, 'live_api_badge')
                    : AppStrings.tr(widget.lang, 'demo_mode_badge'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ArrivoColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePackages =
        widget.packages.where((p) => !p.isArchived).toList();

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // TAB 0: HOME SCREEN (Matching the attached screenshot design)
          _buildHomeScreen(activePackages),

          // TAB 1: TRACK SCREEN (Tabs: In Transit, Delivered, All + Search)
          TrackPackagesTab(
            packages: activePackages,
            lang: widget.lang,
            onOpenDetails: _openPackageDetails,
            onMenuAction: _handleCardMenuAction,
          ),

          // TAB 2: HISTORY SCREEN (Delivered & Archived packages)
          HistoryPackagesTab(
            packages: widget.packages,
            lang: widget.lang,
            onOpenDetails: _openPackageDetails,
            onMenuAction: _handleCardMenuAction,
          ),

          // TAB 3: PROFILE & SETTINGS SCREEN
          ProfileSettingsTab(
            lang: widget.lang,
            themeMode: widget.themeMode,
            notificationsEnabled: widget.notificationsEnabled,
            isPremium: widget.isPremium,
            activeCount: widget.activePackageCount,
            onLanguageChanged: widget.onLanguageChanged,
            onThemeChanged: widget.onThemeChanged,
            onNotificationsChanged: widget.onNotificationsChanged,
            onOpenPaywall: _openPaywall,
            onShowAbout: _showAboutDialog,
          ),
        ],
      ),
      // Blue Floating '+' Button with halo ring matching the screenshot
      floatingActionButton: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ArrivoColors.primaryBlue.withOpacity(0.14),
        ),
        child: SizedBox(
          width: 62,
          height: 62,
          child: FloatingActionButton(
            elevation: 6,
            backgroundColor: ArrivoColors.primaryBlue,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            onPressed: () => _openAddPackageDialog(),
            child: const Icon(Icons.add, size: 34),
          ),
        ),
      ),
      // Rounded Floating Bottom Navigation Bar matching the screenshot
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHomeScreen(List<PackageItem> activePackages) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Blue Wavy Header + Floating Search Bar
          Stack(
            clipBehavior: Clip.none,
            children: [
              WavyHeaderBackground(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ArrivoLogoHeader(scale: 1.0),
                                  const SizedBox(height: 10),
                                  Text(
                                    AppStrings.tr(widget.lang, 'tagline'),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.88),
                                      fontSize: 15.5,
                                      height: 1.3,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Notification Bell with Red Dot
                            GestureDetector(
                              onTap: () async {
                                await NotificationService.showNotification(
                                  id: 777,
                                  title: 'Arrivo Live Tracker',
                                  body:
                                      'Your packages are being monitored in real time!',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Notification sent! Check your phone status bar.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF002B8F)
                                          .withOpacity(0.75),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.18),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Colors.white,
                                      size: 25,
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: ArrivoColors.alertRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 3D Package Illustration on the right side of header
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: IsometricPackageBox(
                              size: 108,
                              withSpeedLines: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating White Pill Search Bar with Blue Arrow Button
              Positioned(
                left: 18,
                right: 18,
                bottom: -18,
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: ArrivoColors.primaryBlue.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF5D6B86),
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _homeSearchCtrl,
                          style: const TextStyle(
                            color: ArrivoColors.textDark,
                            fontSize: 15.5,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                AppStrings.tr(widget.lang, 'search_hint'),
                            hintStyle: const TextStyle(
                              color: Color(0xFF697691),
                              fontSize: 15.5,
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _submitNewPackage(
                                trackingNumber: val.trim(),
                                customName: '',
                                carrierId: 'auto',
                              );
                              _homeSearchCtrl.clear();
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 46,
                        height: 46,
                        child: Material(
                          color: ArrivoColors.primaryBlue,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              final txt = _homeSearchCtrl.text.trim();
                              if (txt.isNotEmpty) {
                                _submitNewPackage(
                                  trackingNumber: txt,
                                  customName: '',
                                  carrierId: 'auto',
                                );
                                _homeSearchCtrl.clear();
                              } else {
                                _openAddPackageDialog();
                              }
                            },
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          // Four Quick-Action Tiles Row: Scan Barcode, Track History, Settings, About
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                QuickActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: AppStrings.tr(widget.lang, 'scan_barcode'),
                  onTap: () => _openBarcodeScanner(autoTrack: true),
                ),
                QuickActionTile(
                  icon: Icons.history_rounded,
                  label: AppStrings.tr(widget.lang, 'track_history'),
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                QuickActionTile(
                  icon: Icons.settings_rounded,
                  label: AppStrings.tr(widget.lang, 'settings'),
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                QuickActionTile(
                  icon: Icons.info_rounded,
                  label: AppStrings.tr(widget.lang, 'about'),
                  onTap: _showAboutDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // "Your Packages" + "View All >"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.tr(widget.lang, 'your_packages'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          AppStrings.tr(widget.lang, 'view_all'),
                          style: const TextStyle(
                            color: ArrivoColors.primaryBlue,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: ArrivoColors.primaryBlue,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Package Cards List (with Skeleton Loader or Empty State)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                if (_isAddingLoading) const PackageSkeletonLoader(),
                if (activePackages.isEmpty && !_isAddingLoading)
                  _buildEmptyStateCard()
                else
                  ...activePackages.map(
                    (pkg) => PackageTimelineCard(
                      package: pkg,
                      lang: widget.lang,
                      onTap: () => _openPackageDetails(pkg),
                      onMenuAction: (action) =>
                          _handleCardMenuAction(pkg, action),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const IsometricPackageBox(size: 72),
          const SizedBox(height: 14),
          Text(
            AppStrings.tr(widget.lang, 'empty_title'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ArrivoColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.tr(widget.lang, 'empty_desc'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: ArrivoColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (Icons.home_rounded, AppStrings.tr(widget.lang, 'home')),
      (Icons.inventory_2_outlined, AppStrings.tr(widget.lang, 'track')),
      (Icons.access_time_rounded, AppStrings.tr(widget.lang, 'history')),
      (Icons.person_outline_rounded, AppStrings.tr(widget.lang, 'profile')),
    ];

    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17223B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: ArrivoColors.primaryBlue.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = _selectedIndex == i;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedIndex = i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    items[i].$1,
                    size: 27,
                    color: selected
                        ? ArrivoColors.primaryBlue
                        : const Color(0xFF616E87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? ArrivoColors.primaryBlue
                          : const Color(0xFF616E87),
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: selected ? 44 : 0,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: ArrivoColors.primaryBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 3. PACKAGE LIST SCREEN WITH TABS (In Transit, Delivered, All) & SEARCH
class TrackPackagesTab extends StatefulWidget {
  final List<PackageItem> packages;
  final String lang;
  final ValueChanged<PackageItem> onOpenDetails;
  final void Function(PackageItem, String) onMenuAction;

  const TrackPackagesTab({
    super.key,
    required this.packages,
    required this.lang,
    required this.onOpenDetails,
    required this.onMenuAction,
  });

  @override
  State<TrackPackagesTab> createState() => _TrackPackagesTabState();
}

class _TrackPackagesTabState extends State<TrackPackagesTab> {
  int _tab = 0; // 0 = In Transit, 1 = Delivered, 2 = All
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.packages.where((p) {
      final matchesSearch = _query.isEmpty ||
          p.customName.toLowerCase().contains(_query.toLowerCase()) ||
          p.trackingNumber.toLowerCase().contains(_query.toLowerCase());
      if (!matchesSearch) return false;
      if (_tab == 0) return p.status != PackageStatus.delivered;
      if (_tab == 1) return p.status == PackageStatus.delivered;
      return true;
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr(widget.lang, 'your_packages'),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: AppStrings.tr(widget.lang, 'search_hint'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF17223B)
                    : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _tabPill(0, AppStrings.tr(widget.lang, 'in_transit')),
                const SizedBox(width: 8),
                _tabPill(1, AppStrings.tr(widget.lang, 'delivered')),
                const SizedBox(width: 8),
                _tabPill(2, AppStrings.tr(widget.lang, 'all')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        AppStrings.tr(widget.lang, 'empty_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: ArrivoColors.textMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final pkg = filtered[i];
                        return PackageTimelineCard(
                          package: pkg,
                          lang: widget.lang,
                          onTap: () => widget.onOpenDetails(pkg),
                          onMenuAction: (act) => widget.onMenuAction(pkg, act),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? ArrivoColors.primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : ArrivoColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// 8. HISTORY SCREEN OF DELIVERED & ARCHIVED PACKAGES
class HistoryPackagesTab extends StatelessWidget {
  final List<PackageItem> packages;
  final String lang;
  final ValueChanged<PackageItem> onOpenDetails;
  final void Function(PackageItem, String) onMenuAction;

  const HistoryPackagesTab({
    super.key,
    required this.packages,
    required this.lang,
    required this.onOpenDetails,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final historyItems = packages
        .where((p) => p.status == PackageStatus.delivered || p.isArchived)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr(lang, 'history'),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${AppStrings.tr(lang, 'delivered')} & ${AppStrings.tr(lang, 'archived')}',
              style: const TextStyle(color: ArrivoColors.textMuted),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: historyItems.isEmpty
                  ? Center(
                      child: Text(
                        AppStrings.tr(lang, 'empty_title'),
                        style: const TextStyle(color: ArrivoColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: historyItems.length,
                      itemBuilder: (ctx, i) {
                        final pkg = historyItems[i];
                        return PackageTimelineCard(
                          package: pkg,
                          lang: lang,
                          onTap: () => onOpenDetails(pkg),
                          onMenuAction: (act) => onMenuAction(pkg, act),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. PACKAGE DETAILS SCREEN (Status Header, ETA, Full Timeline, Rename, Share, Archive, Delete)
class PackageDetailsScreen extends StatelessWidget {
  final PackageItem package;
  final String lang;
  final ValueChanged<PackageItem> onUpdatePackage;
  final VoidCallback onDeletePackage;

  const PackageDetailsScreen({
    super.key,
    required this.package,
    required this.lang,
    required this.onUpdatePackage,
    required this.onDeletePackage,
  });

  @override
  Widget build(BuildContext context) {
    final carrier = CarrierRegistry.byId(package.carrierId);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArrivoColors.primaryBlue,
        foregroundColor: Colors.white,
        title: Text(
          package.customName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              Share.share(
                'Arrivo Package: ${package.customName} (#${package.trackingNumber})\nCarrier: ${carrier.name}\nETA: ${package.eta}',
              );
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDeletePackage,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & ETA Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ArrivoColors.primaryBlue, ArrivoColors.deepBlue],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IsometricPackageBox(size: 58),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${package.trackingNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${carrier.name} • ${carrier.region}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Origin',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            package.origin,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.white70),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Destination',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            package.destination,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ETA: ${package.eta}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Quick Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(package.isArchived ? 'Unarchive' : 'Archive'),
                    onPressed: () {
                      onUpdatePackage(
                        package.copyWith(isArchived: !package.isArchived),
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArrivoColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      package.status == PackageStatus.delivered
                          ? 'In Transit'
                          : 'Mark Delivered',
                    ),
                    onPressed: () {
                      final nextStatus =
                          package.status == PackageStatus.delivered
                              ? PackageStatus.arrivingSoon
                              : PackageStatus.delivered;
                      onUpdatePackage(package.copyWith(status: nextStatus));
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Full Tracking Timeline',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),

            ...package.events.map(
              (ev) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF17223B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      ev.isCurrent
                          ? Icons.location_on_rounded
                          : Icons.check_circle_rounded,
                      color: ArrivoColors.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ev.location,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ArrivoColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ev.timestamp,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: ArrivoColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. BARCODE & QR CAMERA SCANNER SCREEN (mobile_scanner)
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Package Barcode / QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (BarcodeCapture capture) {
              if (_hasScanned) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.trim().isNotEmpty) {
                  _hasScanned = true;
                  Navigator.of(context).pop(raw.trim());
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: ArrivoColors.primaryBlue, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 9. SETTINGS & PROFILE SCREEN (Language RTL/LTR, Theme, Notifications, Plan, About)
class ProfileSettingsTab extends StatelessWidget {
  final String lang;
  final String themeMode;
  final bool notificationsEnabled;
  final bool isPremium;
  final int activeCount;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onOpenPaywall;
  final VoidCallback onShowAbout;

  const ProfileSettingsTab({
    super.key,
    required this.lang,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.isPremium,
    required this.activeCount,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.onOpenPaywall,
    required this.onShowAbout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
        children: [
          Text(
            AppStrings.tr(lang, 'settings'),
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),

          // Subscription Plan Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ArrivoColors.primaryBlue, ArrivoColors.deepBlue],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium
                      ? 'Arrivo Premium Plan (Unlimited)'
                      : 'Arrivo Free Plan ($activeCount / 5 Active Packages)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Unlock unlimited tracking, ad-free experience, and family sharing.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ArrivoColors.primaryBlue,
                  ),
                  onPressed: onOpenPaywall,
                  child: Text(
                    AppStrings.tr(lang, 'upgrade_premium'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Language Selector (English, French, Arabic with RTL)
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(
                Icons.language_rounded,
                color: ArrivoColors.primaryBlue,
              ),
              title: Text(AppStrings.tr(lang, 'language')),
              trailing: DropdownButton<String>(
                value: lang,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية (RTL)')),
                ],
                onChanged: (v) {
                  if (v != null) onLanguageChanged(v);
                },
              ),
            ),
          ),

          // Theme Mode Selector (Light, Dark, System)
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(
                Icons.palette_outlined,
                color: ArrivoColors.primaryBlue,
              ),
              title: Text(AppStrings.tr(lang, 'theme')),
              trailing: DropdownButton<String>(
                value: themeMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'system', child: Text('System')),
                ],
                onChanged: (v) {
                  if (v != null) onThemeChanged(v);
                },
              ),
            ),
          ),

          // Push Notification Toggle
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: SwitchListTile(
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: ArrivoColors.primaryBlue,
              ),
              title: Text(AppStrings.tr(lang, 'notifications')),
              value: notificationsEnabled,
              onChanged: onNotificationsChanged,
            ),
          ),

          // Test Notification Button
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(
                Icons.send_to_mobile_rounded,
                color: ArrivoColors.primaryBlue,
              ),
              title: Text(AppStrings.tr(lang, 'test_notification')),
              onTap: () {
                NotificationService.showNotification(
                  id: 999,
                  title: 'Arrivo Package Alert',
                  body: 'Your Wireless Headphones (#TRK123456789) are arriving soon!',
                );
              },
            ),
          ),

          // About Button
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: ArrivoColors.primaryBlue,
              ),
              title: Text(AppStrings.tr(lang, 'about')),
              onTap: onShowAbout,
            ),
          ),
        ],
      ),
    );
  }
}

/// 10. PREMIUM PAYWALL SCREEN (Free vs Premium Comparison + Placeholder Payment Button)
class PremiumPaywallScreen extends StatelessWidget {
  final bool isPremium;
  final int activeCount;
  final VoidCallback onUnlockDemoPremium;

  const PremiumPaywallScreen({
    super.key,
    required this.isPremium,
    required this.activeCount,
    required this.onUnlockDemoPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArrivoColors.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('Arrivo Premium'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ArrivoColors.primaryBlue, ArrivoColors.deepBlue],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amber,
                    size: 60,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPremium
                        ? 'You are on Arrivo Premium!'
                        : 'Free Plan Limit ($activeCount / 5 Active Packages)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upgrade to track unlimited packages across Algeria & worldwide with zero ads and family sharing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Comparison Table
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  _CompareRow(
                    feature: 'Active Packages',
                    freeVal: 'Up to 5',
                    proVal: 'Unlimited',
                  ),
                  Divider(),
                  _CompareRow(
                    feature: 'Local Algerian Carriers',
                    freeVal: 'Included',
                    proVal: 'Priority Sync',
                  ),
                  Divider(),
                  _CompareRow(
                    feature: 'Advertisements',
                    freeVal: 'Standard',
                    proVal: '100% Ad-Free',
                  ),
                  Divider(),
                  _CompareRow(
                    feature: 'Family Sharing',
                    freeVal: 'No',
                    proVal: 'Up to 5 Members',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Placeholder Payment Button (clearly labeled)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ArrivoColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text(
                  'Unlock Premium (Placeholder Demo - Free)',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
                onPressed: onUnlockDemoPremium,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Note: Real billing (Google Play Billing / BaridiMob / CIB) can be connected later. Tapping the button above unlocks Premium mode for free so you can test unlimited packages right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: ArrivoColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String feature;
  final String freeVal;
  final String proVal;

  const _CompareRow({
    required this.feature,
    required this.freeVal,
    required this.proVal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ArrivoColors.textDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              freeVal,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ArrivoColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              proVal,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: ArrivoColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
