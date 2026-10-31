import 'package:flutter/material.dart';

enum PackageStatus {
  pickedUp,
  inTransit,
  arrivingSoon,
  delivered,
  notFound,
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

  const CarrierInfo({
    required this.id,
    required this.name,
    required this.track17Code,
    required this.region,
  });
}

class CarrierRegistry {
  static const List<CarrierInfo> carriers = [
    CarrierInfo(
      id: 'auto',
      name: 'Auto-Detect Carrier',
      track17Code: 0,
      region: 'Global & Algeria',
    ),
    CarrierInfo(
      id: 'yalidine',
      name: 'Yalidine Express',
      track17Code: 100592,
      region: 'Algeria (Local)',
    ),
    CarrierInfo(
      id: 'zrexpress',
      name: 'ZR Express',
      track17Code: 100791,
      region: 'Algeria (Local)',
    ),
    CarrierInfo(
      id: 'algerie_poste',
      name: 'Algérie Poste / EMS',
      track17Code: 3011,
      region: 'Algeria & International',
    ),
    CarrierInfo(
      id: 'dhl',
      name: 'DHL Express',
      track17Code: 100001,
      region: 'International',
    ),
    CarrierInfo(
      id: 'aramex',
      name: 'Aramex',
      track17Code: 100006,
      region: 'MENA & International',
    ),
    CarrierInfo(
      id: 'aliexpress',
      name: 'AliExpress / Cainiao',
      track17Code: 190008,
      region: 'E-Commerce',
    ),
    CarrierInfo(
      id: 'temu',
      name: 'Temu Logistics',
      track17Code: 190911,
      region: 'E-Commerce',
    ),
    CarrierInfo(
      id: 'shein',
      name: 'Shein Express',
      track17Code: 190271,
      region: 'E-Commerce',
    ),
  ];

  static CarrierInfo detectCarrier(String rawNumber) {
    final code = rawNumber.trim().toUpperCase();
    if (code.startsWith('YAL') || code.startsWith('YD')) {
      return byId('yalidine');
    }
    if (code.startsWith('ZR') || code.startsWith('ZRE')) {
      return byId('zrexpress');
    }
    if (code.endsWith('DZ') ||
        code.startsWith('EE') ||
        code.startsWith('RR') ||
        code.startsWith('CP')) {
      return byId('algerie_poste');
    }
    if (code.startsWith('JJD') ||
        code.startsWith('DHL') ||
        RegExp(r'^\d{10}$').hasMatch(code)) {
      return byId('dhl');
    }
    if (code.startsWith('ARX') || RegExp(r'^\d{11}$').hasMatch(code)) {
      return byId('aramex');
    }
    if (code.startsWith('LP') ||
        code.startsWith('CAINIAO') ||
        code.endsWith('CN')) {
      return byId('aliexpress');
    }
    if (code.startsWith('TMU') || code.startsWith('TEMU')) {
      return byId('temu');
    }
    if (code.startsWith('SHN') || code.startsWith('SHEIN')) {
      return byId('shein');
    }
    return byId('algerie_poste');
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
      carrierId: json['carrierId'] ?? 'algerie_poste',
      status: status,
      eta: json['eta'] ?? 'Oct 31, 2026 • 6:00 PM',
      origin: json['origin'] ?? 'Algiers Hub',
      destination: json['destination'] ?? 'Oran, Algeria',
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => TrackingEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      isArchived: json['isArchived'] ?? false,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  static List<PackageItem> defaultSamplePackages() {
    return [
      PackageItem(
        id: 'sample_1',
        trackingNumber: 'TRK123456789',
        customName: 'Wireless Headphones',
        carrierId: 'dhl',
        status: PackageStatus.arrivingSoon,
        eta: 'Oct 31, 2026 • 6:00 PM',
        origin: 'Frankfurt, Germany',
        destination: 'Oran, Algeria',
        updatedAt: DateTime.now(),
        events: const [
          TrackingEvent(
            title: 'Package picked up',
            timestamp: 'Oct 29, 2026 • 10:24 AM',
            location: 'Frankfurt Sorting Center',
            isCompleted: true,
            isCurrent: false,
          ),
          TrackingEvent(
            title: 'In transit',
            timestamp: 'Oct 30, 2026 • 02:17 PM',
            location: 'Algiers International Hub (ALG)',
            isCompleted: true,
            isCurrent: false,
          ),
          TrackingEvent(
            title: 'Arriving soon',
            timestamp: 'Expected: Oct 31, 2026 • 6:00 PM',
            location: 'Out for delivery - Es Senia, Oran',
            isCompleted: false,
            isCurrent: true,
          ),
        ],
      ),
      PackageItem(
        id: 'sample_2',
        trackingNumber: 'YAL-8849201DZ',
        customName: 'Mechanical Keyboard',
        carrierId: 'yalidine',
        status: PackageStatus.inTransit,
        eta: 'Nov 02, 2026 • 2:00 PM',
        origin: 'Bab Ezzouar, Algiers',
        destination: 'Es Senia Stop Desk, Oran',
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        events: const [
          TrackingEvent(
            title: 'Package picked up',
            timestamp: 'Oct 30, 2026 • 09:15 AM',
            location: 'Yalidine Agency - Bab Ezzouar',
            isCompleted: true,
            isCurrent: false,
          ),
          TrackingEvent(
            title: 'In transit',
            timestamp: 'Oct 31, 2026 • 08:40 AM',
            location: 'Departed Regional Hub towards Oran',
            isCompleted: false,
            isCurrent: true,
          ),
        ],
      ),
      PackageItem(
        id: 'sample_3',
        trackingNumber: 'LP005928174CN',
        customName: 'Smart Watch Strap (AliExpress)',
        carrierId: 'algerie_poste',
        status: PackageStatus.delivered,
        eta: 'Delivered Oct 27, 2026',
        origin: 'Shenzhen, China',
        destination: 'Oran RP, Algeria',
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        events: const [
          TrackingEvent(
            title: 'Package picked up',
            timestamp: 'Oct 15, 2026 • 11:00 AM',
            location: 'Cainiao Consolidation Warehouse',
            isCompleted: true,
            isCurrent: false,
          ),
          TrackingEvent(
            title: 'In transit',
            timestamp: 'Oct 24, 2026 • 04:30 PM',
            location: 'Algérie Poste EMS Algiers Exchange',
            isCompleted: true,
            isCurrent: false,
          ),
          TrackingEvent(
            title: 'Arriving soon',
            timestamp: 'Oct 27, 2026 • 09:00 AM',
            location: 'Oran El M\'Naouer Post Office',
            isCompleted: true,
            isCurrent: false,
          ),
          TrackingEvent(
            title: 'Delivered',
            timestamp: 'Oct 27, 2026 • 01:45 PM',
            location: 'Delivered to recipient in Oran',
            isCompleted: true,
            isCurrent: true,
          ),
        ],
      ),
    ];
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
      'custom_name': 'Custom Name (e.g. New Shoes)',
      'carrier': 'Select Carrier',
      'track_now': 'Track Package',
      'free_limit_title': 'Free Plan Limit Reached (5/5)',
      'upgrade_premium': 'Upgrade to Arrivo Premium',
      'demo_mode_badge': 'Demo Mode Active (No API Key Required)',
      'live_api_badge': '17TRACK Live API Connected',
      'not_found_title': 'Tracking Number Not Found',
      'not_found_desc':
          'We could not find any shipment matching this tracking number. Double-check the digits or pick the carrier manually.',
      'empty_title': 'No packages here yet',
      'empty_desc':
          'Tap the blue + button to add a tracking number or scan a barcode.',
      'onboarding_1_title': 'Track Global & Local Parcels',
      'onboarding_1_desc':
          'Real-time updates for Yalidine, ZR Express, Algérie Poste/EMS, DHL, Aramex, AliExpress, Temu & Shein.',
      'onboarding_2_title': 'Instant Barcode & QR Scanner',
      'onboarding_2_desc':
          'Point your camera at any shipping receipt or box label to add your package in one second.',
      'onboarding_3_title': 'Live Push Notifications',
      'onboarding_3_desc':
          'Get notified immediately when your parcel leaves the hub or is arriving soon.',
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
      'picked_up': 'Colis pris en charge',
      'all': 'Tous',
      'add_package': 'Ajouter un colis',
      'custom_name': 'Nom personnalisé (ex: Casque Audio)',
      'carrier': 'Transporteur',
      'track_now': 'Suivre le colis',
      'free_limit_title': 'Limite Gratuite Atteinte (5/5)',
      'upgrade_premium': 'Passer à Arrivo Premium',
      'demo_mode_badge': 'Mode Démo Actif (Sans clé API)',
      'live_api_badge': 'API 17TRACK Connectée',
      'not_found_title': 'Numéro de suivi introuvable',
      'not_found_desc':
          'Aucun colis trouvé pour ce numéro. Vérifiez le code ou choisissez le transporteur manuellement.',
      'empty_title': 'Aucun colis pour le moment',
      'empty_desc':
          'Appuyez sur le bouton + pour ajouter un numéro ou scanner un code-barres.',
      'onboarding_1_title': 'Suivi Local & International',
      'onboarding_1_desc':
          'Suivez Yalidine, ZR Express, Algérie Poste/EMS, DHL, Aramex, AliExpress, Temu et Shein en temps réel.',
      'onboarding_2_title': 'Scanner Code-Barres & QR',
      'onboarding_2_desc':
          'Scannez votre bordereau d\'expédition avec la caméra pour ajouter un colis instantanément.',
      'onboarding_3_title': 'Notifications en Temps Réel',
      'onboarding_3_desc':
          'Recevez une alerte dès que votre colis change de statut ou arrive bientôt.',
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
      'search_hint': 'أدخل رقم التتبع...',
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
      'picked_up': 'تم استلام الطرد',
      'all': 'الكل',
      'add_package': 'إضافة طرد جديد',
      'custom_name': 'اسم الطرد (مثال: سماعات لاسلكية)',
      'carrier': 'شركة الشحن',
      'track_now': 'تتبع الطرد الآن',
      'free_limit_title': 'وصلت للحد المجاني (5/5)',
      'upgrade_premium': 'الترقية إلى Arrivo Premium',
      'demo_mode_badge': 'الوضع التجريبي مفعل تلقائياً',
      'live_api_badge': 'متصل بخدمة 17TRACK المباشرة',
      'not_found_title': 'لم يتم العثور على رقم التتبع',
      'not_found_desc':
          'تعذر العثور على شحنة بهذا الرقم. يرجى التأكد من الرقم أو اختيار شركة الشحن يدوياً.',
      'empty_title': 'لا توجد طرود حالياً',
      'empty_desc': 'اضغط على زر + الأزرق لإضافة رقم تتبع أو مسح الباركود.',
      'onboarding_1_title': 'تتبع محلي ودولي شامل',
      'onboarding_1_desc':
          'دعم كامل لشركات ياليدين، ZR Express، بريد الجزائر EMS، DHL، أرامكس، AliExpress، Temu و Shein.',
      'onboarding_2_title': 'ماسح باركود و QR سريع',
      'onboarding_2_desc':
          'وجه الكاميرا نحو ملصق الشحنة لإضافة الطرد في ثانية واحدة.',
      'onboarding_3_title': 'إشعارات فورية لتحديثات الشحن',
      'onboarding_3_desc':
          'احصل على تنبيه فوري عند تغير حالة طردك أو اقتراب موعد وصوله.',
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
