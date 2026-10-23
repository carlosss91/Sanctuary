class AiWatchdogSource {
  final String id;
  final String name;
  final String url;
  final String description;
  final bool enabled;
  final bool isCustom;

  const AiWatchdogSource({
    required this.id,
    required this.name,
    required this.url,
    this.description = '',
    this.enabled = true,
    this.isCustom = false,
  });

  factory AiWatchdogSource.fromJson(Map<String, dynamic> json) {
    return AiWatchdogSource(
      id: json['id'] as String? ?? 'src-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Fuente Oficial',
      url: json['url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'description': description,
      'enabled': enabled,
      'isCustom': isCustom,
    };
  }

  AiWatchdogSource copyWith({
    String? id,
    String? name,
    String? url,
    String? description,
    bool? enabled,
    bool? isCustom,
  }) {
    return AiWatchdogSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

class AiWatchdogConfig {
  final String geminiApiKey;
  final String geminiModel;
  final bool notifyEmail;
  final String targetEmail;
  final String checkFrequency;
  final bool enablePlaceFilter;
  final String targetPlace;
  final List<String> keywords;
  final List<AiWatchdogSource> sources;
  final String? lastScanDate;
  final String? lastScanStatus;

  static const List<AiWatchdogSource> defaultSources = [
    AiWatchdogSource(
      id: 'boc',
      name: 'BOC · Boletín Oficial de Canarias',
      url: 'https://www.gobiernodecanarias.org/boc/',
      description: 'Monitorea convocatorias del Gobierno de Canarias y cabildos',
      enabled: true,
      isCustom: false,
    ),
    AiWatchdogSource(
      id: 'boe',
      name: 'BOE · Boletín Oficial del Estado',
      url: 'https://www.boe.es/diario_boe/',
      description: 'Planes estatales, subvenciones, empleo y ayudas públicas',
      enabled: true,
      isCustom: false,
    ),
    AiWatchdogSource(
      id: 'gobcan_vivienda',
      name: 'Gobierno de Canarias (Consejería de Vivienda)',
      url: 'https://www.gobiernodecanarias.org/vivienda/',
      description: 'Portal oficial de vivienda pública y convocatorias autonómicas',
      enabled: true,
      isCustom: false,
    ),
    AiWatchdogSource(
      id: 'icv',
      name: 'Instituto Canario de la Vivienda (ICV)',
      url: 'https://www.gobiernodecanarias.org/icv/',
      description: 'Convocatorias de VPO, alquiler y programas públicos',
      enabled: true,
      isCustom: false,
    ),
    AiWatchdogSource(
      id: 'ayto_yaiza',
      name: 'Ayuntamiento de Yaiza · Vivienda y Tablón Oficial',
      url: 'https://yaiza.es/',
      description: 'Convocatorias municipales de vivienda, ayudas sociales y VPO en Yaiza y Playa Blanca (Lanzarote)',
      enabled: true,
      isCustom: false,
    ),
  ];

  const AiWatchdogConfig({
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-1.5-flash',
    this.notifyEmail = true,
    this.targetEmail = '',
    this.checkFrequency = 'daily',
    this.enablePlaceFilter = true,
    this.targetPlace = 'Lanzarote',
    this.keywords = const [
      'vivienda protegida',
      'vpo',
      'lanzarote',
      'arrecife',
      'yaiza',
      'playa blanca',
      'ayudas alquiler',
      'vivienda social',
      'promoción pública',
      'instituto canario de la vivienda',
      'vivienda pública',
      'adjudicación',
    ],
    this.sources = defaultSources,
    this.lastScanDate,
    this.lastScanStatus,
  });

  static AiWatchdogConfig defaultConfig({String targetEmail = ''}) =>
      AiWatchdogConfig(targetEmail: targetEmail);

  String get targetIsland => enablePlaceFilter ? targetPlace : 'Cualquier lugar';
  String get islandFilter => targetPlace;
  bool get emailNotifications => notifyEmail;
  List<String> get activeSources => sources.where((s) => s.enabled).map((s) => s.id).toList();

  factory AiWatchdogConfig.fromJson(Map<String, dynamic> json) {
    List<AiWatchdogSource> parsedSources;
    if (json['sources'] is List && (json['sources'] as List).isNotEmpty) {
      parsedSources = (json['sources'] as List)
          .map((e) => AiWatchdogSource.fromJson(e as Map<String, dynamic>))
          .toList();
      // Ensure any newly added default source (such as ayto_yaiza) is included
      for (final defSource in defaultSources) {
        if (!parsedSources.any((s) => s.id.toLowerCase() == defSource.id.toLowerCase())) {
          parsedSources.add(defSource);
        }
      }
    } else {
      final activeList = (json['activeSources'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          ['boc', 'boe', 'gobcan_vivienda', 'icv', 'ayto_yaiza'];
      parsedSources = defaultSources
          .map((ds) => ds.copyWith(enabled: activeList.contains(ds.id.toLowerCase())))
          .toList();
    }

    final place = json['targetPlace'] as String? ?? json['islandFilter'] as String? ?? 'Lanzarote';
    final hasPlaceFilter = json['enablePlaceFilter'] as bool? ??
        (place.toLowerCase() != 'todas las islas' && place.isNotEmpty);

    return AiWatchdogConfig(
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      geminiModel: json['geminiModel'] as String? ?? 'gemini-1.5-flash',
      notifyEmail: json['notifyEmail'] as bool? ?? json['emailNotifications'] as bool? ?? true,
      targetEmail: json['targetEmail'] as String? ?? '',
      checkFrequency: json['checkFrequency'] as String? ?? 'daily',
      enablePlaceFilter: hasPlaceFilter,
      targetPlace: place,
      keywords: (json['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [
            'vivienda protegida',
            'vpo',
            'lanzarote',
            'arrecife',
            'yaiza',
            'playa blanca',
            'ayudas alquiler',
            'vivienda social',
            'promoción pública',
            'instituto canario de la vivienda',
            'vivienda pública',
            'adjudicación',
          ],
      sources: parsedSources,
      lastScanDate: json['lastScanDate'] as String?,
      lastScanStatus: json['lastScanStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'geminiApiKey': geminiApiKey,
      'geminiModel': geminiModel,
      'notifyEmail': notifyEmail,
      'emailNotifications': notifyEmail,
      'targetEmail': targetEmail,
      'checkFrequency': checkFrequency,
      'enablePlaceFilter': enablePlaceFilter,
      'targetPlace': targetPlace,
      'islandFilter': targetPlace,
      'keywords': keywords,
      'sources': sources.map((s) => s.toJson()).toList(),
      'activeSources': sources.where((s) => s.enabled).map((s) => s.id).toList(),
      'lastScanDate': lastScanDate,
      'lastScanStatus': lastScanStatus,
    };
  }

  AiWatchdogConfig copyWith({
    String? geminiApiKey,
    String? geminiModel,
    bool? notifyEmail,
    String? targetEmail,
    String? checkFrequency,
    bool? enablePlaceFilter,
    String? targetPlace,
    String? islandFilter,
    List<String>? keywords,
    List<AiWatchdogSource>? sources,
    List<String>? activeSources,
    String? lastScanDate,
    String? lastScanStatus,
  }) {
    List<AiWatchdogSource>? newSources = sources;
    if (newSources == null && activeSources != null) {
      newSources = this.sources.map((s) => s.copyWith(enabled: activeSources.contains(s.id))).toList();
    }
    return AiWatchdogConfig(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      targetEmail: targetEmail ?? this.targetEmail,
      checkFrequency: checkFrequency ?? this.checkFrequency,
      enablePlaceFilter: enablePlaceFilter ?? this.enablePlaceFilter,
      targetPlace: targetPlace ?? islandFilter ?? this.targetPlace,
      keywords: keywords ?? this.keywords,
      sources: newSources ?? this.sources,
      lastScanDate: lastScanDate ?? this.lastScanDate,
      lastScanStatus: lastScanStatus ?? this.lastScanStatus,
    );
  }
}

class AiWatchdogNotification {
  final String id;
  final String title;
  final String source; // 'BOC' | 'BOE' | 'Gobierno de Canarias' | 'ICV'
  final String date;
  final String bulletinNumber;
  final String summary;
  final String aiAnalysis;
  final String url;
  final String island;
  final String relevance; // 'Alta' | 'Media' | 'Informativa'
  final bool isRead;
  final bool isEmailSent;
  final int timestamp;

  const AiWatchdogNotification({
    required this.id,
    required this.title,
    required this.source,
    required this.date,
    this.bulletinNumber = '',
    required this.summary,
    this.aiAnalysis = '',
    required this.url,
    this.island = 'Lanzarote',
    this.relevance = 'Alta',
    this.isRead = false,
    this.isEmailSent = false,
    required this.timestamp,
  });

  factory AiWatchdogNotification.fromJson(Map<String, dynamic> json) {
    return AiWatchdogNotification(
      id: json['id'] as String? ?? 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? '',
      source: json['source'] as String? ?? 'BOC',
      date: json['date'] as String? ?? '',
      bulletinNumber: json['bulletinNumber'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      aiAnalysis: json['aiAnalysis'] as String? ?? '',
      url: json['url'] as String? ?? '',
      island: json['island'] as String? ?? 'Lanzarote',
      relevance: json['relevance'] as String? ?? 'Alta',
      isRead: json['isRead'] as bool? ?? false,
      isEmailSent: json['isEmailSent'] as bool? ?? false,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'date': date,
      'bulletinNumber': bulletinNumber,
      'summary': summary,
      'aiAnalysis': aiAnalysis,
      'url': url,
      'island': island,
      'relevance': relevance,
      'isRead': isRead,
      'isEmailSent': isEmailSent,
      'timestamp': timestamp,
    };
  }

  AiWatchdogNotification copyWith({
    String? id,
    String? title,
    String? source,
    String? date,
    String? bulletinNumber,
    String? summary,
    String? aiAnalysis,
    String? url,
    String? island,
    String? relevance,
    bool? isRead,
    bool? isEmailSent,
    int? timestamp,
  }) {
    return AiWatchdogNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      source: source ?? this.source,
      date: date ?? this.date,
      bulletinNumber: bulletinNumber ?? this.bulletinNumber,
      summary: summary ?? this.summary,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      url: url ?? this.url,
      island: island ?? this.island,
      relevance: relevance ?? this.relevance,
      isRead: isRead ?? this.isRead,
      isEmailSent: isEmailSent ?? this.isEmailSent,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
