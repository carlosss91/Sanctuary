import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/trayectoria_sidebar.dart';
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
  bool _isSidebarCollapsed = true;
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
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: selected.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (context, idx) {
                      final vid = selected[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppTheme.emerald.withOpacity(0.15),
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                          ),
                        ),
                        title: Text(
                          vid.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                              icon: const Icon(Icons.download_rounded, size: 18, color: AppTheme.emerald),
                              tooltip: 'Descargar archivo a disco',
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
    int addedCount = 0;
    int skippedCount = 0;

    for (int i = 0; i < selected.length; i++) {
      final video = selected[i];
      if (video.isYouTube || video.isVimeo) {
        skippedCount++;
        continue;
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
                Expanded(child: Text('Descargando vídeo ${i + 1} de ${selected.length}: "${video.title}"...')),
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
          addedCount++;
        }
      } catch (e) {
        debugPrint('Error en descarga de vídeo (${video.title}): $e');
      } finally {
        if (mounted) {
          setState(() => _downloadingVideoIds.remove(video.id));
        }
      }
    }

    if (addedCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Expanded(child: Text('Empaquetando todos los vídeos en archivo .ZIP...')),
              ],
            ),
            duration: Duration(seconds: 15),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  skippedCount > 0
                      ? '✔ ¡$addedCount vídeos empaquetados y guardados en $zipName! ($skippedCount de YouTube/Vimeo omitidos)'
                      : '✔ ¡Todos los vídeos ($addedCount) se han guardado con éxito en el archivo $zipName!',
                ),
                backgroundColor: AppTheme.emerald,
                duration: const Duration(seconds: 6),
              ),
            );
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
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron obtener los archivos de vídeo para empaquetar.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isBatchDownloading = false);
    }
  }

  Future<void> _startBatchDownload(List<PreziVideoItem> selected) async {
    setState(() => _isBatchDownloading = true);

    int downloadedCount = 0;
    int skippedCount = 0;

    for (int i = 0; i < selected.length; i++) {
      final video = selected[i];
      if (video.isYouTube || video.isVimeo) {
        skippedCount++;
        continue;
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
                Expanded(child: Text('Descargando vídeo individual ${i + 1} de ${selected.length}: ${video.title}...')),
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
          downloadedCount++;
        }
      } catch (e) {
        debugPrint('Error en descarga de lote (${video.title}): $e');
      } finally {
        if (mounted) {
          setState(() => _downloadingVideoIds.remove(video.id));
        }
      }

      // Pausa secuencial controlada de 1.8s para que el navegador procese cada descarga sin bloquear la siguiente
      await Future.delayed(const Duration(milliseconds: 1800));
    }

    if (mounted) {
      setState(() => _isBatchDownloading = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skippedCount > 0
                ? '✔ $downloadedCount vídeos guardados ($skippedCount de YouTube/Vimeo omitidos).'
                : '✔ ¡Se han procesado las descargas de todos los vídeos ($downloadedCount)!',
          ),
          backgroundColor: AppTheme.emerald,
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
      drawer: isMobile
          ? Drawer(
              backgroundColor: isDark ? const Color(0xFF0D121D) : Colors.white,
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
                  onToggleCollapse: () => Navigator.of(context).maybePop(),
                ),
              ),
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Collapsible Sanctuary Sidebar (Desktop / Tablet only)
          if (!isMobile)
            TrayectoriaSidebar(
              isDark: isDark,
              isCollapsed: _isSidebarCollapsed,
              activeItem: 'Prezi2Pdf',
              onSelect: (item) {
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
              onToggleCollapse: () {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
              },
            ),

          // 2. Main Workspace
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isDark, isMobile),
                Expanded(
                  child: SingleChildScrollView(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark, bool isMobile) {
    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D121D).withOpacity(0.85) : Colors.white.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // On Mobile: Sidebar Menu Button
          if (isMobile) ...[
            Tooltip(
              message: 'Abrir barra lateral',
              child: InkWell(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_rounded,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Back Button to Hub (Solo flecha compacta, sin texto)
          Tooltip(
            message: 'Volver al Santuario Hub',
            child: InkWell(
              onTap: widget.onBackToHub,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // App Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.present_to_all_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Slide Downloader',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Spacer(),

          // Cosmic Animation Toggle (Hide on mobile to keep top bar clean)
          if (!isMobile) ...[
            Tooltip(
              message: widget.isCosmicActive ? 'Pausar animación cósmica' : 'Activar animación cósmica',
              child: InkWell(
                onTap: widget.onToggleCosmic,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.isCosmicActive
                        ? (isDark ? const Color(0xFF10B981).withOpacity(0.18) : const Color(0xFF10B981).withOpacity(0.12))
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.isCosmicActive ? const Color(0xFF10B981).withOpacity(0.55) : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.isCosmicActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                      size: 18,
                      color: widget.isCosmicActive ? AppTheme.emerald : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],

          // Theme Toggle (Consistent 36x36 style)
          Tooltip(
            message: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
            child: InkWell(
              onTap: widget.onToggleTheme,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
                ),
                child: Center(
                  child: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 18,
                    color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Profile Dropdown (compact on mobile)
          _buildProfileDropdown(isDark, isMobile),
        ],
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

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withOpacity(0.25) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.emerald.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.emerald, size: 36),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _state.generatedPdfFilename ?? 'Presentacion_Slides.pdf',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Documento PDF generado · Tamaño: $sizeText · Páginas nítidas en formato apaisado',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            onPressed: _previewPdf,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Visualizar / Imprimir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.emerald,
              side: const BorderSide(color: AppTheme.emerald),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _shareOrDownloadPdf,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Descargar PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.video_library_rounded, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'VIDEOS DETECTADOS EN LA PRESENTACIÓN',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
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
                    const SizedBox(height: 2),
                    Text(
                      '$_selectedVideosCount de ${_detectedVideos.length} seleccionados para descarga',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // TICK MASTER: SELECCIONAR / MARCAR TODOS
              InkWell(
                onTap: () => _toggleSelectAllVideos(!_isAllVideosSelected),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    mainAxisSize: MainAxisSize.min,
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _isAllVideosSelected ? AppTheme.emerald : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              ElevatedButton.icon(
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
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
  }

  Widget _buildVideoCard(PreziVideoItem video, bool isDark) {
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
                              icon: const Icon(Icons.download_rounded, size: 14),
                              label: const Text('Descargar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emerald,
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
