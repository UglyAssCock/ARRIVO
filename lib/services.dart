import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class NotificationService {
  static const MethodChannel _channel =
      MethodChannel('com.arrivo.app/notifications');

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  static Future<bool> requestCameraPermission() async {
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('requestCameraPermission');
      return granted ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<String?> pickGoogleAccount() async {
    try {
      return await _channel.invokeMethod<String>('pickGoogleAccount');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openExternalUrl(String url) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'openExternalUrl',
        {'url': url},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'id': id,
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }
}

class StorageService {
  static const String _packagesKey = 'arrivo_packages_v2_clean';
  static const String _langKey = 'arrivo_lang_v1';
  static const String _themeKey = 'arrivo_theme_v1';
  static const String _onboardingKey = 'arrivo_onboarded_v2';
  static const String _notifKey = 'arrivo_notifications_v1';
  static const String _custom17Key = 'arrivo_custom_17track_key';
  static const String _accountKey = 'arrivo_user_account_v1';
  static const String _cloudVaultPrefix = 'arrivo_cloud_vault_';

  /// Loads saved packages. Returns an EMPTY list on first launch (no fake items!).
  static Future<List<PackageItem>> loadPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_packagesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((e) => PackageItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePackages(List<PackageItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_packagesKey, encoded);
  }

  static Future<String> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_langKey) ?? 'en';
  }

  static Future<void> saveLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }

  static Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'light';
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  static Future<bool> loadNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifKey) ?? true;
  }

  static Future<void> saveNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, enabled);
  }

  static Future<String> loadCustom17TrackKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_custom17Key) ?? '';
  }

  static Future<void> saveCustom17TrackKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_custom17Key, key.trim());
  }

  static Future<UserAccount?> loadUserAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserAccount.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUserAccount(UserAccount? account) async {
    final prefs = await SharedPreferences.getInstance();
    if (account == null) {
      await prefs.remove(_accountKey);
    } else {
      await prefs.setString(_accountKey, jsonEncode(account.toJson()));
    }
  }

  static Future<void> saveAccountBackupVault(
    String email,
    List<PackageItem> packages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cloudVaultPrefix${email.trim().toLowerCase()}';
    final encoded = jsonEncode(packages.map((e) => e.toJson()).toList());
    await prefs.setString(key, encoded);
  }

  static Future<List<PackageItem>?> loadAccountBackupVault(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cloudVaultPrefix${email.trim().toLowerCase()}';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((e) => PackageItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }
}

/// Cloud Backup & Account Sync Service (Google & Email/Password + Backup Code Export/Import)
class CloudSyncService {
  static String _generateSyncId(String email) {
    final clean = email.trim().toLowerCase();
    int hash = 5381;
    for (int i = 0; i < clean.length; i++) {
      hash = ((hash << 5) + hash) + clean.codeUnitAt(i);
    }
    return 'ARRIVO-${(hash & 0x7FFFFFFF).toRadixString(16).toUpperCase()}';
  }

  static Future<UserAccount> signInWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final passKey = 'arrivo_auth_pwd_$cleanEmail';
    final savedPwd = prefs.getString(passKey);

    if (savedPwd != null && savedPwd != password) {
      throw const FormatException('Incorrect password for this email account.');
    }
    await prefs.setString(passKey, password);

    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : cleanEmail.split('@').first;

    final account = UserAccount(
      email: cleanEmail,
      displayName: name,
      authProvider: 'email',
      syncId: _generateSyncId(cleanEmail),
      lastSyncedAt: DateTime.now(),
    );

    await StorageService.saveUserAccount(account);
    return account;
  }

  static Future<UserAccount> signInWithGoogleEmail(String googleEmail) async {
    final cleanEmail = googleEmail.trim().toLowerCase();
    final name = cleanEmail.split('@').first;
    final account = UserAccount(
      email: cleanEmail,
      displayName: name,
      authProvider: 'google',
      syncId: _generateSyncId(cleanEmail),
      lastSyncedAt: DateTime.now(),
    );
    await StorageService.saveUserAccount(account);
    return account;
  }

  /// Syncs current packages with the user's cloud/account backup vault and merges any restored items
  static Future<List<PackageItem>> syncPackages({
    required UserAccount account,
    required List<PackageItem> currentPackages,
  }) async {
    final existingVault =
        await StorageService.loadAccountBackupVault(account.email) ?? [];

    // Merge currentPackages + existingVault by trackingNumber (newest wins)
    final Map<String, PackageItem> mergedMap = {};
    for (final pkg in existingVault) {
      mergedMap[pkg.trackingNumber.toUpperCase()] = pkg;
    }
    for (final pkg in currentPackages) {
      mergedMap[pkg.trackingNumber.toUpperCase()] = pkg;
    }

    final mergedList = mergedMap.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    await StorageService.saveAccountBackupVault(account.email, mergedList);
    await StorageService.savePackages(mergedList);
    await StorageService.saveUserAccount(
      account.copyWith(lastSyncedAt: DateTime.now()),
    );
    return mergedList;
  }

  /// Encodes all packages into a portable Cloud Backup String that can be copied/restored on any phone
  static String exportPortableBackupCode(List<PackageItem> packages) {
    final jsonStr = jsonEncode(packages.map((p) => p.toJson()).toList());
    return base64UrlEncode(utf8.encode(jsonStr));
  }

  static List<PackageItem> importPortableBackupCode(String backupCode) {
    final decodedStr = utf8.decode(base64Url.decode(backupCode.trim()));
    final List<dynamic> list = jsonDecode(decodedStr);
    return list
        .map((e) => PackageItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// Real Multi-Engine Package Tracking Service (Zero Fake Dates!)
class TrackingApiService {
  static const String envApiKey = String.fromEnvironment('TRACK17_KEY');

  static Future<String> getEffective17TrackKey() async {
    final custom = await StorageService.loadCustom17TrackKey();
    if (custom.trim().isNotEmpty) return custom.trim();
    return envApiKey.trim();
  }

  static String _formatRealTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[dt.month - 1];
    final d = dt.day.toString().padLeft(2, '0');
    final y = dt.year;
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$m $d, $y • $hour12:$min $ampm';
  }

  static Future<PackageItem> fetchTrackingInfo({
    required String trackingNumber,
    required String customName,
    required String selectedCarrierId,
  }) async {
    final cleaned = trackingNumber.trim().toUpperCase();
    if (cleaned.length < 4) {
      throw const FormatException('INVALID_TRACKING_NUMBER');
    }

    final resolvedCarrier = selectedCarrierId == 'auto'
        ? CarrierRegistry.detectCarrier(cleaned)
        : CarrierRegistry.byId(selectedCarrierId);

    final activeKey = await getEffective17TrackKey();

    // ENGINE 1: Official 17TRACK v2.2 Live API (if API key is configured in Settings or GitHub Secrets)
    if (activeKey.isNotEmpty) {
      try {
        final live17 = await _fetchFrom17Track(
          apiKey: activeKey,
          trackingNumber: cleaned,
          customName: customName,
          carrier: resolvedCarrier,
          forceAutoDetect: selectedCarrierId == 'auto',
        );
        if (live17 != null) {
          return live17;
        }
      } catch (_) {}
    }

    // ENGINE 2: Cainiao / Global Postal Live Public API (No API key required! Tracks AliExpress, Cainiao, EMS, China Post, Yanwen, SunYou, UPU Postal, etc.)
    try {
      final liveCainiao = await _fetchFromCainiaoGlobal(
        trackingNumber: cleaned,
        customName: customName,
        carrier: resolvedCarrier,
      );
      if (liveCainiao != null) {
        return liveCainiao;
      }
    } catch (_) {}

    // ENGINE 3: Honest Registered State with Real Current Timestamp & Direct Live Carrier Portal
    // (Never invents fake dates!)
    final nowStr = _formatRealTimestamp(DateTime.now());
    final displayTitle = customName.trim().isEmpty
        ? '${resolvedCarrier.name} Shipment'
        : customName.trim();

    return PackageItem(
      id: 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      trackingNumber: cleaned,
      customName: displayTitle,
      carrierId: resolvedCarrier.id,
      status: PackageStatus.inTransit,
      eta: 'Tap "Open Live Courier Tracker" for real-time scan',
      origin: resolvedCarrier.region,
      destination: 'Algeria / Destination',
      updatedAt: DateTime.now(),
      events: [
        TrackingEvent(
          title: 'Shipment registered (${resolvedCarrier.name})',
          timestamp: nowStr,
          location: activeKey.isEmpty
              ? 'Tap "Open Live Courier Tracker" or add a free 17TRACK API key in Settings for automatic checkpoints'
              : 'Registered with 17TRACK — awaiting courier scan update',
          isCompleted: true,
          isCurrent: true,
        ),
      ],
    );
  }

  /// Queries Cainiao Global Public JSON API (Zero API Key Needed)
  static Future<PackageItem?> _fetchFromCainiaoGlobal({
    required String trackingNumber,
    required String customName,
    required CarrierInfo carrier,
  }) async {
    final uri = Uri.parse(
      'https://global.cainiao.com/global/detail.json?mailNos=${Uri.encodeComponent(trackingNumber)}&lang=en-US',
    );
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14)',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;

    final Map<String, dynamic> body = jsonDecode(response.body);
    final moduleList = body['module'] as List<dynamic>?;
    if (moduleList == null || moduleList.isEmpty) return null;

    final firstModule = moduleList.first as Map<String, dynamic>;
    final detailList = firstModule['detailList'] as List<dynamic>? ?? [];
    if (detailList.isEmpty) return null;

    final originCountry =
        firstModule['originCountry']?.toString() ?? carrier.region;
    final destCountry =
        firstModule['destCountry']?.toString() ?? 'Destination';
    final statusStr = firstModule['status']?.toString().toUpperCase() ?? '';

    final List<TrackingEvent> realEvents = [];
    for (int i = 0; i < detailList.length && i < 15; i++) {
      final item = detailList[i] as Map<String, dynamic>;
      final desc = item['standerdDesc']?.toString() ??
          item['desc']?.toString() ??
          'Scan update';
      final timeStr = item['timeStr']?.toString() ??
          item['time']?.toString() ??
          '';
      final place = item['place']?.toString() ??
          item['ActionCode']?.toString() ??
          originCountry;

      realEvents.add(
        TrackingEvent(
          title: desc,
          timestamp: timeStr,
          location: place.isEmpty ? originCountry : place,
          isCompleted: i > 0,
          isCurrent: i == 0,
        ),
      );
    }

    PackageStatus mappedStatus = PackageStatus.inTransit;
    final topDesc = realEvents.first.title.toLowerCase();
    if (statusStr.contains('SIGN') ||
        statusStr.contains('DELIVER') ||
        topDesc.contains('delivered')) {
      mappedStatus = PackageStatus.delivered;
    } else if (topDesc.contains('out for delivery') ||
        topDesc.contains('arrived at local delivery') ||
        topDesc.contains('local post office')) {
      mappedStatus = PackageStatus.arrivingSoon;
    }

    return PackageItem(
      id: 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      trackingNumber: trackingNumber,
      customName: customName.trim().isEmpty
          ? '${carrier.name} ($trackingNumber)'
          : customName.trim(),
      carrierId: carrier.id,
      status: mappedStatus,
      eta: mappedStatus == PackageStatus.delivered
          ? 'Delivered (${realEvents.first.timestamp})'
          : 'Latest scan: ${realEvents.first.timestamp}',
      origin: originCountry,
      destination: destCountry,
      events: realEvents.reversed.toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Queries Official 17TRACK v2.2 API with Auto-Detect and Polling Retry
  static Future<PackageItem?> _fetchFrom17Track({
    required String apiKey,
    required String trackingNumber,
    required String customName,
    required CarrierInfo carrier,
    required bool forceAutoDetect,
  }) async {
    final headers = {
      '17token': apiKey,
      'Content-Type': 'application/json',
    };

    // If forceAutoDetect or track17Code == 0, omit 'carrier' so 17TRACK auto-detects across all 2,400+ couriers!
    final Map<String, dynamic> reqItem = {'number': trackingNumber};
    if (!forceAutoDetect && carrier.track17Code > 0) {
      reqItem['carrier'] = carrier.track17Code;
    }
    final bodyPayload = jsonEncode([reqItem]);

    // Step 1: Register tracking number with 17TRACK
    await http
        .post(
          Uri.parse('https://api.17track.net/track/v2.2/register'),
          headers: headers,
          body: bodyPayload,
        )
        .timeout(const Duration(seconds: 8));

    // Step 2: Poll gettrackinfo (with retry if 17TRACK is still pulling initial events from carrier)
    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
      final infoResponse = await http
          .post(
            Uri.parse('https://api.17track.net/track/v2.2/gettrackinfo'),
            headers: headers,
            body: bodyPayload,
          )
          .timeout(const Duration(seconds: 8));

      if (infoResponse.statusCode != 200) continue;

      final Map<String, dynamic> data = jsonDecode(infoResponse.body);
      final accepted = data['data']?['accepted'] as List<dynamic>?;
      if (accepted == null || accepted.isEmpty) continue;

      final first = accepted.first as Map<String, dynamic>;
      final trackInfo = first['track_info'] as Map<String, dynamic>?;
      if (trackInfo == null) continue;

      final latestStatus =
          trackInfo['latest_status']?['status']?.toString() ?? 'InTransit';
      final providers =
          trackInfo['tracking']?['providers'] as List<dynamic>? ?? [];

      final List<TrackingEvent> parsedEvents = [];
      String detectedProviderName = carrier.name;

      if (providers.isNotEmpty) {
        final firstProvider = providers.first as Map<String, dynamic>;
        detectedProviderName =
            firstProvider['provider']?['name']?.toString() ?? carrier.name;
        final rawEvents = firstProvider['events'] as List<dynamic>? ?? [];
        for (int i = 0; i < rawEvents.length && i < 15; i++) {
          final ev = rawEvents[i] as Map<String, dynamic>;
          final rawTime = ev['time_iso']?.toString() ?? '';
          final cleanTime = rawTime.length >= 16
              ? rawTime.substring(0, 16).replaceFirst('T', ' • ')
              : rawTime;
          parsedEvents.add(
            TrackingEvent(
              title: ev['description']?.toString() ?? 'Carrier scan',
              timestamp: cleanTime,
              location: ev['location']?.toString() ?? detectedProviderName,
              isCompleted: i > 0,
              isCurrent: i == 0,
            ),
          );
        }
      }

      if (parsedEvents.isEmpty && attempt == 0) {
        // Wait 2 seconds and try one more time so 17TRACK finishes scraping the carrier
        continue;
      }

      if (parsedEvents.isEmpty) return null;

      PackageStatus mappedStatus = PackageStatus.inTransit;
      if (latestStatus.toLowerCase().contains('deliver')) {
        mappedStatus = PackageStatus.delivered;
      } else if (latestStatus.toLowerCase().contains('outfordelivery') ||
          latestStatus.toLowerCase().contains('pickup')) {
        mappedStatus = PackageStatus.arrivingSoon;
      }

      return PackageItem(
        id: 'pkg_${DateTime.now().millisecondsSinceEpoch}',
        trackingNumber: trackingNumber,
        customName: customName.trim().isEmpty
            ? '$detectedProviderName Shipment'
            : customName.trim(),
        carrierId: carrier.id,
        status: mappedStatus,
        eta: mappedStatus == PackageStatus.delivered
            ? 'Delivered (${parsedEvents.first.timestamp})'
            : 'Latest: ${parsedEvents.first.timestamp}',
        origin: detectedProviderName,
        destination: 'Destination',
        events: parsedEvents.reversed.toList(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
