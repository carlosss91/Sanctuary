class AiWatchdogConfig {
  final String geminiApiKey;
  final String geminiModel;
  final bool notifyEmail;
  final String targetEmail;
  final String checkFrequency;
  final String islandFilter;
  final List<String> keywords;
  final List<String> activeSources;
  final String? lastScanDate;
  final String? lastScanStatus;

  const AiWatchdogConfig({
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-1.5-flash',
    this.notifyEmail = true,
    this.targetEmail = '',
    this.checkFrequency = 'daily',
    this.islandFilter = 'Lanzarote',
    this.keywords = const [
      'vivienda protegida',
      'vpo',
      'lanzarote',
      'ayudas alquiler',
      'vivienda social',
      'promoción pública',
      'instituto canario de la vivienda',
      'arrecife',
    ],
    this.activeSources = const ['boc', 'boe', 'gobcan_vivienda', 'icv'],
    this.lastScanDate,
    this.lastScanStatus,
  });

  static AiWatchdogConfig defaultConfig({String targetEmail = ''}) =>
      AiWatchdogConfig(targetEmail: targetEmail);

  String get targetIsland => islandFilter;
  bool get emailNotifications => notifyEmail;

  factory AiWatchdogConfig.fromJson(Map<String, dynamic> json) {
    return AiWatchdogConfig(
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      geminiModel: json['geminiModel'] as String? ?? 'gemini-1.5-flash',
      notifyEmail: json['notifyEmail'] as bool? ?? true,
      targetEmail: json['targetEmail'] as String? ?? '',
      checkFrequency: json['checkFrequency'] as String? ?? 'daily',
      islandFilter: json['islandFilter'] as String? ?? 'Lanzarote',
      keywords: (json['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [
            'vivienda protegida',
            'vpo',
            'lanzarote',
            'ayudas alquiler',
            'vivienda social',
            'promoción pública',
            'instituto canario de la vivienda',
            'arrecife',
          ],
      activeSources: (json['activeSources'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['boc', 'boe', 'gobcan_vivienda', 'icv'],
      lastScanDate: json['lastScanDate'] as String?,
      lastScanStatus: json['lastScanStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'geminiApiKey': geminiApiKey,
      'geminiModel': geminiModel,
      'notifyEmail': notifyEmail,
      'targetEmail': targetEmail,
      'checkFrequency': checkFrequency,
      'islandFilter': islandFilter,
      'keywords': keywords,
      'activeSources': activeSources,
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
    String? islandFilter,
    List<String>? keywords,
    List<String>? activeSources,
    String? lastScanDate,
    String? lastScanStatus,
  }) {
    return AiWatchdogConfig(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      targetEmail: targetEmail ?? this.targetEmail,
      checkFrequency: checkFrequency ?? this.checkFrequency,
      islandFilter: islandFilter ?? this.islandFilter,
      keywords: keywords ?? this.keywords,
      activeSources: activeSources ?? this.activeSources,
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
