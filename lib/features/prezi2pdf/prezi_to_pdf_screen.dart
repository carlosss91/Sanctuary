import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/trayectoria_sidebar.dart';
import '../../core/widgets/sanctuary_planet_logo.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_service.dart';
import '../hub/user_profile_dialog.dart';
import 'models/prezi_model.dart';
import 'services/prezi_service.dart';

class PreziToPdfScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBackToHub;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleCosmic;
  final VoidCallback? onOpenCvBuilder;
  final VoidCallback? onOpenPdfSigner;
  final VoidCallback? onOpenAdminPanel;
  final bool isDark;
  final bool isCosmicActive;

  const PreziToPdfScreen({
    super.key,
    required this.apiService,
    required this.onBackToHub,
    this.onOpenCvBuilder,
    this.onOpenPdfSigner,
    this.onOpenAdminPanel,
    required this.onLogout,
    required this.onToggleTheme,
    required this.onToggleCosmic,
    required this.isDark,
    required this.isCosmicActive,
  });

  @override
  State<PreziToPdfScreen> createState() => _PreziToPdfScreenState();
}

class _PreziToPdfScreenState extends State<PreziToPdfScreen> {
  late final PreziService _preziService;
  final TextEditingController _urlController = TextEditingController();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _filterTransitions = true;
  bool _filterDuplicates = true;

  SlidePlatform _detectedPlatform = SlidePlatform.prezi;
  PreziConversionState _state = const PreziConversionState();
  List<PreziVideoItem> _detectedVideos = [];
  final Set<String> _downloadingVideoIds = {};
  bool _isBatchDownloading = false;

  // Master checkbox state
  bool get _isAllVideosSelected =>
      _detectedVideos.isNotEmpty && _detectedVideos.every((v) => v.isSelected);

  int get _selectedVideosCount =>
      _detectedVideos.where((v) => v.isSelected).length;

  @override
  void initState() {
    super.initState();
    _preziService = PreziService(backendBaseUrl: widget.apiService.baseUrl);
    _urlController.text = 'https://prezi.com/view/fa_waqixoa-l/';
    _updateDetectedPlatform(_urlController.text);
    _urlController.addListener(() {
      _updateDetectedPlatform(_urlController.text);
    });
  }

  void _updateDetectedPlatform(String text) {
    final platform = _preziService.detectPlatform(text);
    if (platform != _detectedPlatform) {
      setState(() {
        _detectedPlatform = platform;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _toggleSelectAllVideos(bool? value) {
    final select = value ?? false;
    setState(() {
      for (final video in _detectedVideos) {
        video.isSelected = select;
      }
    });
  }

  void _toggleSingleVideo(PreziVideoItem video, bool? value) {
    setState(() {
      video.isSelected = value ?? false;
    });
  }

  void _applySampleUrl(SlidePlatform platform) {
    String sample;
    switch (platform) {
      case SlidePlatform.prezi:
        sample = 'https://prezi.com/view/fa_waqixoa-l/';
        break;
      case SlidePlatform.googleSlides:
        sample = 'https://docs.google.com/presentation/d/1_sample_deck/edit';
        break;
      case SlidePlatform.slideShare:
        sample = 'https://www.slideshare.net/slideshow/git-basics/12345';
        break;
      case SlidePlatform.speakerDeck:
        sample = 'https://speakerdeck.com/user/presentation-sample';
        break;
      case SlidePlatform.directPdf:
        sample = 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';
        break;
      default:
        sample = 'https://prezi.com/view/fa_waqixoa-l/';
    }
    setState(() {
      _urlController.text = sample;
      _updateDetectedPlatform(sample);
    });
  }

  Future<void> _startConversion() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, introduce un enlace de presentación válido.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _detectedVideos = [];
      _state = PreziConversionState(
        phase: PreziProcessPhase.analyzing,
        progress: 0.05,
        message: 'Detectando plataforma y analizando estructura de la presentación...',
      );
    });

    try {
      // 1. Resolver información según la plataforma
      final info = await _preziService.resolvePresentationInfo(input);
      final platform = (info['platform'] as SlidePlatform?) ?? _detectedPlatform;
      final oid = (info['oid'] as String?) ?? 'deck';
      final title = (info['title'] as String?) ?? 'Presentación';

      setState(() {
        _state = _state.copyWith(
          phase: PreziProcessPhase.fetchingStoryboard,
          progress: 0.15,
          message: 'Conectando con ${platform.displayName}...',
          presentationInfo: PreziPresentationInfo(
            id: oid,
            platform: platform,
            title: title,
            originalUrl: input,
          ),
        );
      });

      // =======================================================================
      // A. FLUJO GOOGLE SLIDES (EXPORTACIÓN DIRECTA A PDF OFICIAL)
      // =======================================================================
      if (platform == SlidePlatform.googleSlides) {
        final exportUrl = info['exportPdfUrl'] as String;
        setState(() {
          _state = _state.copyWith(
            phase: PreziProcessPhase.downloadingSlides,
            progress: 0.35,
            message: 'Generando y descargando PDF oficial desde Google Docs...',
          );
        });

        final pdfBytes = await _preziService.fetchBinary(exportUrl);
        if (pdfBytes == null || pdfBytes.isEmpty) {
          throw Exception('No se pudo exportar la presentación. Asegúrate de que el enlace sea público o con acceso para lectores.');
        }

        final safeTitle = title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '').trim();
        setState(() {
          _state = _state.copyWith(
            phase: PreziProcessPhase.completed,
            progress: 1.0,
            message: '¡Presentación de Google Slides descargada con éxito en PDF vectorial!',
            generatedPdfBytes: pdfBytes,
            generatedPdfFilename: '$safeTitle.pdf',
          );
        });
        return;
      }

      // =======================================================================
      // B. FLUJO DOCUMENTO PDF DIRECTO
      // =======================================================================
      if (platform == SlidePlatform.directPdf) {
        setState(() {
          _state = _state.copyWith(
            phase: PreziProcessPhase.downloadingSlides,
            progress: 0.4,
            message: 'Descargando documento de diapositivas PDF...',
          );
        });

        final pdfBytes = await _preziService.fetchBinary(input);
        if (pdfBytes == null || pdfBytes.isEmpty) {
          throw Exception('No se pudo descargar el archivo PDF desde la dirección URL proporcionada.');
        }

        final safeTitle = title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '').trim();
        setState(() {
          _state = _state.copyWith(
            phase: PreziProcessPhase.completed,
            progress: 1.0,
            message: '¡Documento PDF de diapositivas listo para visualizar y guardar!',
            generatedPdfBytes: pdfBytes,
            generatedPdfFilename: '$safeTitle.pdf',
          );
        });
        return;
      }

      // =======================================================================
      // C. FLUJO SLIDESHARE O SPEAKER DECK (DESDE IMÁGENES DE DIAPOSITIVAS)
      // =======================================================================
      if (platform == SlidePlatform.slideShare || platform == SlidePlatform.speakerDeck) {
        final pdfDirectUrl = info['pdfUrl'] as String?;
        if (pdfDirectUrl != null && pdfDirectUrl.isNotEmpty) {
          final pdfBytes = await _preziService.fetchBinary(pdfDirectUrl);
          if (pdfBytes != null && pdfBytes.isNotEmpty) {
            final safeTitle = title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '').trim();
            setState(() {
              _state = _state.copyWith(
                phase: PreziProcessPhase.completed,
                progress: 1.0,
                message: '¡Presentación descargada con éxito en formato PDF!',
                generatedPdfBytes: pdfBytes,
                generatedPdfFilename: '$safeTitle.pdf',
              );
            });
            return;
          }
        }

        final slideImages = (info['slideImageUrls'] as List<String>?) ?? [];
        if (slideImages.isNotEmpty) {
          final pdfBytes = await _preziService.buildPdfFromImageUrls(
            imageUrls: slideImages,
            title: title,
            onProgress: (msg, pct, curr, total) {
              setState(() {
                _state = _state.copyWith(
                  message: msg,
                  progress: pct,
                  currentItem: curr,
                  totalItems: total,
                  phase: pct >= 0.9 ? PreziProcessPhase.compilingPdf : PreziProcessPhase.downloadingSlides,
                );
              });
            },
          );

          final safeTitle = title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '').trim();
          setState(() {
            _state = _state.copyWith(
              phase: PreziProcessPhase.completed,
              progress: 1.0,
              message: '¡Presentación de ${platform.displayName} compilada en PDF (${slideImages.length} diapositivas)!',
              generatedPdfBytes: pdfBytes,
              generatedPdfFilename: '$safeTitle.pdf',
            );
          });
          return;
        }
      }

      // =======================================================================
      // D. FLUJO PREZI Y PREZI VIDEO
      // =======================================================================
      final prezilink = info['prezilink'] as String?;
      final isVideo = (info['isVideo'] as bool?) ?? false;

      if (isVideo) {
        final videoContent = await _preziService.fetchPreziVideoContent(oid);
        String? videoSignedUrl;
        String videoTitle = title;
        if (videoContent != null && videoContent['meta'] is Map) {
          final meta = videoContent['meta'] as Map<String, dynamic>;
          videoTitle = (meta['title'] as String?) ?? title;
          videoSignedUrl = meta['video_signed_url_with_title'] as String?;
        }

        final videoItem = PreziVideoItem(
          id: 'prezi_video_$oid',
          stepIndex: 1,
          service: 'prezi_video',
          url: videoSignedUrl ?? input,
          title: videoTitle,
          isSelected: true,
        );

        setState(() {
          _detectedVideos = [videoItem];
          _state = _state.copyWith(
            phase: PreziProcessPhase.completed,
            progress: 1.0,
            message: '¡Prezi Video detectado con éxito!',
            presentationInfo: _state.presentationInfo?.copyWith(
              title: videoTitle,
              videos: [videoItem],
              signedVideoUrl: videoSignedUrl,
            ),
          );
        });
        return;
      }

      // Storyboard estándar de Prezi
      final storyboard = await _preziService.fetchStoryboard(
        id: oid,
        prezilink: prezilink,
        onProgress: (msg, pct) {
          setState(() {
            _state = _state.copyWith(message: msg, progress: pct);
          });
        },
      );

      final rawSteps = storyboard['steps'] as List<dynamic>? ?? [];
      if (rawSteps.isEmpty) {
        throw Exception('La presentación no contiene ninguna diapositiva procesable.');
      }

      final originalCount = rawSteps.length;
      final extractedVideos = _preziService.extractEmbeddedVideos(rawSteps);
      setState(() {
        _detectedVideos = extractedVideos;
      });

      List<Map<String, dynamic>> stepsToProcess;
      int skippedTransitions = 0;
      if (_filterTransitions) {
        stepsToProcess = _preziService.filterTransitionSteps(rawSteps);
        skippedTransitions = originalCount - stepsToProcess.length;
      } else {
        stepsToProcess = rawSteps.whereType<Map<String, dynamic>>().toList();
      }

      setState(() {
        _state = _state.copyWith(
          phase: PreziProcessPhase.downloadingSlides,
          progress: 0.25,
          totalItems: stepsToProcess.length,
          currentItem: 0,
          message: 'Descargando ${stepsToProcess.length} diapositivas en alta resolución...',
          presentationInfo: _state.presentationInfo?.copyWith(
            totalSteps: originalCount,
            filteredStepsCount: stepsToProcess.length,
            videos: extractedVideos,
          ),
        );
      });

      final pdfBytes = await _preziService.downloadSlidesAndBuildPdf(
        steps: stepsToProcess,
        presentationTitle: title,
        filterDuplicates: _filterDuplicates,
        onProgress: (msg, pct, curr, total) {
          setState(() {
            _state = _state.copyWith(
              message: msg,
              progress: pct,
              currentItem: curr,
              totalItems: total,
              phase: pct >= 0.90 ? PreziProcessPhase.compilingPdf : PreziProcessPhase.downloadingSlides,
            );
          });
        },
      );

      final safeTitle = title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '').trim();
      final filename = '$safeTitle.pdf';

      setState(() {
        _state = _state.copyWith(
          phase: PreziProcessPhase.completed,
          progress: 1.0,
          message: '¡Presentación convertida con éxito a PDF! ($skippedTransitions transiciones depuradas)',
          generatedPdfBytes: pdfBytes,
          generatedPdfFilename: filename,
        );
      });
    } catch (e) {
      setState(() {
        _state = _state.copyWith(
          phase: PreziProcessPhase.error,
          progress: 0.0,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  Future<void> _shareOrDownloadPdf() async {
    if (_state.generatedPdfBytes == null) return;
    try {
      await Printing.sharePdf(
        bytes: _state.generatedPdfBytes!,
        filename: _state.generatedPdfFilename ?? 'Presentacion_Slides.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar PDF: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _previewPdf() async {
    if (_state.generatedPdfBytes == null) return;
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _state.generatedPdfBytes!,
        name: _state.generatedPdfFilename ?? 'Presentacion_Slides.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al visualizar PDF: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _downloadSelectedVideos() async {
    final selected = _detectedVideos.where((v) => v.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ningún video seleccionado para descargar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selected.length == 1) {
      // Si solo hay un video seleccionado, descargarlo directamente a disco
      await _downloadSingleVideo(selected.first);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.download_for_offline_rounded, color: AppTheme.emerald),
              const SizedBox(width: 10),
              Text(
                'Descarga de ${selected.length} Videos',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Elige cómo deseas descargar los vídeos a tu equipo o previsualizarlos:',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.folder_zip_rounded, size: 18, color: AppTheme.emerald),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recomendado: "Descargar en ZIP" agrupa todos los vídeos en un único archivo comprimido, garantizando que el navegador no bloquee descargas automáticas múltiples.',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (_) {
                    final cachedCount = selected.where((v) => _preziService.hasCachedVideo(v.url)).length;
                    if (cachedCount == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.offline_bolt_rounded, size: 16, color: Colors.cyanAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$cachedCount de ${selected.length} vídeos ya están en caché de memoria (descarga inmediata).',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: selected.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (context, idx) {
                      final vid = selected[idx];
                      final isCached = _preziService.hasCachedVideo(vid.url);

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: isCached ? AppTheme.emerald.withOpacity(0.2) : AppTheme.emerald.withOpacity(0.15),
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCached ? AppTheme.emerald : null,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                vid.title,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCached)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  'En caché',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${vid.serviceDisplayName} · Paso #${vid.stepIndex}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blueAccent),
                              tooltip: 'Previsualizar en pestaña',
                              onPressed: () => _openVideoPreview(vid.url),
                            ),
                            IconButton(
                              icon: Icon(
                                isCached ? Icons.check_circle_outline_rounded : Icons.download_rounded,
                                size: 18,
                                color: AppTheme.emerald,
                              ),
                              tooltip: isCached ? 'Guardar desde caché' : 'Descargar archivo a disco',
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _downloadSingleVideo(vid);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Previsualizar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.black87,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                for (final vid in selected) {
                  await _openVideoPreview(vid.url);
                  await Future.delayed(const Duration(milliseconds: 600));
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 15),
              label: const Text('Uno a Uno (.mp4)'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _startBatchDownload(selected);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_zip_rounded, size: 16),
              label: Text('Descargar en ZIP (${selected.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _startBatchDownloadZip(selected);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startBatchDownloadZip(List<PreziVideoItem> selected) async {
    setState(() => _isBatchDownloading = true);

    final archive = Archive();
    final List<PreziVideoItem> successVideos = [];
    final List<({PreziVideoItem video, String reason})> failedVideos = [];
    final List<PreziVideoItem> skippedVideos = [];

    for (int i = 0; i < selected.length; i++) {
      final video = selected[i];
      if (video.isYouTube || video.isVimeo) {
        skippedVideos.add(video);
        continue;
      }

      setState(() => _downloadingVideoIds.add(video.id));

      final isAlreadyCached = _preziService.hasCachedVideo(video.url);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAlreadyCached
                        ? 'Obteniendo vídeo ${i + 1} de ${selected.length} (desde caché): "${video.title}"...'
                        : 'Descargando vídeo ${i + 1} de ${selected.length}: "${video.title}"...',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 45),
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      }

      try {
        final bytes = await _preziService.fetchVideoBytes(video.url);
        if (bytes != null && bytes.isNotEmpty) {
          final safeName = _buildSafeVideoFilename(index: i, video: video);
          archive.addFile(ArchiveFile(safeName, bytes.length, bytes));
          successVideos.add(video);
        } else {
          failedVideos.add((video: video, reason: 'Tiempo de espera agotado o restricción CORS'));
        }
      } catch (e) {
        debugPrint('Error en descarga de vídeo (${video.title}): $e');
        failedVideos.add((video: video, reason: e.toString()));
      } finally {
        if (mounted) {
          setState(() => _downloadingVideoIds.remove(video.id));
        }
      }
    }

    if (successVideos.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(child: Text('Empaquetando ${successVideos.length} vídeos en archivo .ZIP...')),
              ],
            ),
            duration: const Duration(seconds: 15),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }

      try {
        final zipData = ZipEncoder().encode(archive);
        if (zipData.isNotEmpty) {
          final title = _state.presentationInfo?.title ?? 'Presentacion';
          final cleanTitle = title.replaceAll(RegExp(r'[^\w\.-]'), '_');
          final zipName = '${cleanTitle}_Videos.zip';
          await Printing.sharePdf(bytes: Uint8List.fromList(zipData), filename: zipName);

          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (failedVideos.isEmpty && skippedVideos.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✔ ¡Todos los vídeos (${successVideos.length}) se han guardado con éxito en $zipName!'),
                  backgroundColor: AppTheme.emerald,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error al crear ZIP de vídeos: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al comprimir vídeos: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isBatchDownloading = false);
    }

    // Si algún vídeo falló o fue omitido, mostrar diálogo detallado con opciones de recuperación
    if (mounted && (failedVideos.isNotEmpty || skippedVideos.isNotEmpty)) {
      _showBatchDownloadSummaryDialog(
        isZip: true,
        successVideos: successVideos,
        failedVideos: failedVideos,
        skippedVideos: skippedVideos,
        originalSelected: selected,
      );
    }
  }

  Future<void> _startBatchDownload(List<PreziVideoItem> selected) async {
    setState(() => _isBatchDownloading = true);

    final List<PreziVideoItem> successVideos = [];
    final List<({PreziVideoItem video, String reason})> failedVideos = [];
    final List<PreziVideoItem> skippedVideos = [];

    for (int i = 0; i < selected.length; i++) {
      final video = selected[i];
      if (video.isYouTube || video.isVimeo) {
        skippedVideos.add(video);
        continue;
      }

      setState(() => _downloadingVideoIds.add(video.id));

      final isAlreadyCached = _preziService.hasCachedVideo(video.url);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAlreadyCached
                        ? 'Recuperando vídeo ${i + 1} de ${selected.length} (desde caché): "${video.title}"...'
                        : 'Descargando vídeo individual ${i + 1} de ${selected.length}: "${video.title}"...',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 25),
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      }

      try {
        final bytes = await _preziService.fetchVideoBytes(video.url);
        if (bytes != null && bytes.isNotEmpty) {
          final safeName = _buildSafeVideoFilename(index: i, video: video);
          await Printing.sharePdf(bytes: bytes, filename: safeName);
          successVideos.add(video);
        } else {
          failedVideos.add((video: video, reason: 'Tiempo de espera agotado o bloqueo de red / CORS'));
        }
      } catch (e) {
        debugPrint('Error en descarga de lote (${video.title}): $e');
        failedVideos.add((video: video, reason: e.toString()));
      } finally {
        if (mounted) {
          setState(() => _downloadingVideoIds.remove(video.id));
        }
      }

      // Pausa secuencial controlada de 1.4s si fue descarga de red
      if (!isAlreadyCached) {
        await Future.delayed(const Duration(milliseconds: 1400));
      }
    }

    if (mounted) {
      setState(() => _isBatchDownloading = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (failedVideos.isEmpty && skippedVideos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✔ ¡Se han procesado las descargas de todos los vídeos (${successVideos.length})!'),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        _showBatchDownloadSummaryDialog(
          isZip: false,
          successVideos: successVideos,
          failedVideos: failedVideos,
          skippedVideos: skippedVideos,
          originalSelected: selected,
        );
      }
    }
  }

  void _showBatchDownloadSummaryDialog({
    required bool isZip,
    required List<PreziVideoItem> successVideos,
    required List<({PreziVideoItem video, String reason})> failedVideos,
    required List<PreziVideoItem> skippedVideos,
    required List<PreziVideoItem> originalSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final totalAttempted = successVideos.length + failedVideos.length;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                failedVideos.isEmpty
                    ? Icons.info_outline_rounded
                    : (successVideos.isEmpty ? Icons.error_outline_rounded : Icons.warning_amber_rounded),
                color: failedVideos.isEmpty
                    ? Colors.lightBlueAccent
                    : (successVideos.isEmpty ? Colors.redAccent : Colors.orangeAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  failedVideos.isEmpty
                      ? 'Resumen de Descargas'
                      : (successVideos.isNotEmpty
                          ? 'Descarga Parcial (${successVideos.length}/$totalAttempted)'
                          : 'No se pudieron descargar los vídeos'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A. Estado de éxito parcial
                  if (successVideos.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isZip
                                  ? '✔ ${successVideos.length} vídeo(s) descargados con éxito e incluidos en el archivo .ZIP (guardados en la caché en memoria).'
                                  : '✔ ${successVideos.length} vídeo(s) descargados con éxito a tu dispositivo (guardados en memoria).',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // B. Videos con fallos
                  if (failedVideos.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${failedVideos.length} vídeo(s) no se pudieron descargar automáticamente en este intento.',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Esto suele deberse a bloqueos de CORS del navegador en GitHub Pages o saturación temporal de la CDN. Los vídeos exitosos siguen en memoria, por lo que reintentar solo procesará los que faltan.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Vídeos que requieren atención:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...failedVideos.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.video.title,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    item.reason,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.blueAccent),
                              tooltip: 'Abrir enlace en pestaña nueva',
                              onPressed: () => _openVideoPreview(item.video.url),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                  ],

                  // C. Videos de YouTube/Vimeo omitidos
                  if (skippedVideos.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${skippedVideos.length} vídeo(s) de YouTube/Vimeo se omitieron porque los servidores de streaming no permiten descargas directas en bruto desde la web.',
                              style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
            if (failedVideos.isNotEmpty) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Abrir enlaces fallidos'),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  for (final item in failedVideos) {
                    await _openVideoPreview(item.video.url);
                    await Future.delayed(const Duration(milliseconds: 500));
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Reintentar fallidos (${failedVideos.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  final retryVideos = failedVideos.map((f) => f.video).toList();
                  if (isZip) {
                    _startBatchDownloadZip(retryVideos);
                  } else {
                    _startBatchDownload(retryVideos);
                  }
                },
              ),
            ],
          ],
        );
      },
    );
  }

  String _buildSafeVideoFilename({
    required int index,
    required PreziVideoItem video,
  }) {
    final numPrefix = (index + 1).toString().padLeft(2, '0');
    final stepStr = video.stepIndex > 0 ? '_Diapositiva_${video.stepIndex}' : '';
    String rawTitle = video.title.trim();
    // Limpiar redundancia si el título ya empieza por "Video" o "Video #"
    rawTitle = rawTitle.replaceAll(RegExp(r'^video\s*#?\d*\s*', caseSensitive: false), '').trim();
    String cleanTitle = rawTitle
        .replaceAll(RegExp(r'[^\w\.-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (cleanTitle.startsWith('_')) cleanTitle = cleanTitle.substring(1);
    if (cleanTitle.endsWith('_')) cleanTitle = cleanTitle.substring(0, cleanTitle.length - 1);

    if (cleanTitle.isEmpty) {
      return 'Video_$numPrefix$stepStr.mp4';
    }
    return 'Video_$numPrefix${stepStr}_$cleanTitle.mp4';
  }

  Future<void> _downloadSingleVideo(PreziVideoItem video) async {
    if (video.isYouTube || video.isVimeo) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(video.isYouTube ? Icons.smart_display_rounded : Icons.live_tv_rounded,
                  color: video.isYouTube ? Colors.redAccent : Colors.lightBlueAccent),
              const SizedBox(width: 10),
              Text('Video de ${video.serviceDisplayName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Este video está incrustado desde ${video.serviceDisplayName}. Los proveedores de streaming externos no permiten descarga directa en bruto en el navegador. ¿Deseas previsualizarlo o abrirlo en ${video.serviceDisplayName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openVideoPreview(video.url);
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('Abrir en ${video.serviceDisplayName}'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _downloadingVideoIds.add(video.id));
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Text('Descargando "${video.title}" a tu equipo...')),
            ],
          ),
          duration: const Duration(seconds: 8),
          backgroundColor: const Color(0xFF1E293B),
        ),
      );
    }

    try {
      final bytes = await _preziService.fetchVideoBytes(video.url);
      if (bytes != null && bytes.isNotEmpty) {
        final videoIdx = _detectedVideos.indexOf(video);
        final safeName = _buildSafeVideoFilename(index: videoIdx >= 0 ? videoIdx : 0, video: video);
        await Printing.sharePdf(bytes: bytes, filename: safeName);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Video guardado en tu equipo: $safeName')),
                ],
              ),
              backgroundColor: AppTheme.emerald,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Descarga directa no disponible, abriendo enlace de video...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        await _openVideoPreview(video.url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar video: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingVideoIds.remove(video.id));
      }
    }
  }

  Future<void> _openVideoPreview(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la previsualización: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SafeArea(
          child: TrayectoriaSidebar(
            isDark: isDark,
            isCollapsed: false,
            activeItem: 'Prezi2Pdf',
            onSelect: (item) {
              Navigator.of(context).maybePop();
              if (item == 'Inicio') {
                widget.onBackToHub();
              } else if (item == 'Orientación') {
                if (widget.onOpenCvBuilder != null) {
                  widget.onOpenCvBuilder!();
                } else {
                  widget.onBackToHub();
                }
              } else if (item == 'PdfSigner' && widget.onOpenPdfSigner != null) {
                widget.onOpenPdfSigner!();
              } else if ((item == 'AdminPanel' || item == 'Ajustes') && widget.onOpenAdminPanel != null) {
                widget.onOpenAdminPanel!();
              }
            },
          ),
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Volver a Sanctuary Hub',
          onPressed: widget.onBackToHub,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SanctuaryPlanetLogo(size: 26, showGlow: true),
            const SizedBox(width: 9),
            const Text(
              'SANCTUARY',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.isCosmicActive ? 'Pausar animación cósmica' : 'Activar animación cósmica',
            icon: Icon(
              widget.isCosmicActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              size: 20,
              color: widget.isCosmicActive ? AppTheme.emerald : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            onPressed: widget.onToggleCosmic,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF475569),
            ),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 4),
          _buildProfileDropdown(isDark, isMobile),
          const SizedBox(width: 14),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 12 : 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HERO BANNER
                _buildHeroBanner(isDark),

                const SizedBox(height: 24),

                // 2. INPUT CARD CON SELECTOR DE PLATAFORMAS
                _buildInputCard(isDark),

                const SizedBox(height: 24),

                // 3. PROGRESS SECTION
                if (_state.isProcessing || _state.hasError || _state.isDone)
                  _buildProgressCard(isDark),

                // 4. PDF RESULT CARD
                if (_state.generatedPdfBytes != null) ...[
                  const SizedBox(height: 24),
                  _buildPdfResultCard(isDark),
                ],

                // 5. VIDEOS EXTRACTION & SELECTION SECTION
                if (_detectedVideos.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildVideosSection(isDark),
                ],

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildProfileDropdown(bool isDark, bool isMobile) {
    final user = widget.apiService.storage.getCurrentUser() ?? const UserModel(username: 'Usuario', role: 'admin');

    return PopupMenuButton<String>(
      tooltip: 'Menú de usuario',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      onSelected: (val) {
        if (val == 'edit_profile') {
          UserProfileDialog.show(
            context,
            user: user,
            apiService: widget.apiService,
            onUserUpdated: (_) => setState(() {}),
          );
        } else if (val == 'admin') {
          widget.onOpenAdminPanel?.call();
        } else if (val == 'hub') {
          widget.onBackToHub();
        } else if (val == 'toggle_theme') {
          widget.onToggleTheme();
        } else if (val == 'toggle_cosmic') {
          widget.onToggleCosmic();
        } else if (val == 'logout') {
          widget.onLogout();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.emerald,
                  backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(user.fullName ?? user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(user.role.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        if (user.role.toLowerCase() == 'admin' && widget.onOpenAdminPanel != null) ...[
          const PopupMenuItem<String>(
            value: 'admin',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, size: 17, color: Color(0xFF06B6D4)),
                SizedBox(width: 10),
                Text(
                  'Panel de Administración',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem<String>(
          value: 'edit_profile',
          child: Row(
            children: [
              Icon(Icons.badge_outlined, size: 17, color: AppTheme.emerald),
              SizedBox(width: 10),
              Text('Editar Perfil', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'hub',
          child: Row(
            children: [
              Icon(Icons.home_outlined, size: 17),
              SizedBox(width: 10),
              Text('Volver al Santuario Hub', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 17, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Cerrar Sesión', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.emerald.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: AppTheme.emerald,
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                  ? Text(
                      user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              Text(
                user.username,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B).withOpacity(0.8), const Color(0xFF0F172A).withOpacity(0.9)]
              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF312E81).withOpacity(0.6) : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFF9333EA), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'SANCTUARY DIGITAL SUITE',
                        style: TextStyle(
                          color: Color(0xFFE11D48),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'SLIDE DOWNLOADER PRO',
                        style: TextStyle(
                          color: AppTheme.emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Slide Downloader · Presentaciones a PDF & Videos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Descarga presentaciones de Prezi, Google Slides, SlideShare, Speaker Deck o documentos PDF en archivos de alta nitidez con extracción opcional de videos.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(bool isDark) {
    final platformColor = _detectedPlatform.brandColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ENLACE DE LA PRESENTACIÓN',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              const Spacer(),
              // Badge de detección automática de plataforma
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: platformColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: platformColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_detectedPlatform.iconData, size: 14, color: platformColor),
                    const SizedBox(width: 6),
                    Text(
                      'Detectado: ${_detectedPlatform.displayName}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: platformColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final urlInput = TextField(
                controller: _urlController,
                enabled: !_state.isProcessing,
                decoration: InputDecoration(
                  hintText: 'Introduce el enlace (Prezi, Google Slides, SlideShare, Speaker Deck o PDF)...',
                  prefixIcon: Icon(_detectedPlatform.iconData, color: platformColor),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_urlController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Limpiar',
                          onPressed: () {
                            setState(() {
                              _urlController.clear();
                              _updateDetectedPlatform('');
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        tooltip: 'Pegar desde el portapapeles',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            final text = data!.text!.trim();
                            setState(() {
                              _urlController.text = text;
                              _updateDetectedPlatform(text);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _startConversion(),
              );

              final actionBtn = SizedBox(
                height: 50,
                width: isNarrow ? double.infinity : null,
                child: ElevatedButton.icon(
                  onPressed: _state.isProcessing ? null : _startConversion,
                  icon: _state.isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_for_offline_rounded, size: 20),
                  label: Text(
                    _state.isProcessing ? 'Procesando...' : 'Descargar Diapositivas',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    elevation: 3,
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    urlInput,
                    const SizedBox(height: 12),
                    actionBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: urlInput),
                  const SizedBox(width: 14),
                  actionBtn,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // CHIPS DE PLATAFORMAS SOPORTADAS CON ENLACES DE EJEMPLO
          Row(
            children: [
              const Text(
                'Plataformas compatibles:',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SlidePlatform.prezi,
                      SlidePlatform.googleSlides,
                      SlidePlatform.slideShare,
                      SlidePlatform.speakerDeck,
                      SlidePlatform.directPdf,
                    ].map((platform) {
                      final isSelected = _detectedPlatform == platform;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Icon(platform.iconData, size: 14, color: platform.brandColor),
                          label: Text(
                            platform.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? platform.brandColor : null,
                            ),
                          ),
                          backgroundColor: isSelected ? platform.brandColor.withOpacity(0.15) : null,
                          side: BorderSide(
                            color: isSelected ? platform.brandColor : Colors.grey.withOpacity(0.2),
                          ),
                          onPressed: () => _applySampleUrl(platform),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Opciones y Switches de optimización
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _filterTransitions,
                    activeColor: AppTheme.emerald,
                    onChanged: _state.isProcessing ? null : (val) => setState(() => _filterTransitions = val),
                  ),
                  const SizedBox(width: 6),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo diapositivas completas (Prezi)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Omite transiciones y zooms intermedios para guardar solo pantallas finales',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _filterDuplicates,
                    activeColor: AppTheme.emerald,
                    onChanged: _state.isProcessing ? null : (val) => setState(() => _filterDuplicates = val),
                  ),
                  const SizedBox(width: 6),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evitar duplicados idénticos',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Descarta capturas consecutivas con bytes exactamente iguales',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark) {
    final state = _state;
    final isDone = state.isDone;
    final hasError = state.hasError;

    Color accentColor = AppTheme.emerald;
    if (hasError) {
      accentColor = Colors.redAccent;
    } else if (state.isProcessing) {
      accentColor = const Color(0xFFE11D48);
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : (isDone ? Icons.check_circle_rounded : Icons.sync_rounded),
                color: accentColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasError
                      ? 'Error en la conversión'
                      : (isDone ? '¡Proceso completado con éxito!' : 'Progreso de descarga y conversión'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: accentColor,
                  ),
                ),
              ),
              Text(
                '${(state.progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: hasError ? 1.0 : state.progress,
              minHeight: 10,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hasError ? (state.errorMessage ?? 'Ocurrió un error inesperado.') : state.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: hasError ? Colors.redAccent : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                  ),
                ),
              ),
              if (state.totalItems > 0 && !hasError)
                Text(
                  'Diapositivas: ${state.currentItem} / ${state.totalItems}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfResultCard(bool isDark) {
    final bytes = _state.generatedPdfBytes!;
    final sizeKb = (bytes.lengthInBytes / 1024).toStringAsFixed(1);
    final sizeMb = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(2);
    final sizeText = bytes.lengthInBytes > 1024 * 1024 ? '$sizeMb MB' : '$sizeKb KB';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        final pdfIcon = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.emerald.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.emerald, size: 32),
        );

        final pdfInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _state.generatedPdfFilename ?? 'Presentacion_Slides.pdf',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Documento PDF generado · Tamaño: $sizeText · Formato apaisado',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );

        final previewBtn = OutlinedButton.icon(
          onPressed: _previewPdf,
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('Visualizar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.emerald,
            side: const BorderSide(color: AppTheme.emerald),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        final downloadBtn = ElevatedButton.icon(
          onPressed: _shareOrDownloadPdf,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Descargar PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        );

        return Container(
          padding: EdgeInsets.all(isNarrow ? 14 : 22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF064E3B).withOpacity(0.25) : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.emerald.withOpacity(0.5)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        pdfIcon,
                        const SizedBox(width: 12),
                        Expanded(child: pdfInfo),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: previewBtn),
                        const SizedBox(width: 10),
                        Expanded(child: downloadBtn),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    pdfIcon,
                    const SizedBox(width: 18),
                    Expanded(child: pdfInfo),
                    const SizedBox(width: 14),
                    previewBtn,
                    const SizedBox(width: 10),
                    downloadBtn,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildVideosSection(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        final videoIcon = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.video_library_rounded, color: Color(0xFF8B5CF6), size: 20),
        );

        final cachedCount = _detectedVideos.where((v) => _preziService.hasCachedVideo(v.url)).length;

        final videoTitleAndCount = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    isNarrow ? 'VIDEOS DETECTADOS' : 'VIDEOS DETECTADOS EN LA PRESENTACIÓN',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_detectedVideos.length}',
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  '$_selectedVideosCount de ${_detectedVideos.length} seleccionados para descarga',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                if (cachedCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.emerald.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 11, color: AppTheme.emerald),
                        const SizedBox(width: 2),
                        Text(
                          '$cachedCount en caché',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        );

        final selectAllBtn = InkWell(
          onTap: () => _toggleSelectAllVideos(!_isAllVideosSelected),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isAllVideosSelected
                  ? AppTheme.emerald.withOpacity(0.15)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isAllVideosSelected ? AppTheme.emerald : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: isNarrow ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Checkbox(
                  value: _isAllVideosSelected,
                  activeColor: AppTheme.emerald,
                  onChanged: _toggleSelectAllVideos,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Text(
                  _isAllVideosSelected ? 'Desmarcar todos' : 'Marcar todos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isAllVideosSelected ? AppTheme.emerald : null,
                  ),
                ),
              ],
            ),
          ),
        );

        final downloadVideosBtn = ElevatedButton.icon(
          onPressed: (_selectedVideosCount > 0 && !_isBatchDownloading) ? _downloadSelectedVideos : null,
          icon: _isBatchDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(
            _isBatchDownloading ? 'Descargando...' : 'Descargar ($_selectedVideosCount)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        );

        return Container(
          padding: EdgeInsets.all(isNarrow ? 14 : 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        videoIcon,
                        const SizedBox(width: 10),
                        Expanded(child: videoTitleAndCount),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: selectAllBtn),
                        const SizedBox(width: 10),
                        Expanded(child: downloadVideosBtn),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    videoIcon,
                    const SizedBox(width: 12),
                    Expanded(child: videoTitleAndCount),
                    selectAllBtn,
                    const SizedBox(width: 14),
                    downloadVideosBtn,
                  ],
                ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 250,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _detectedVideos.length,
                itemBuilder: (context, idx) {
                  final video = _detectedVideos[idx];
                  return _buildVideoCard(video, isDark);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoCard(PreziVideoItem video, bool isDark) {
    final isCached = _preziService.hasCachedVideo(video.url);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: video.isSelected
              ? AppTheme.emerald
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: video.isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (video.isSelected)
            BoxShadow(
              color: AppTheme.emerald.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 125,
                  width: double.infinity,
                  child: video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderThumbnail(),
                        )
                      : _buildPlaceholderThumbnail(),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openVideoPreview(video.url),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Checkbox(
                    value: video.isSelected,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) => _toggleSingleVideo(video, val),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        video.isYouTube
                            ? Icons.smart_display_rounded
                            : (video.isVimeo ? Icons.live_tv_rounded : Icons.movie_creation_rounded),
                        size: 13,
                        color: video.isYouTube ? Colors.redAccent : AppTheme.emerald,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        video.serviceDisplayName,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              if (isCached)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'En caché',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Paso #${video.stepIndex}',
                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        video.url,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('Previsualizar', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _openVideoPreview(video.url),
                      ),
                      _downloadingVideoIds.contains(video.id)
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald),
                              ),
                            )
                          : ElevatedButton.icon(
                              icon: Icon(
                                isCached ? Icons.check_circle_outline_rounded : Icons.download_rounded,
                                size: 14,
                              ),
                              label: Text(
                                isCached ? 'Guardar' : 'Descargar',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCached ? const Color(0xFF059669) : AppTheme.emerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () => _downloadSingleVideo(video),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_filter_rounded, color: Colors.white38, size: 36),
      ),
    );
  }
}
