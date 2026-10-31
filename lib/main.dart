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
  UserAccount? _userAccount;
  String _lang = 'en';
  String _themeMode = 'light';
  bool _onboardingDone = true;
  bool _notificationsEnabled = true;
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
      _refreshActivePackagesSilently();
    }
  }

  Future<void> _initializeApp() async {
    final pkgs = await StorageService.loadPackages();
    final lang = await StorageService.loadLanguage();
    final theme = await StorageService.loadThemeMode();
    final onboarded = await StorageService.isOnboardingComplete();
    final notif = await StorageService.loadNotificationsEnabled();
    final account = await StorageService.loadUserAccount();

    if (mounted) {
      setState(() {
        _packages = pkgs;
        _lang = lang;
        _themeMode = theme;
        _onboardingDone = onboarded;
        _notificationsEnabled = notif;
        _userAccount = account;
        _isLoading = false;
      });
    }

    await NotificationService.requestPermission();

    _backgroundTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _refreshActivePackagesSilently();
    });
  }

  Future<void> _refreshActivePackagesSilently() async {
    if (_packages.isEmpty) return;
    final List<PackageItem> updatedList = [];
    bool changed = false;

    for (final pkg in _packages) {
      if (pkg.isArchived || pkg.status == PackageStatus.delivered) {
        updatedList.add(pkg);
        continue;
      }
      try {
        final refreshed = await TrackingApiService.fetchTrackingInfo(
          trackingNumber: pkg.trackingNumber,
          customName: pkg.customName,
          selectedCarrierId: pkg.carrierId,
        );
        if (refreshed.events.length != pkg.events.length ||
            refreshed.status != pkg.status) {
          changed = true;
          if (_notificationsEnabled) {
            await NotificationService.showNotification(
              id: pkg.trackingNumber.hashCode,
              title: 'Update: ${pkg.customName}',
              body: refreshed.events.last.title,
            );
          }
        }
        updatedList.add(refreshed.copyWith(customName: pkg.customName));
      } catch (_) {
        updatedList.add(pkg);
      }
    }

    if (changed && mounted) {
      await _savePackagesList(updatedList);
    }
  }

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

  Future<void> _savePackagesList(List<PackageItem> updated) async {
    setState(() => _packages = updated);
    await StorageService.savePackages(updated);
    if (_userAccount != null) {
      await StorageService.saveAccountBackupVault(
        _userAccount!.email,
        updated,
      );
      final updatedAcc =
          _userAccount!.copyWith(lastSyncedAt: DateTime.now());
      setState(() => _userAccount = updatedAcc);
      await StorageService.saveUserAccount(updatedAcc);
    }
  }

  Future<void> _handleAccountSignedIn(UserAccount account) async {
    final syncedPackages = await CloudSyncService.syncPackages(
      account: account,
      currentPackages: _packages,
    );
    setState(() {
      _userAccount = account.copyWith(lastSyncedAt: DateTime.now());
      _packages = syncedPackages;
    });
  }

  Future<void> _handleSignOut() async {
    await StorageService.saveUserAccount(null);
    setState(() => _userAccount = null);
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
                  userAccount: _userAccount,
                  lang: _lang,
                  themeMode: _themeMode,
                  notificationsEnabled: _notificationsEnabled,
                  onPackagesChanged: _savePackagesList,
                  onLanguageChanged: _updateLanguage,
                  onThemeChanged: _updateTheme,
                  onNotificationsChanged: _updateNotifications,
                  onAccountSignedIn: _handleAccountSignedIn,
                  onSignOut: _handleSignOut,
                ),
    );
  }
}

/// ONBOARDING SCREEN
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
        Icons.cloud_done_rounded,
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
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.$3,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 15.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
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

/// MAIN NAVIGATION SHELL
class MainNavigationShell extends StatefulWidget {
  final List<PackageItem> packages;
  final UserAccount? userAccount;
  final String lang;
  final String themeMode;
  final bool notificationsEnabled;
  final ValueChanged<List<PackageItem>> onPackagesChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<UserAccount> onAccountSignedIn;
  final VoidCallback onSignOut;

  const MainNavigationShell({
    super.key,
    required this.packages,
    required this.userAccount,
    required this.lang,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.onPackagesChanged,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.onAccountSignedIn,
    required this.onSignOut,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;
  bool _isAddingLoading = false;
  final TextEditingController _homeSearchCtrl = TextEditingController();

  Future<void> _openBarcodeScanner({bool autoTrack = true}) async {
    final granted = await NotificationService.requestCameraPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera permission is required to scan barcodes. Please allow Camera access.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tr(widget.lang, 'add_package'),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: numberCtrl,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        labelText: AppStrings.tr(widget.lang, 'search_hint'),
                        hintText: 'Enter any tracking number...',
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
                                final ok = await NotificationService
                                    .requestCameraPermission();
                                if (!ok || !ctx.mounted) return;
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
                          Expanded(
                            child: Text(
                              'Auto-detected: ${detected.name} (${detected.region})',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: ArrivoColors.primaryBlue,
                              ),
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
                      isExpanded: true,
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
                              child: Text(
                                '${c.name} (${c.region})',
                                overflow: TextOverflow.ellipsis,
                              ),
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
    setState(() => _isAddingLoading = true);

    try {
      final newPkg = await TrackingApiService.fetchTrackingInfo(
        trackingNumber: trackingNumber,
        customName: customName,
        selectedCarrierId: carrierId,
      );

      final filtered = widget.packages
          .where((p) =>
              p.trackingNumber.toUpperCase() !=
              newPkg.trackingNumber.toUpperCase())
          .toList();
      final updated = [newPkg, ...filtered];
      widget.onPackagesChanged(updated);

      if (widget.notificationsEnabled) {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          title: 'Tracking: ${newPkg.customName}',
          body: '#${newPkg.trackingNumber} • ${newPkg.events.last.title}',
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr(widget.lang, 'not_found_desc')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingLoading = false);
      }
    }
  }

  Future<void> _refreshSinglePackage(PackageItem pkg) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Refreshing #${pkg.trackingNumber}...')),
    );
    try {
      final refreshed = await TrackingApiService.fetchTrackingInfo(
        trackingNumber: pkg.trackingNumber,
        customName: pkg.customName,
        selectedCarrierId: pkg.carrierId,
      );
      final updated = widget.packages
          .map((p) => p.id == pkg.id
              ? refreshed.copyWith(customName: pkg.customName)
              : p)
          .toList();
      widget.onPackagesChanged(updated);
    } catch (_) {}
  }

  void _openLiveCourierWeb(PackageItem pkg) {
    final carrier = CarrierRegistry.byId(pkg.carrierId);
    final url = carrier.buildLiveTrackingUrl(pkg.trackingNumber);
    NotificationService.openExternalUrl(url);
  }

  void _handleCardMenuAction(PackageItem pkg, String action) {
    if (action == 'refresh') {
      _refreshSinglePackage(pkg);
    } else if (action == 'live_web') {
      _openLiveCourierWeb(pkg);
    } else if (action == 'rename') {
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
        'Arrivo Package Tracking:\n${pkg.customName} (#${pkg.trackingNumber})\nStatus: ${pkg.status.name}\nLatest: ${pkg.events.isNotEmpty ? pkg.events.last.title : pkg.eta}',
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
          onRefreshLive: () => _refreshSinglePackage(pkg),
          onOpenLiveWeb: () => _openLiveCourierWeb(pkg),
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arrivo v2.0.0 (com.arrivo.app)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Live tracking for 2,400+ local Algerian & global couriers including Yalidine, ZR Express, Maystro, Guepex, Algérie Poste/EMS, Cainiao/AliExpress, DHL, UPS, FedEx, Aramex, Temu, and Shein.\n\nIncludes Google & Email Account Sync and Barcode Scanner.',
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
          _buildHomeScreen(activePackages),
          TrackPackagesTab(
            packages: activePackages,
            lang: widget.lang,
            onOpenDetails: _openPackageDetails,
            onMenuAction: _handleCardMenuAction,
          ),
          HistoryPackagesTab(
            packages: widget.packages,
            lang: widget.lang,
            onOpenDetails: _openPackageDetails,
            onMenuAction: _handleCardMenuAction,
          ),
          ProfileSettingsTab(
            userAccount: widget.userAccount,
            packages: widget.packages,
            lang: widget.lang,
            themeMode: widget.themeMode,
            notificationsEnabled: widget.notificationsEnabled,
            onLanguageChanged: widget.onLanguageChanged,
            onThemeChanged: widget.onThemeChanged,
            onNotificationsChanged: widget.onNotificationsChanged,
            onAccountSignedIn: widget.onAccountSignedIn,
            onSignOut: widget.onSignOut,
            onPackagesRestored: widget.onPackagesChanged,
            onShowAbout: _showAboutDialog,
          ),
        ],
      ),
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
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHomeScreen(List<PackageItem> activePackages) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                            // Cloud Sync Status Button + Notification Bell
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedIndex = 3),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF002B8F)
                                          .withOpacity(0.75),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.18),
                                      ),
                                    ),
                                    child: Icon(
                                      widget.userAccount != null
                                          ? Icons.cloud_done_rounded
                                          : Icons.cloud_upload_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                     _openAddPackageDialog();
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
                                            color:
                                                Colors.white.withOpacity(0.18),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.notifications_none_rounded,
                                          color: Colors.white,
                                          size: 25,
                                        ),
                                      ),
                                      if (activePackages.isNotEmpty)
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
                          ],
                        ),
                        const SizedBox(height: 4),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17223B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const IsometricPackageBox(size: 72),
          const SizedBox(height: 14),
          Text(
            AppStrings.tr(widget.lang, 'empty_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ArrivoColors.textDark,
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

/// PACKAGE LIST SCREEN WITH TABS & SEARCH
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
  int _tab = 0;
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

/// HISTORY SCREEN
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

/// PACKAGE DETAILS SCREEN WITH LIVE COURIER VERIFICATION & REFRESH
class PackageDetailsScreen extends StatelessWidget {
  final PackageItem package;
  final String lang;
  final VoidCallback onRefreshLive;
  final VoidCallback onOpenLiveWeb;
  final ValueChanged<PackageItem> onUpdatePackage;
  final VoidCallback onDeletePackage;

  const PackageDetailsScreen({
    super.key,
    required this.package,
    required this.lang,
    required this.onRefreshLive,
    required this.onOpenLiveWeb,
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
            tooltip: 'Refresh Live Status',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRefreshLive,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              Share.share(
                'Arrivo Package: ${package.customName} (#${package.trackingNumber})\nCourier: ${carrier.name}\nLatest: ${package.events.isNotEmpty ? package.events.last.title : package.eta}',
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
                            SelectableText(
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ArrivoColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        'Open Live Courier Tracker (${carrier.name})',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: onOpenLiveWeb,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
                          ? 'Mark In Transit'
                          : 'Mark Delivered',
                    ),
                    onPressed: () {
                      final nextStatus =
                          package.status == PackageStatus.delivered
                              ? PackageStatus.inTransit
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
              'Live Tracking Checkpoints',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...package.events.reversed.map(
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
                              fontSize: 15,
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

/// FIXED CAMERA BARCODE & QR SCANNER SCREEN
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _scannerController;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _manualInputFallback() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Barcode Manually'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Tracking number...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = ctrl.text.trim();
              Navigator.of(ctx).pop();
              if (code.isNotEmpty) {
                Navigator.of(context).pop(code);
              }
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
            tooltip: 'Toggle Flashlight',
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch Camera',
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => _scannerController.switchCamera(),
          ),
          IconButton(
            tooltip: 'Type Manually',
            icon: const Icon(Icons.keyboard_rounded),
            onPressed: _manualInputFallback,
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
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(raw.trim());
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 280,
              height: 190,
              decoration: BoxDecoration(
                border: Border.all(color: ArrivoColors.primaryBlue, width: 3.5),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Positioned(
            bottom: 42,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Align the shipping barcode or QR code inside the blue frame',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// PROFILE, GOOGLE/EMAIL ACCOUNT SYNC & SETTINGS SCREEN
class ProfileSettingsTab extends StatefulWidget {
  final UserAccount? userAccount;
  final List<PackageItem> packages;
  final String lang;
  final String themeMode;
  final bool notificationsEnabled;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<UserAccount> onAccountSignedIn;
  final VoidCallback onSignOut;
  final ValueChanged<List<PackageItem>> onPackagesRestored;
  final VoidCallback onShowAbout;

  const ProfileSettingsTab({
    super.key,
    required this.userAccount,
    required this.packages,
    required this.lang,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.onAccountSignedIn,
    required this.onSignOut,
    required this.onPackagesRestored,
    required this.onShowAbout,
  });

  @override
  State<ProfileSettingsTab> createState() => _ProfileSettingsTabState();
}

class _ProfileSettingsTabState extends State<ProfileSettingsTab> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  String _custom17Key = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final k = await StorageService.loadCustom17TrackKey();
    if (mounted) setState(() => _custom17Key = k);
  }

  Future<void> _handleGoogleSignIn() async {
    // Try native Android Google Account Picker first
    String? pickedEmail = await NotificationService.pickGoogleAccount();
    if (pickedEmail == null || pickedEmail.trim().isEmpty) {
      if (!mounted) return;
      pickedEmail = await _promptGoogleEmailFallback();
    }
    if (pickedEmail != null && pickedEmail.trim().isNotEmpty) {
      final acc =
          await CloudSyncService.signInWithGoogleEmail(pickedEmail.trim());
      widget.onAccountSignedIn(acc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Signed in with Google (${acc.email}) & synced packages!',
            ),
          ),
        );
      }
    }
  }

  Future<String?> _promptGoogleEmailFallback() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_circle_rounded, color: ArrivoColors.primaryBlue),
            SizedBox(width: 8),
            Text('Sign in with Google'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Your Google / Gmail Address',
            hintText: 'yourname@gmail.com',
          ),
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
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _openEmailAuthDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Sign In / Create Account',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
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
            onPressed: () async {
              final email = _emailCtrl.text.trim();
              final pwd = _passwordCtrl.text.trim();
              if (email.isEmpty || !email.contains('@') || pwd.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter a valid email and password (4+ chars).',
                    ),
                  ),
                );
                return;
              }
              try {
                final acc = await CloudSyncService.signInWithEmail(
                  email: email,
                  password: pwd,
                  displayName: _nameCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                widget.onAccountSignedIn(acc);
              } on FormatException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              }
            },
            child: const Text('Sign In & Sync'),
          ),
        ],
      ),
    );
  }

  void _openPortableBackupDialog() {
    final backupCode =
        CloudSyncService.exportPortableBackupCode(widget.packages);
    final importCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cloud Backup & Restore Code'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Copy your encrypted backup code to save or transfer all your packages to another phone:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      backupCode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ArrivoColors.primaryBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: backupCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup code copied!')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Or paste a backup code below to restore packages:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: importCtrl,
                decoration: const InputDecoration(
                  hintText: 'Paste backup code here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final restored = CloudSyncService.importPortableBackupCode(
                  importCtrl.text,
                );
                widget.onPackagesRestored(restored);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Restored ${restored.length} packages successfully!',
                    ),
                  ),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid backup code.')),
                );
              }
            },
            child: const Text('Restore Packages'),
          ),
        ],
      ),
    );
  }

  void _openApiKeyDialog() {
    final ctrl = TextEditingController(text: _custom17Key);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('17TRACK Live API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your free 17TRACK API key to enable automatic background checkpoints for all 2,400+ couriers (or leave blank to use Cainiao Global & Direct Live Courier tracking):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: '17TRACK API Token',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await StorageService.saveCustom17TrackKey(ctrl.text);
              await _loadApiKey();
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('17TRACK API Key saved!')),
                );
              }
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acc = widget.userAccount;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
        children: [
          Text(
            AppStrings.tr(widget.lang, 'profile'),
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),

          // GOOGLE & EMAIL ACCOUNT BACKUP / SYNC CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ArrivoColors.primaryBlue, ArrivoColors.deepBlue],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: acc == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_upload_rounded,
                              color: Colors.white, size: 30),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Backup & Sync Your Packages',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in with Google or Email to automatically save, backup, and sync all your tracking numbers.',
                        style: TextStyle(color: Colors.white70, fontSize: 13.5),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ArrivoColors.textDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 28,
                            color: ArrivoColors.primaryBlue,
                          ),
                          label: const Text(
                            'Continue with Google',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onPressed: _handleGoogleSignIn,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.email_outlined),
                          label: const Text(
                            'Sign in with Email & Password',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: _openEmailAuthDialog,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            child: Text(
                              acc.displayName.isNotEmpty
                                  ? acc.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: ArrivoColors.primaryBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acc.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  acc.email,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sign Out',
                            icon: const Icon(Icons.logout_rounded,
                                color: Colors.white),
                            onPressed: widget.onSignOut,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cloud ID: ${acc.syncId} (${widget.packages.length} saved)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Icon(Icons.cloud_done_rounded,
                                color: Colors.greenAccent, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: ArrivoColors.primaryBlue,
                              ),
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text(
                                'Backup & Sync Now',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              onPressed: () => widget.onAccountSignedIn(acc),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 16),

          // Cloud Backup Code Export / Import
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(
                Icons.settings_backup_restore_rounded,
                color: ArrivoColors.primaryBlue,
              ),
              title: const Text('Export / Restore Cloud Backup Code'),
              subtitle:
                  const Text('Transfer your packages across phones anytime'),
              onTap: _openPortableBackupDialog,
            ),
          ),

          // In-App 17TRACK API Key Configuration
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(
                Icons.vpn_key_rounded,
                color: ArrivoColors.primaryBlue,
              ),
              title: const Text('17TRACK Live API Key (2,400+ Couriers)'),
              subtitle: Text(
                _custom17Key.isNotEmpty ||
                        TrackingApiService.envApiKey.isNotEmpty
                    ? 'Connected & Active'
                    : 'Tap to paste your free 17TRACK API key',
              ),
              onTap: _openApiKeyDialog,
            ),
          ),

          // Language Selector
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(
                Icons.language_rounded,
                color: ArrivoColors.primaryBlue,
              ),
              title: Text(AppStrings.tr(widget.lang, 'language')),
              trailing: DropdownButton<String>(
                value: widget.lang,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية (RTL)')),
                ],
                onChanged: (v) {
                  if (v != null) widget.onLanguageChanged(v);
                },
              ),
            ),
          ),

          // Theme Mode Selector
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(
                Icons.palette_outlined,
                color: ArrivoColors.primaryBlue,
              ),
              title: Text(AppStrings.tr(widget.lang, 'theme')),
              trailing: DropdownButton<String>(
                value: widget.themeMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'system', child: Text('System')),
                ],
                onChanged: (v) {
                  if (v != null) widget.onThemeChanged(v);
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
              title: Text(AppStrings.tr(widget.lang, 'notifications')),
              value: widget.notificationsEnabled,
              onChanged: widget.onNotificationsChanged,
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
              title: Text(AppStrings.tr(widget.lang, 'about')),
              onTap: widget.onShowAbout,
            ),
          ),
        ],
      ),
    );
  }
}
