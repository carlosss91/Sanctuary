import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/prezi_model.dart';

class PreziService {
  final String? backendBaseUrl;

  PreziService({this.backendBaseUrl});

  static const Map<String, String> _standardHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Detecta automáticamente el tipo de plataforma según la URL proporcionada
  SlidePlatform detectPlatform(String input) {
    final clean = input.trim().toLowerCase();
    if (clean.contains('docs.google.com/presentation')) {
      return SlidePlatform.googleSlides;
    } else if (clean.contains('slideshare.net')) {
      return SlidePlatform.slideShare;
    } else if (clean.contains('speakerdeck.com')) {
      return SlidePlatform.speakerDeck;
    } else if (clean.endsWith('.pdf') || clean.contains('.pdf?')) {
      return SlidePlatform.directPdf;
    } else if (clean.contains('canva.com')) {
      return SlidePlatform.canva;
    } else if (clean.contains('prezi.com') || extractId(input) != null) {
      return SlidePlatform.prezi;
    }
    return SlidePlatform.generic;
  }

  /// 1. Extrae el identificador de una URL de Prezi o valida si es un ID directo.
  String? extractId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    final patterns = [
      RegExp(r'/p/(?:edit/)?([a-zA-Z0-9_-]{10,32})'),
      RegExp(r'/v/([a-zA-Z0-9_-]{10,32})'),
      RegExp(r'/view/([a-zA-Z0-9_-]{10,32})'),
      RegExp(r'/i/([a-zA-Z0-9_-]{10,32})'),
      RegExp(r'prezi\.com/([a-zA-Z0-9_-]{10,32})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(clean);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }

    final trimmed = clean.replaceAll(RegExp(r'^/+|/+$'), '');
    if (RegExp(r'^[a-zA-Z0-9_-]{10,32}$').hasMatch(trimmed)) {
      return trimmed;
    }

    final fallback = RegExp(r'([a-zA-Z0-9_-]{10,32})').firstMatch(clean);
    if (fallback != null && fallback.groupCount >= 1) {
      return fallback.group(1);
    }

    return null;
  }

  /// Helper para obtener HTML sorteando posibles restricciones de CORS en Web
  Future<String?> fetchHtml(String url) async {
    // 1. Intentar con backend proxy si está disponible
    if (backendBaseUrl != null) {
      try {
        final proxyUri = Uri.parse('$backendBaseUrl/slides/proxy?url=${Uri.encodeComponent(url)}');
        final res = await http.get(proxyUri).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          return res.body;
        }
      } catch (_) {}
    }

    // 2. Intentar llamada directa
    try {
      final res = await http.get(Uri.parse(url), headers: _standardHeaders).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return res.body;
      }
    } catch (e) {
      debugPrint('Error en fetchHtml directo: $e');
    }
    return null;
  }

  /// Helper para descargar bytes binarios (PDF o imagen)
  Future<Uint8List?> fetchBinary(String url) async {
    // 1. Intentar directa
    try {
      final res = await http.get(Uri.parse(url), headers: _standardHeaders).timeout(const Duration(seconds: 25));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (_) {}

    // 2. Intentar backend proxy
    if (backendBaseUrl != null) {
      try {
        final proxyUri = Uri.parse('$backendBaseUrl/slides/proxy?url=${Uri.encodeComponent(url)}');
        final res = await http.get(proxyUri).timeout(const Duration(seconds: 30));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Resuelve la información según la plataforma detectada
  Future<Map<String, dynamic>> resolvePresentationInfo(String inputStr) async {
    final platform = detectPlatform(inputStr);

    switch (platform) {
      case SlidePlatform.googleSlides:
        return _resolveGoogleSlidesInfo(inputStr);
      case SlidePlatform.slideShare:
        return _resolveSlideShareInfo(inputStr);
      case SlidePlatform.speakerDeck:
        return _resolveSpeakerDeckInfo(inputStr);
      case SlidePlatform.directPdf:
        return _resolveDirectPdfInfo(inputStr);
      case SlidePlatform.canva:
        return _resolveCanvaInfo(inputStr);
      case SlidePlatform.prezi:
      case SlidePlatform.generic:
        return _resolvePreziInfo(inputStr);
    }
  }

  // ===========================================================================
  // 1. RESOLVER GOOGLE SLIDES
  // ===========================================================================
  Future<Map<String, dynamic>> _resolveGoogleSlidesInfo(String url) async {
    final idMatch = RegExp(r'/presentation/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    final docId = idMatch?.group(1) ?? 'google_slides';

    String title = 'Presentación Google Slides';
    final html = await fetchHtml(url);
    if (html != null) {
      final titleMatch = RegExp(r'<title>(.*?)(?: - Google Slides| - Presentaciones de Google)?</title>', caseSensitive: false)
          .firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.replaceAll('&amp;', '&').trim() ?? title;
      }
    }

    final exportPdfUrl = 'https://docs.google.com/presentation/d/$docId/export/pdf';

    return {
      'oid': docId,
      'platform': SlidePlatform.googleSlides,
      'prezilink': null,
      'title': title,
      'isVideo': false,
      'originalUrl': url,
      'exportPdfUrl': exportPdfUrl,
    };
  }

  // ===========================================================================
  // 2. RESOLVER SLIDESHARE
  // ===========================================================================
  Future<Map<String, dynamic>> _resolveSlideShareInfo(String url) async {
    String title = 'Presentación SlideShare';
    List<String> slideImageUrls = [];
    final html = await fetchHtml(url);

    if (html != null) {
      final titleMatch = RegExp(r'<title>(.*?)(?: \| SlideShare)?</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.replaceAll('&amp;', '&').trim() ?? title;
      }

      // Extraer URLs de diapositivas en máxima resolución
      final matches = RegExp(r'data-full-url="([^"]+)"').allMatches(html).map((m) => m.group(1)!).toList();
      if (matches.isNotEmpty) {
        slideImageUrls = matches;
      } else {
        final matches2 = RegExp(r'srcset="([^"\s]+)\s+2048w"').allMatches(html).map((m) => m.group(1)!).toList();
        if (matches2.isNotEmpty) {
          slideImageUrls = matches2;
        } else {
          final matches3 = RegExp(r'src="([^"]+slide-\d+[^"]+)"').allMatches(html).map((m) => m.group(1)!).toList();
          slideImageUrls = matches3.toSet().toList();
        }
      }
    }

    return {
      'oid': 'slideshare_${DateTime.now().millisecondsSinceEpoch}',
      'platform': SlidePlatform.slideShare,
      'prezilink': null,
      'title': title,
      'isVideo': false,
      'originalUrl': url,
      'slideImageUrls': slideImageUrls,
    };
  }

  // ===========================================================================
  // 3. RESOLVER SPEAKER DECK
  // ===========================================================================
  Future<Map<String, dynamic>> _resolveSpeakerDeckInfo(String url) async {
    String title = 'Presentación Speaker Deck';
    String? pdfUrl;
    List<String> slideImages = [];

    final html = await fetchHtml(url);
    if (html != null) {
      final titleMatch = RegExp(r'<title>(.*?)(?: // Speaker Deck)?</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.replaceAll('&amp;', '&').trim() ?? title;
      }

      // Enlace directo a PDF de Speaker Deck
      final pdfMatch = RegExp(r'href="([^"]+\.pdf[^"]*)"').firstMatch(html);
      if (pdfMatch != null) {
        pdfUrl = pdfMatch.group(1);
      }

      final imgMatches = RegExp(r'data-slide-image="([^"]+)"').allMatches(html).map((m) => m.group(1)!).toList();
      if (imgMatches.isNotEmpty) {
        slideImages = imgMatches;
      }
    }

    return {
      'oid': 'speakerdeck_${DateTime.now().millisecondsSinceEpoch}',
      'platform': SlidePlatform.speakerDeck,
      'prezilink': null,
      'title': title,
      'isVideo': false,
      'originalUrl': url,
      'pdfUrl': pdfUrl,
      'slideImageUrls': slideImages,
    };
  }

  // ===========================================================================
  // 4. RESOLVER DOCUMENTO PDF DIRECTO
  // ===========================================================================
  Future<Map<String, dynamic>> _resolveDirectPdfInfo(String url) async {
    final uri = Uri.parse(url);
    var filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'documento.pdf';
    filename = filename.replaceAll('.pdf', '').replaceAll('_', ' ').replaceAll('-', ' ');

    return {
      'oid': 'pdf_${DateTime.now().millisecondsSinceEpoch}',
      'platform': SlidePlatform.directPdf,
      'prezilink': null,
      'title': filename.isNotEmpty ? filename : 'Documento de Diapositivas PDF',
      'isVideo': false,
      'originalUrl': url,
      'directPdfUrl': url,
    };
  }

  // ===========================================================================
  // 5. RESOLVER CANVA
  // ===========================================================================
  Future<Map<String, dynamic>> _resolveCanvaInfo(String url) async {
    String title = 'Diseño / Presentación de Canva';
    final html = await fetchHtml(url);
    if (html != null) {
      final titleMatch = RegExp(r'<title>(.*?)(?: - Canva)?</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.replaceAll('&amp;', '&').trim() ?? title;
      }
    }
    return {
      'oid': 'canva_${DateTime.now().millisecondsSinceEpoch}',
      'platform': SlidePlatform.canva,
      'prezilink': null,
      'title': title,
      'isVideo': false,
      'originalUrl': url,
    };
  }

  // ===========================================================================
  // 6. RESOLVER PREZI
  // ===========================================================================
  Future<Map<String, dynamic>> _resolvePreziInfo(String inputStr) async {
    final inputClean = inputStr.trim();
    final isVideo = inputClean.contains('prezi.com/v/');

    final isUrl = inputClean.startsWith('http://') ||
        inputClean.startsWith('https://') ||
        inputClean.contains('prezi.com');

    String? viewUrl;
    if (!isUrl && inputClean.length >= 18) {
      viewUrl = 'https://prezi.com/view/$inputClean/';
    } else if (isUrl) {
      viewUrl = inputClean.startsWith('http') ? inputClean : 'https://$inputClean';
    }

    if (viewUrl != null && (viewUrl.contains('/view/') || inputClean.length >= 18)) {
      try {
        final html = await fetchHtml(viewUrl);
        if (html != null) {
          final oidMatches = RegExp(r"""prezi_oid["'\\]*:\s*["'\\]*([a-zA-Z0-9_-]+)""").allMatches(html).toList();
          final fallbackOidMatches = RegExp(r"""oid["'\\]*:\s*["'\\]*([a-zA-Z0-9_-]+)""").allMatches(html).toList();
          final resolvedOid = oidMatches.isNotEmpty
              ? oidMatches.first.group(1)
              : (fallbackOidMatches.isNotEmpty ? fallbackOidMatches.first.group(1) : null);

          final linkMatches = RegExp(r"""link_id["'\\]*:\s*["'\\]*([a-zA-Z0-9_-]+)""").allMatches(html).toList();
          String? resolvedLink = linkMatches.isNotEmpty ? linkMatches.first.group(1) : null;
          if (resolvedLink == null) {
            final tokenMatch = RegExp(r'/view/([a-zA-Z0-9_-]+)').firstMatch(viewUrl);
            if (tokenMatch != null) resolvedLink = tokenMatch.group(1);
          }

          final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
          String? resolvedTitle;
          if (titleMatch != null) {
            resolvedTitle = titleMatch
                .group(1)
                ?.replaceAll(' | Prezi', '')
                .replaceAll('&amp;', '&')
                .trim();
          }

          if (resolvedOid != null) {
            return {
              'oid': resolvedOid,
              'platform': SlidePlatform.prezi,
              'prezilink': resolvedLink,
              'title': resolvedTitle ?? resolvedOid,
              'isVideo': isVideo,
              'originalUrl': viewUrl,
            };
          }
        }
      } catch (e) {
        debugPrint('Aviso al resolver enlace de Prezi: $e');
      }
    }

    final directId = extractId(inputClean) ?? inputClean;
    return {
      'oid': directId,
      'platform': SlidePlatform.prezi,
      'prezilink': null,
      'title': directId,
      'isVideo': isVideo,
      'originalUrl': viewUrl ?? inputClean,
    };
  }

  /// Obtiene el contenido de Prezi Video
  Future<Map<String, dynamic>?> fetchPreziVideoContent(String id) async {
    final url = 'https://prezi.com/api/v5/presentation-content/$id/';
    try {
      if (backendBaseUrl != null) {
        try {
          final proxyUri = Uri.parse('$backendBaseUrl/prezi/video-content?id=$id');
          final res = await http.get(proxyUri).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            return jsonDecode(res.body);
          }
        } catch (_) {}
      }

      final res = await http.get(Uri.parse(url), headers: _standardHeaders).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error al obtener video de Prezi: $e');
    }
    return null;
  }

  /// Obtiene el storyboard con las diapositivas y metadatos de Prezi
  Future<Map<String, dynamic>> fetchStoryboard({
    required String id,
    String? prezilink,
    void Function(String message, double progress)? onProgress,
  }) async {
    var apiUrl = 'https://prezi.com/api/v2/storyboard/$id/';
    if (prezilink != null && prezilink.isNotEmpty) {
      apiUrl += '?prezilink=$prezilink';
    }

    const maxRetries = 25;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      onProgress?.call('Solicitando diapositivas a la API de Prezi (intento ${attempt + 1})...', 0.1);

      http.Response? response;
      if (backendBaseUrl != null) {
        try {
          final proxyUrl = '$backendBaseUrl/prezi/storyboard?id=$id${prezilink != null ? '&prezilink=$prezilink' : ''}';
          response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 15));
        } catch (_) {}
      }

      if (response == null || response.statusCode != 200) {
        try {
          response = await http.get(Uri.parse(apiUrl), headers: _standardHeaders).timeout(const Duration(seconds: 30));
        } catch (e) {
          if (attempt == maxRetries - 1) {
            throw Exception('Error de red al conectar con Prezi: $e');
          }
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
      }

      if (response.statusCode == 403) {
        throw Exception('Error 403 (Prohibido): La presentación "$id" es privada o requiere permisos de acceso.');
      } else if (response.statusCode == 404) {
        throw Exception('Error 404 (No encontrada): No se encontró la presentación con ID "$id".');
      } else if (response.statusCode != 200) {
        throw Exception('Error del servidor de Prezi (HTTP ${response.statusCode})');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Error al decodificar los datos JSON recibidos de Prezi.');
      }

      final status = data['status'];
      if (status == 'wait') {
        onProgress?.call('Prezi está renderizando las diapositivas (${attempt + 1}/$maxRetries)...', 0.15);
        await Future.delayed(const Duration(seconds: 3));
        continue;
      } else if (status == 'success' || data.containsKey('steps')) {
        return data;
      } else {
        throw Exception('Respuesta inesperada de Prezi: $status');
      }
    }

    throw Exception('Tiempo de espera agotado esperando a que Prezi genere las diapositivas.');
  }

  /// Compara si dos pasos de Prezi pertenecen a la misma vista
  bool areSameView(Map<String, dynamic> s1, Map<String, dynamic> s2) {
    final c1 = s1['camera'];
    final c2 = s2['camera'];
    if (c1 is Map && c2 is Map) {
      try {
        final x1 = (c1['x'] as num).toDouble();
        final y1 = (c1['y'] as num).toDouble();
        final z1 = (c1['zoom'] as num).toDouble();
        final r1 = ((c1['rotation'] ?? 0) as num).toDouble();

        final x2 = (c2['x'] as num).toDouble();
        final y2 = (c2['y'] as num).toDouble();
        final z2 = (c2['zoom'] as num).toDouble();
        final r2 = ((c2['rotation'] ?? 0) as num).toDouble();

        if ((x1 - x2).abs() < 1e-3 &&
            (y1 - y2).abs() < 1e-3 &&
            (z1 - z2).abs() < 1e-3 &&
            (r1 - r2).abs() < 1e-3) {
          return true;
        }
      } catch (_) {}
    }

    final si1 = s1['step_index'];
    final si2 = s2['step_index'];
    if (si1 != null && si2 != null && si1 == si2) {
      if (s2['type'] == 'animation') {
        return true;
      }
    }

    return false;
  }

  /// Filtra pasos y transiciones conservando solo la diapositiva final completa
  List<Map<String, dynamic>> filterTransitionSteps(List<dynamic> steps) {
    if (steps.isEmpty) return [];

    final typedSteps = steps.whereType<Map<String, dynamic>>().toList();
    final List<Map<String, dynamic>> filtered = [];
    final n = typedSteps.length;
    int i = 0;

    while (i < n) {
      int j = i;
      while (j + 1 < n && areSameView(typedSteps[j], typedSteps[j + 1])) {
        j++;
      }
      filtered.add(typedSteps[j]);
      i = j + 1;
    }

    return filtered;
  }

  /// Extrae videos incrustados dentro de los pasos (YouTube, Vimeo, MP4, etc.)
  List<PreziVideoItem> extractEmbeddedVideos(List<dynamic> steps) {
    final List<PreziVideoItem> videos = [];
    final Set<String> seenUrls = {};

    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      if (s is! Map<String, dynamic>) continue;

      String? vUrl = s['url'] as String?;
      if ((vUrl == null || vUrl.isEmpty) && s['video'] is Map) {
        vUrl = s['video']['url'] as String?;
      }

      final service = (s['videoService'] as String?) ?? '';
      final stype = (s['type'] as String?) ?? '';

      final isVideoStep = stype == 'video' ||
          service.isNotEmpty ||
          (vUrl != null &&
              ['.mp4', '.webm', 'youtube', 'youtu.be', 'vimeo'].any((ext) => vUrl!.toLowerCase().contains(ext)));

      if (isVideoStep && vUrl != null && vUrl.trim().isNotEmpty) {
        final cleanUrl = vUrl.trim();
        if (!seenUrls.contains(cleanUrl)) {
          seenUrls.add(cleanUrl);

          String? thumbUrl;
          final images = s['images'];
          if (images is List && images.isNotEmpty && images[0] is Map && images[0]['url'] != null) {
            thumbUrl = images[0]['url'] as String;
          }

          if (thumbUrl == null || thumbUrl.isEmpty) {
            final ytId = _extractYouTubeId(cleanUrl);
            if (ytId != null) {
              thumbUrl = 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';
            }
          }

          final videoTitle = 'Video #${videos.length + 1} (Diapositiva ${i + 1})';

          videos.add(
            PreziVideoItem(
              id: 'video_${i + 1}_${DateTime.now().millisecondsSinceEpoch}',
              stepIndex: i + 1,
              service: service.isNotEmpty ? service : (stype == 'video' ? 'mp4' : 'video'),
              url: cleanUrl,
              thumbnailUrl: thumbUrl,
              title: videoTitle,
              isSelected: true,
            ),
          );
        }
      }
    }

    return videos;
  }

  String? _extractYouTubeId(String url) {
    final match = RegExp(r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})').firstMatch(url);
    return match?.group(1);
  }

  bool areBytesIdentical(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.lengthInBytes != b.lengthInBytes) return false;
    for (int i = 0; i < a.lengthInBytes; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Construye un archivo PDF directamente desde una lista de URLs de imágenes (SlideShare, Speaker Deck, etc.)
  Future<Uint8List> buildPdfFromImageUrls({
    required List<String> imageUrls,
    required String title,
    void Function(String message, double progress, int current, int total)? onProgress,
  }) async {
    final total = imageUrls.length;
    if (total == 0) throw Exception('No se detectaron diapositivas descargables.');

    onProgress?.call('Descargando diapositivas de la presentación...', 0.2, 0, total);
    final List<Uint8List> validSlides = [];

    for (int i = 0; i < total; i++) {
      final imgBytes = await fetchBinary(imageUrls[i]);
      if (imgBytes != null && imgBytes.isNotEmpty) {
        validSlides.add(imgBytes);
      }
      final pct = 0.2 + ((i + 1) / total) * 0.7;
      onProgress?.call('Descargando diapositiva ${i + 1} de $total...', pct, i + 1, total);
    }

    if (validSlides.isEmpty) {
      throw Exception('No se pudo descargar ninguna imagen válida de las diapositivas.');
    }

    onProgress?.call('Compilando documento PDF (${validSlides.length} páginas)...', 0.94, total, total);

    final pdf = pw.Document(
      title: title,
      author: 'Sanctuary Slide Downloader',
      creator: 'Sanctuary Digital Platform',
    );

    for (int p = 0; p < validSlides.length; p++) {
      final slideBytes = validSlides[p];
      final image = pw.MemoryImage(slideBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(1920, 1080),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  /// Descarga las diapositivas de Prezi en paralelo y compila el documento PDF
  Future<Uint8List> downloadSlidesAndBuildPdf({
    required List<Map<String, dynamic>> steps,
    required String presentationTitle,
    bool filterDuplicates = true,
    void Function(String message, double progress, int current, int total)? onProgress,
  }) async {
    final total = steps.length;
    if (total == 0) {
      throw Exception('No hay diapositivas para procesar.');
    }

    onProgress?.call('Iniciando descarga paralela de $total diapositivas...', 0.2, 0, total);

    final List<Uint8List?> downloadedSlides = List<Uint8List?>.filled(total, null);
    int completedCount = 0;

    const batchSize = 6;
    for (int i = 0; i < total; i += batchSize) {
      final end = math.min(i + batchSize, total);
      final batchFutures = <Future<void>>[];

      for (int j = i; j < end; j++) {
        final stepIndex = j;
        final step = steps[stepIndex];
        final images = step['images'];
        if (images is! List || images.isEmpty || images[0] is! Map || images[0]['url'] == null) {
          completedCount++;
          continue;
        }

        final imgUrl = images[0]['url'] as String;

        batchFutures.add(
          fetchBinary(imgUrl).then((bytes) {
            downloadedSlides[stepIndex] = bytes;
            completedCount++;
            final pct = 0.2 + (completedCount / total) * 0.65;
            onProgress?.call(
              'Descargando diapositiva $completedCount de $total...',
              pct,
              completedCount,
              total,
            );
          }),
        );
      }

      await Future.wait(batchFutures);
    }

    onProgress?.call('Depurando diapositivas y optimizando resolución...', 0.88, completedCount, total);
    final List<Uint8List> validSlides = [];
    Uint8List? lastSlide;

    for (final bytes in downloadedSlides) {
      if (bytes != null && bytes.isNotEmpty) {
        if (filterDuplicates && lastSlide != null) {
          if (areBytesIdentical(bytes, lastSlide)) {
            continue;
          }
        }
        validSlides.add(bytes);
        lastSlide = bytes;
      }
    }

    if (validSlides.isEmpty) {
      throw Exception('No se pudo descargar ninguna imagen válida de las diapositivas.');
    }

    onProgress?.call('Compilando documento PDF con ${validSlides.length} páginas...', 0.94, completedCount, total);

    final pdf = pw.Document(
      title: presentationTitle,
      author: 'Sanctuary Slide Downloader',
      creator: 'Sanctuary Digital Platform',
    );

    for (int p = 0; p < validSlides.length; p++) {
      final slideBytes = validSlides[p];
      final image = pw.MemoryImage(slideBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(1920, 1080),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            );
          },
        ),
      );
    }

    onProgress?.call('Finalizando archivo PDF de alta definición...', 0.98, completedCount, total);
    return await pdf.save();
  }
}
