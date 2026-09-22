class CvExperience {
  final String jobTitle;
  final String company;
  final String period;
  final String description;

  const CvExperience({
    this.jobTitle = '',
    this.company = '',
    this.period = '',
    this.description = '',
  });

  factory CvExperience.fromJson(Map<String, dynamic> json) {
    return CvExperience(
      jobTitle: json['jobTitle'] as String? ?? '',
      company: json['company'] as String? ?? '',
      period: json['period'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobTitle': jobTitle,
      'company': company,
      'period': period,
      'description': description,
    };
  }

  CvExperience copyWith({
    String? jobTitle,
    String? company,
    String? period,
    String? description,
  }) {
    return CvExperience(
      jobTitle: jobTitle ?? this.jobTitle,
      company: company ?? this.company,
      period: period ?? this.period,
      description: description ?? this.description,
    );
  }
}

class CvEducation {
  final String degree;
  final String institution;
  final String period;
  final String details;

  const CvEducation({
    this.degree = '',
    this.institution = '',
    this.period = '',
    this.details = '',
  });

  factory CvEducation.fromJson(Map<String, dynamic> json) {
    return CvEducation(
      degree: json['degree'] as String? ?? '',
      institution: json['institution'] as String? ?? '',
      period: json['period'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'degree': degree,
      'institution': institution,
      'period': period,
      'details': details,
    };
  }

  CvEducation copyWith({
    String? degree,
    String? institution,
    String? period,
    String? details,
  }) {
    return CvEducation(
      degree: degree ?? this.degree,
      institution: institution ?? this.institution,
      period: period ?? this.period,
      details: details ?? this.details,
    );
  }
}

class CvProfileModel {
  final String id;
  final String moduleBadge;
  final String workshopTitle;
  final String fullName;
  final String jobTitle;
  final String photoUrl;
  final String photoShape; // 'circle' | 'square'
  final double photoZoom;
  final double photoPanX;
  final double photoPanY;
  final String phone;
  final String email;
  final String location;
  final String availability;
  final String drivingLicense;
  final String summary;
  final List<String> skills;
  final List<CvExperience> experiences;
  final List<CvEducation> educations;
  final String template;
  final String accentColor;
  final String fontFamily;
  final bool isEnglishVersion;
  final bool showWatermark;
  final String watermarkPattern;
  final double watermarkOpacity;
  final String customWatermarkUrl;

  const CvProfileModel({
    required this.id,
    this.moduleBadge = 'MÓDULO FC0003 · Inserción y Orientación Laboral',
    this.workshopTitle = 'Taller de Curriculum Vitae · Gestión Docente',
    this.fullName = '',
    this.jobTitle = '',
    this.photoUrl = '',
    this.photoShape = 'circle',
    this.photoZoom = 1.0,
    this.photoPanX = 0.0,
    this.photoPanY = 0.0,
    this.phone = '',
    this.email = '',
    this.location = '',
    this.availability = '',
    this.drivingLicense = '',
    this.summary = '',
    this.skills = const [],
    this.experiences = const [],
    this.educations = const [],
    this.template = 'sidebar_dark',
    this.accentColor = '#10B981',
    this.fontFamily = 'Inter',
    this.isEnglishVersion = false,
    this.showWatermark = true,
    this.watermarkPattern = 'gears',
    this.watermarkOpacity = 0.14,
    this.customWatermarkUrl = '',
  });

  factory CvProfileModel.fromJson(Map<String, dynamic> json) {
    return CvProfileModel(
      id: json['id'] as String? ?? 'profile-${DateTime.now().millisecondsSinceEpoch}',
      moduleBadge: json['moduleBadge'] as String? ?? 'MÓDULO FC0003 · Inserción y Orientación Laboral',
      workshopTitle: json['workshopTitle'] as String? ?? 'Taller de Curriculum Vitae · Gestión Docente',
      fullName: json['fullName'] as String? ?? '',
      jobTitle: json['jobTitle'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? json['avatarUrl'] as String? ?? '',
      photoShape: json['photoShape'] as String? ?? 'circle',
      photoZoom: (json['photoZoom'] as num?)?.toDouble() ?? 1.0,
      photoPanX: (json['photoPanX'] as num?)?.toDouble() ?? 0.0,
      photoPanY: (json['photoPanY'] as num?)?.toDouble() ?? 0.0,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      location: json['location'] as String? ?? '',
      availability: json['availability'] as String? ?? '',
      drivingLicense: json['drivingLicense'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      skills: (json['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      experiences: (json['experiences'] as List<dynamic>?)
              ?.map((e) => CvExperience.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      educations: (json['educations'] as List<dynamic>?)
              ?.map((e) => CvEducation.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      template: json['template'] as String? ?? 'sidebar_dark',
      accentColor: json['accentColor'] as String? ?? '#10B981',
      fontFamily: json['fontFamily'] as String? ?? 'Inter',
      isEnglishVersion: json['isEnglishVersion'] as bool? ?? false,
      showWatermark: json['showWatermark'] as bool? ?? true,
      watermarkPattern: json['watermarkPattern'] as String? ?? 'gears',
      watermarkOpacity: (json['watermarkOpacity'] as num?)?.toDouble() ?? 0.14,
      customWatermarkUrl: json['customWatermarkUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'moduleBadge': moduleBadge,
      'workshopTitle': workshopTitle,
      'fullName': fullName,
      'jobTitle': jobTitle,
      'photoUrl': photoUrl,
      'photoShape': photoShape,
      'photoZoom': photoZoom,
      'photoPanX': photoPanX,
      'photoPanY': photoPanY,
      'phone': phone,
      'email': email,
      'location': location,
      'availability': availability,
      'drivingLicense': drivingLicense,
      'summary': summary,
      'skills': skills,
      'experiences': experiences.map((e) => e.toJson()).toList(),
      'educations': educations.map((e) => e.toJson()).toList(),
      'template': template,
      'accentColor': accentColor,
      'fontFamily': fontFamily,
      'isEnglishVersion': isEnglishVersion,
      'showWatermark': showWatermark,
      'watermarkPattern': watermarkPattern,
      'watermarkOpacity': watermarkOpacity,
      'customWatermarkUrl': customWatermarkUrl,
    };
  }

  CvProfileModel copyWith({
    String? id,
    String? moduleBadge,
    String? workshopTitle,
    String? fullName,
    String? jobTitle,
    String? photoUrl,
    String? photoShape,
    double? photoZoom,
    double? photoPanX,
    double? photoPanY,
    String? phone,
    String? email,
    String? location,
    String? availability,
    String? drivingLicense,
    String? summary,
    List<String>? skills,
    List<CvExperience>? experiences,
    List<CvEducation>? educations,
    String? template,
    String? accentColor,
    String? fontFamily,
    bool? isEnglishVersion,
    bool? showWatermark,
    String? watermarkPattern,
    double? watermarkOpacity,
    String? customWatermarkUrl,
  }) {
    return CvProfileModel(
      id: id ?? this.id,
      moduleBadge: moduleBadge ?? this.moduleBadge,
      workshopTitle: workshopTitle ?? this.workshopTitle,
      fullName: fullName ?? this.fullName,
      jobTitle: jobTitle ?? this.jobTitle,
      photoUrl: photoUrl ?? this.photoUrl,
      photoShape: photoShape ?? this.photoShape,
      photoZoom: photoZoom ?? this.photoZoom,
      photoPanX: photoPanX ?? this.photoPanX,
      photoPanY: photoPanY ?? this.photoPanY,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      location: location ?? this.location,
      availability: availability ?? this.availability,
      drivingLicense: drivingLicense ?? this.drivingLicense,
      summary: summary ?? this.summary,
      skills: skills ?? this.skills,
      experiences: experiences ?? this.experiences,
      educations: educations ?? this.educations,
      template: template ?? this.template,
      accentColor: accentColor ?? this.accentColor,
      fontFamily: fontFamily ?? this.fontFamily,
      isEnglishVersion: isEnglishVersion ?? this.isEnglishVersion,
      showWatermark: showWatermark ?? this.showWatermark,
      watermarkPattern: watermarkPattern ?? this.watermarkPattern,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      customWatermarkUrl: customWatermarkUrl ?? this.customWatermarkUrl,
    );
  }
}
