import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Plataformas de presentaciones soportadas por Slide Downloader
enum SlidePlatform {
  prezi,
  googleSlides,
  slideShare,
  speakerDeck,
  directPdf,
  canva,
  generic;

  String get displayName {
    switch (this) {
      case SlidePlatform.prezi:
        return 'Prezi';
      case SlidePlatform.googleSlides:
        return 'Google Slides';
      case SlidePlatform.slideShare:
        return 'LinkedIn SlideShare';
      case SlidePlatform.speakerDeck:
        return 'Speaker Deck';
      case SlidePlatform.directPdf:
        return 'Documento PDF';
      case SlidePlatform.canva:
        return 'Canva';
      case SlidePlatform.generic:
        return 'Presentación Web';
    }
  }

  IconData get iconData {
    switch (this) {
      case SlidePlatform.prezi:
        return Icons.slideshow_rounded;
      case SlidePlatform.googleSlides:
        return Icons.co_present_rounded;
      case SlidePlatform.slideShare:
        return Icons.auto_stories_rounded;
      case SlidePlatform.speakerDeck:
        return Icons.view_carousel_rounded;
      case SlidePlatform.directPdf:
        return Icons.picture_as_pdf_rounded;
      case SlidePlatform.canva:
        return Icons.palette_rounded;
      case SlidePlatform.generic:
        return Icons.present_to_all_rounded;
    }
  }

  Color get brandColor {
    switch (this) {
      case SlidePlatform.prezi:
        return const Color(0xFF3182CE);
      case SlidePlatform.googleSlides:
        return const Color(0xFFF59E0B);
      case SlidePlatform.slideShare:
        return const Color(0xFF0077B5);
      case SlidePlatform.speakerDeck:
        return const Color(0xFF10B981);
      case SlidePlatform.directPdf:
        return const Color(0xFFEF4444);
      case SlidePlatform.canva:
        return const Color(0xFF7C3AED);
      case SlidePlatform.generic:
        return const Color(0xFF6366F1);
    }
  }
}

/// Modelo de información unificada de una presentación (Slide Downloader)
class PreziPresentationInfo {
  final String id;
  final SlidePlatform platform;
  final String? prezilink;
  final String title;
  final bool isVideo;
  final String originalUrl;
  final int totalSteps;
  final int filteredStepsCount;
  final int duplicatesCount;
  final List<PreziVideoItem> videos;
  final String? signedVideoUrl;

  PreziPresentationInfo({
    required this.id,
    this.platform = SlidePlatform.prezi,
    this.prezilink,
    required this.title,
    this.isVideo = false,
    required this.originalUrl,
    this.totalSteps = 0,
    this.filteredStepsCount = 0,
    this.duplicatesCount = 0,
    this.videos = const [],
    this.signedVideoUrl,
  });

  PreziPresentationInfo copyWith({
    String? id,
    SlidePlatform? platform,
    String? prezilink,
    String? title,
    bool? isVideo,
    String? originalUrl,
    int? totalSteps,
    int? filteredStepsCount,
    int? duplicatesCount,
    List<PreziVideoItem>? videos,
    String? signedVideoUrl,
  }) {
    return PreziPresentationInfo(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      prezilink: prezilink ?? this.prezilink,
      title: title ?? this.title,
      isVideo: isVideo ?? this.isVideo,
      originalUrl: originalUrl ?? this.originalUrl,
      totalSteps: totalSteps ?? this.totalSteps,
      filteredStepsCount: filteredStepsCount ?? this.filteredStepsCount,
      duplicatesCount: duplicatesCount ?? this.duplicatesCount,
      videos: videos ?? this.videos,
      signedVideoUrl: signedVideoUrl ?? this.signedVideoUrl,
    );
  }
}

/// Modelo de un video detectado dentro de la presentación
class PreziVideoItem {
  final String id;
  final int stepIndex;
  final String service; // 'youtube', 'vimeo', 'mp4', 'prezi_video'
  final String url;
  final String? thumbnailUrl;
  final String title;
  bool isSelected;

  PreziVideoItem({
    required this.id,
    required this.stepIndex,
    required this.service,
    required this.url,
    this.thumbnailUrl,
    required this.title,
    this.isSelected = true,
  });

  bool get isYouTube =>
      service.toLowerCase().contains('youtube') ||
      url.toLowerCase().contains('youtube.com') ||
      url.toLowerCase().contains('youtu.be');

  bool get isVimeo =>
      service.toLowerCase().contains('vimeo') ||
      url.toLowerCase().contains('vimeo.com');

  bool get isDirectMp4 =>
      url.toLowerCase().contains('.mp4') ||
      url.toLowerCase().contains('.webm') ||
      service.toLowerCase() == 'video';

  String get serviceDisplayName {
    if (isYouTube) return 'YouTube';
    if (isVimeo) return 'Vimeo';
    if (service == 'prezi_video') return 'Prezi Video';
    return 'Video MP4';
  }
}

/// Estado de la conversión y descarga de diapositivas
enum PreziProcessPhase {
  idle,
  analyzing,
  fetchingStoryboard,
  downloadingSlides,
  compilingPdf,
  downloadingVideos,
  completed,
  error,
}

class PreziConversionState {
  final PreziProcessPhase phase;
  final double progress; // 0.0 a 1.0
  final String message;
  final int currentItem;
  final int totalItems;
  final Uint8List? generatedPdfBytes;
  final String? generatedPdfFilename;
  final PreziPresentationInfo? presentationInfo;
  final String? errorMessage;

  const PreziConversionState({
    this.phase = PreziProcessPhase.idle,
    this.progress = 0.0,
    this.message = '',
    this.currentItem = 0,
    this.totalItems = 0,
    this.generatedPdfBytes,
    this.generatedPdfFilename,
    this.presentationInfo,
    this.errorMessage,
  });

  bool get isProcessing =>
      phase == PreziProcessPhase.analyzing ||
      phase == PreziProcessPhase.fetchingStoryboard ||
      phase == PreziProcessPhase.downloadingSlides ||
      phase == PreziProcessPhase.compilingPdf ||
      phase == PreziProcessPhase.downloadingVideos;

  bool get isDone => phase == PreziProcessPhase.completed;
  bool get hasError => phase == PreziProcessPhase.error;

  PreziConversionState copyWith({
    PreziProcessPhase? phase,
    double? progress,
    String? message,
    int? currentItem,
    int? totalItems,
    Uint8List? generatedPdfBytes,
    String? generatedPdfFilename,
    PreziPresentationInfo? presentationInfo,
    String? errorMessage,
  }) {
    return PreziConversionState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      currentItem: currentItem ?? this.currentItem,
      totalItems: totalItems ?? this.totalItems,
      generatedPdfBytes: generatedPdfBytes ?? this.generatedPdfBytes,
      generatedPdfFilename: generatedPdfFilename ?? this.generatedPdfFilename,
      presentationInfo: presentationInfo ?? this.presentationInfo,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
