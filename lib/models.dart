import 'package:flutter/material.dart';

enum PackageStatus {
  pickedUp,
  inTransit,
  arrivingSoon,
  delivered,
  notFound,
}

class UserAccount {
  final String email;
  final String displayName;
  final String authProvider; // 'google' or 'email'
  final String syncId;
  final DateTime lastSyncedAt;

  const UserAccount({
    required this.email,
    required this.displayName,
    required this.authProvider,
    required this.syncId,
    required this.lastSyncedAt,
  });

  UserAccount copyWith({DateTime? lastSyncedAt}) {
    return UserAccount(
      email: email,
      displayName: displayName,
      authProvider: authProvider,
      syncId: syncId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'authProvider': authProvider,
        'syncId': syncId,
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        email: json['email'] ?? '',
        displayName: json['displayName'] ?? 'User',
        authProvider: json['authProvider'] ?? 'email',
        syncId: json['syncId'] ?? '',
        lastSyncedAt:
            DateTime.tryParse(json['lastSyncedAt'] ?? '') ?? DateTime.now(),
      );
}

class TrackingEvent {
  final String title;
  final String timestamp;
  final String location;
  final bool isCompleted;
  final bool isCurrent;

  const TrackingEvent({
    required this.title,
    required this.timestamp,
    required this.location,
    this.isCompleted = true,
    this.isCurrent = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'timestamp': timestamp,
        'location': location,
        'isCompleted': isCompleted,
        'isCurrent': isCurrent,
      };

  factory TrackingEvent.fromJson(Map<String, dynamic> json) => TrackingEvent(
        title: json['title'] ?? '',
        timestamp: json['timestamp'] ?? '',
        location: json['location'] ?? '',
        isCompleted: json['isCompleted'] ?? true,
        isCurrent: json['isCurrent'] ?? false,
      );
}

class CarrierInfo {
  final String id;
  final String name;
  final int track17Code;
  final String region;
  final String trackingUrlTemplate;

  const CarrierInfo({
    required this.id,
    required this.name,
    required this.track17Code,
    required this.region,
    required this.trackingUrlTemplate,
  });

  String buildLiveTrackingUrl(String trackingNumber) {
    final clean = Uri.encodeComponent(trackingNumber.trim());
    return trackingUrlTemplate.replaceAll('{num}', clean);
  }
}

class CarrierRegistry {
  static const List<CarrierInfo> carriers = [
    CarrierInfo(
      id: 'auto',
      name: 'Auto-Detect (All 2,400+ Couriers)',
      track17Code: 0,
      region: 'Worldwide & Local',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    // Algerian Local & National Couriers
    CarrierInfo(
      id: 'yalidine',
      name: 'Yalidine Express',
      track17Code: 100592,
      region: 'Algeria',
      trackingUrlTemplate: 'https://yalidine.com/suivre-un-colis/?tracking={num}',
    ),
    CarrierInfo(
      id: 'zrexpress',
      name: 'ZR Express',
      track17Code: 100791,
      region: 'Algeria',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'maystro',
      name: 'Maystro Delivery',
      track17Code: 0,
      region: 'Algeria',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'guepex',
      name: 'Guepex Express',
      track17Code: 0,
      region: 'Algeria',
      trackingUrlTemplate: 'https://guepex.com/suivre-un-colis/?tracking={num}',
    ),
    CarrierInfo(
      id: 'noest',
      name: 'Nord et Ouest Express (NOEST)',
      track17Code: 0,
      region: 'Algeria',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'algerie_poste',
      name: 'Algérie Poste / EMS Champion Post',
      track17Code: 3011,
      region: 'Algeria & International',
      trackingUrlTemplate: 'https://www.ems.dz/track/?tracking={num}',
    ),
    // E-Commerce & Asian Logistics
    CarrierInfo(
      id: 'cainiao',
      name: 'Cainiao / AliExpress Standard',
      track17Code: 190008,
      region: 'Global E-Commerce',
      trackingUrlTemplate: 'https://global.cainiao.com/newDetail.htm?mailNoList={num}',
    ),
    CarrierInfo(
      id: 'china_post',
      name: 'China Post (ePacket / Registered)',
      track17Code: 3011,
      region: 'China & Worldwide',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'yanwen',
      name: 'Yanwen Logistics',
      track17Code: 190012,
      region: 'International E-Commerce',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'sunyou',
      name: 'SunYou (Sypost)',
      track17Code: 190074,
      region: 'International E-Commerce',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: '4px',
      name: '4PX Worldwide Express',
      track17Code: 190002,
      region: 'International E-Commerce',
      trackingUrlTemplate: 'https://track.4px.com/#/result/0/{num}',
    ),
    CarrierInfo(
      id: 'yunexpress',
      name: 'YunExpress',
      track17Code: 190009,
      region: 'International E-Commerce',
      trackingUrlTemplate: 'https://www.yuntrack.com/parcelTracking?id={num}',
    ),
    CarrierInfo(
      id: 'temu',
      name: 'Temu Logistics',
      track17Code: 0,
      region: 'Global E-Commerce',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'shein',
      name: 'Shein Express',
      track17Code: 0,
      region: 'Global E-Commerce',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'speedaf',
      name: 'Speedaf Express',
      track17Code: 190441,
      region: 'Africa, MENA & Asia',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'jt_express',
      name: 'J&T Express',
      track17Code: 100279,
      region: 'MENA, Asia & Global',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    // Major International Couriers
    CarrierInfo(
      id: 'dhl',
      name: 'DHL Express / eCommerce',
      track17Code: 100001,
      region: 'Worldwide',
      trackingUrlTemplate: 'https://www.dhl.com/en/express/tracking.html?AWB={num}',
    ),
    CarrierInfo(
      id: 'ups',
      name: 'UPS',
      track17Code: 100002,
      region: 'Worldwide',
      trackingUrlTemplate: 'https://www.ups.com/track?tracknum={num}',
    ),
    CarrierInfo(
      id: 'fedex',
      name: 'FedEx',
      track17Code: 100003,
      region: 'Worldwide',
      trackingUrlTemplate: 'https://www.fedex.com/fedextrack/?trknbr={num}',
    ),
    CarrierInfo(
      id: 'aramex',
      name: 'Aramex',
      track17Code: 100006,
      region: 'MENA & Worldwide',
      trackingUrlTemplate: 'https://www.aramex.com/us/en/track/results?ShipmentNumber={num}',
    ),
    CarrierInfo(
      id: 'tnt',
      name: 'TNT Express',
      track17Code: 100004,
      region: 'Worldwide',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'dpd',
      name: 'DPD Group',
      track17Code: 100007,
      region: 'Europe & Worldwide',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'gls',
      name: 'GLS',
      track17Code: 100005,
      region: 'Europe & North America',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    // National Postal Services
    CarrierInfo(
      id: 'laposte',
      name: 'La Poste / Colissimo / Chronopost',
      track17Code: 6051,
      region: 'France & International',
      trackingUrlTemplate: 'https://www.laposte.fr/outils/suivre-vos-envois?code={num}',
    ),
    CarrierInfo(
      id: 'royal_mail',
      name: 'Royal Mail / Parcelforce',
      track17Code: 11031,
      region: 'United Kingdom',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'usps',
      name: 'USPS (United States Postal Service)',
      track17Code: 21051,
      region: 'United States',
      trackingUrlTemplate: 'https://tools.usps.com/go/TrackConfirmAction?tLabels={num}',
    ),
    CarrierInfo(
      id: 'canada_post',
      name: 'Canada Post',
      track17Code: 3041,
      region: 'Canada',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'singapore_post',
      name: 'Singapore Post (SingPost)',
      track17Code: 19011,
      region: 'Singapore & Worldwide',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'postnl',
      name: 'PostNL',
      track17Code: 14041,
      region: 'Netherlands & Worldwide',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'ptt_turkey',
      name: 'PTT Kargo (Turkish Post)',
      track17Code: 20101,
      region: 'Turkey & Worldwide',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
    CarrierInfo(
      id: 'emirates_post',
      name: 'Emirates Post',
      track17Code: 1021,
      region: 'UAE & Worldwide',
      trackingUrlTemplate: 'https://t.17track.net/en#nums={num}',
    ),
  ];

  static CarrierInfo detectCarrier(String rawNumber) {
    final code = rawNumber.trim().toUpperCase();
    if (code.isEmpty) return byId('auto');

    if (code.startsWith('YAL') || code.startsWith('YD')) {
      return byId('yalidine');
    }
    if (code.startsWith('ZR') || code.startsWith('ZRE')) {
      return byId('zrexpress');
    }
    if (code.startsWith('MAY') || code.startsWith('MSD')) {
      return byId('maystro');
    }
    if (code.startsWith('GPX') || code.startsWith('GUE')) {
      return byId('guepex');
    }
    if (code.endsWith('DZ')) {
      return byId('algerie_poste');
    }
    if (code.startsWith('LP') ||
        code.startsWith('CAINIAO') ||
        code.startsWith('CN') ||
        code.endsWith('CN')) {
      return byId('cainiao');
    }
    if (code.startsWith('YT') && code.length >= 16) {
      return byId('yunexpress');
    }
    if (code.startsWith('VR') ||
        code.startsWith('UG') ||
        code.startsWith('UY')) {
      return byId('yanwen');
    }
    if (code.startsWith('SY')) {
      return byId('sunyou');
    }
    if (code.startsWith('4PX')) {
      return byId('4px');
    }
    if (code.startsWith('1Z')) {
      return byId('ups');
    }
    if (code.startsWith('JJD') ||
        code.startsWith('DHL') ||
        code.startsWith('GM')) {
      return byId('dhl');
    }
    if (code.endsWith('FR') || code.startsWith('6A') || code.startsWith('8R')) {
      return byId('laposte');
    }
    if (code.endsWith('SG') || code.endsWith('NL')) {
      return code.endsWith('SG') ? byId('singapore_post') : byId('postnl');
    }
    if (code.endsWith('TR')) {
      return byId('ptt_turkey');
    }
    if (code.startsWith('94') ||
        code.startsWith('92') ||
        code.startsWith('93')) {
      return byId('usps');
    }
    if (RegExp(r'^[A-Z]{2}\d{9}[A-Z]{2}$').hasMatch(code)) {
      // Universal Postal Union S10 international EMS/Registered format
      return byId('algerie_poste');
    }
    return byId('auto');
  }

  static CarrierInfo byId(String id) {
    return carriers.firstWhere(
      (c) => c.id == id,
      orElse: () => carriers.first,
    );
  }
}

class PackageItem {
  final String id;
  final String trackingNumber;
  final String customName;
  final String carrierId;
  final PackageStatus status;
  final String eta;
  final String origin;
  final String destination;
  final List<TrackingEvent> events;
  final bool isArchived;
  final DateTime updatedAt;

  const PackageItem({
    required this.id,
    required this.trackingNumber,
    required this.customName,
    required this.carrierId,
    required this.status,
    required this.eta,
    required this.origin,
    required this.destination,
    required this.events,
    this.isArchived = false,
    required this.updatedAt,
  });

  PackageItem copyWith({
    String? customName,
    String? carrierId,
    PackageStatus? status,
    String? eta,
    String? origin,
    String? destination,
    List<TrackingEvent>? events,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return PackageItem(
      id: id,
      trackingNumber: trackingNumber,
      customName: customName ?? this.customName,
      carrierId: carrierId ?? this.carrierId,
      status: status ?? this.status,
      eta: eta ?? this.eta,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      events: events ?? this.events,
      isArchived: isArchived ?? this.isArchived,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackingNumber': trackingNumber,
        'customName': customName,
        'carrierId': carrierId,
        'status': status.name,
        'eta': eta,
        'origin': origin,
        'destination': destination,
        'events': events.map((e) => e.toJson()).toList(),
        'isArchived': isArchived,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PackageItem.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] ?? 'inTransit';
    final status = PackageStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => PackageStatus.inTransit,
    );
    return PackageItem(
      id: json['id'] ?? '',
      trackingNumber: json['trackingNumber'] ?? '',
      customName: json['customName'] ?? 'Package',
      carrierId: json['carrierId'] ?? 'auto',
      status: status,
      eta: json['eta'] ?? 'In Transit',
      origin: json['origin'] ?? 'Origin Hub',
      destination: json['destination'] ?? 'Destination',
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => TrackingEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      isArchived: json['isArchived'] ?? false,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class AppStrings {
  static const Map<String, Map<String, String>> _data = {
    'en': {
      'tagline': 'Track your packages\nanytime, anywhere',
      'search_hint': 'Enter tracking number...',
      'scan_barcode': 'Scan\nBarcode',
      'track_history': 'Track\nHistory',
      'settings': 'Settings',
      'about': 'About',
      'your_packages': 'Your Packages',
      'view_all': 'View All',
      'home': 'Home',
      'track': 'Track',
      'history': 'History',
      'profile': 'Profile',
      'in_transit': 'In Transit',
      'arriving_soon': 'Arriving soon',
      'delivered': 'Delivered',
      'picked_up': 'Package picked up',
      'all': 'All',
      'add_package': 'Add Package',
      'custom_name': 'Custom Name (e.g. Phone Case)',
      'carrier': 'Select Courier (2,400+ Supported)',
      'track_now': 'Track Package Live',
      'not_found_title': 'Invalid Tracking Number',
      'not_found_desc':
          'Please enter a valid tracking number (at least 4 characters).',
      'empty_title': 'No packages tracked yet',
      'empty_desc':
          'Paste your real tracking number above or tap the + button to start tracking.',
      'onboarding_1_title': 'Track 2,400+ Local & Global Couriers',
      'onboarding_1_desc':
          'Supports Yalidine, ZR Express, Maystro, Guepex, Algérie Poste/EMS, Cainiao/AliExpress, DHL, UPS, FedEx, Aramex & more.',
      'onboarding_2_title': 'Instant Barcode & QR Scanner',
      'onboarding_2_desc':
          'Point your camera at any shipping label to scan the barcode immediately.',
      'onboarding_3_title': 'Cloud Backup & Account Sync',
      'onboarding_3_desc':
          'Sign in with Google or Email to backup and sync all your packages across your devices.',
      'get_started': 'Get Started',
      'next': 'Next',
      'skip': 'Skip',
      'language': 'Language',
      'theme': 'Theme Mode',
      'notifications': 'Push Notifications',
      'test_notification': 'Send Test Notification',
      'archived': 'Archived',
    },
    'fr': {
      'tagline': 'Suivez vos colis\nà tout moment, partout',
      'search_hint': 'Entrez le numéro de suivi...',
      'scan_barcode': 'Scanner\nCode',
      'track_history': 'Historique\nSuivi',
      'settings': 'Paramètres',
      'about': 'À propos',
      'your_packages': 'Vos Colis',
      'view_all': 'Voir tout',
      'home': 'Accueil',
      'track': 'Suivi',
      'history': 'Historique',
      'profile': 'Profil',
      'in_transit': 'En Transit',
      'arriving_soon': 'Arrive bientôt',
      'delivered': 'Livré',
      'picked_up': 'Colis enregistré',
      'all': 'Tous',
      'add_package': 'Ajouter un colis',
      'custom_name': 'Nom personnalisé (ex: Commande)',
      'carrier': 'Transporteur (2 400+ supportés)',
      'track_now': 'Suivre en direct',
      'not_found_title': 'Numéro de suivi invalide',
      'not_found_desc':
          'Veuillez entrer un numéro de suivi valide (au moins 4 caractères).',
      'empty_title': 'Aucun colis suivi',
      'empty_desc':
          'Entrez un numéro de suivi en haut ou appuyez sur + pour suivre votre premier colis.',
      'onboarding_1_title': '2 400+ Transporteurs Locaux & Mondiaux',
      'onboarding_1_desc':
          'Yalidine, ZR Express, Maystro, Guepex, Algérie Poste/EMS, Cainiao/AliExpress, DHL, UPS, FedEx, Aramex et plus.',
      'onboarding_2_title': 'Scanner Code-Barres & QR',
      'onboarding_2_desc':
          'Scannez votre étiquette d\'expédition avec la caméra en une seconde.',
      'onboarding_3_title': 'Sauvegarde & Synchronisation Cloud',
      'onboarding_3_desc':
          'Connectez-vous avec Google ou Email pour sauvegarder et synchroniser tous vos colis.',
      'get_started': 'Commencer',
      'next': 'Suivant',
      'skip': 'Passer',
      'language': 'Langue',
      'theme': 'Thème',
      'notifications': 'Notifications Push',
      'test_notification': 'Tester une notification',
      'archived': 'Archivés',
    },
    'ar': {
      'tagline': 'تتبع طرودك في أي وقت\nومن أي مكان',
      'search_hint': 'أدخل رقم التتبع الحقيقي...',
      'scan_barcode': 'مسح\nالباركود',
      'track_history': 'سجل\nالتتبع',
      'settings': 'الإعدادات',
      'about': 'حول التطبيق',
      'your_packages': 'طرودك الحالية',
      'view_all': 'عرض الكل',
      'home': 'الرئيسية',
      'track': 'التتبع',
      'history': 'السجل',
      'profile': 'حسابي',
      'in_transit': 'في الطريق',
      'arriving_soon': 'يصل قريباً',
      'delivered': 'تم التسليم',
      'picked_up': 'تم تسجيل الشحنة',
      'all': 'الكل',
      'add_package': 'إضافة طرد جديد',
      'custom_name': 'اسم الطرد (مثال: طلبية جديدة)',
      'carrier': 'شركة الشحن (أكثر من 2400 شركة)',
      'track_now': 'تتبع الطرد مباشرة',
      'not_found_title': 'رقم التتبع غير صالح',
      'not_found_desc': 'يرجى إدخال رقم تتبع صحيح (4 أحرف أو أرقام على الأقل).',
      'empty_title': 'لا توجد طرود مضافة بعد',
      'empty_desc':
          'أدخل رقم التتبع في الأعلى أو اضغط على زر + الأزرق لبدء تتبع طرودك الحقيقية.',
      'onboarding_1_title': 'دعم أكثر من 2400 شركة شحن محلية وعالمية',
      'onboarding_1_desc':
          'ياليدين، ZR Express، مايسترو، غويبيكس، بريد الجزائر EMS، AliExpress، DHL، UPS، FedEx، أرامكس والمزيد.',
      'onboarding_2_title': 'ماسح باركود و QR بالكاميرا',
      'onboarding_2_desc': 'وجه الكاميرا نحو ملصق الطرد لمسح رقم التتبع فوراً.',
      'onboarding_3_title': 'نسخ احتياطي ومزامنة عبر الحساب',
      'onboarding_3_desc':
          'سجل الدخول بحساب Google أو البريد الإلكتروني لحفظ ومزامنة جميع طرودك.',
      'get_started': 'ابدأ الآن',
      'next': 'التالي',
      'skip': 'تخطي',
      'language': 'اللغة',
      'theme': 'المظهر',
      'notifications': 'الإشعارات الفورية',
      'test_notification': 'إرسال إشعار تجريبي',
      'archived': 'الأرشيف',
    },
  };

  static String tr(String lang, String key) {
    return _data[lang]?[key] ?? _data['en']![key] ?? key;
  }

  static TextDirection directionOf(String lang) {
    return lang == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  }
}
