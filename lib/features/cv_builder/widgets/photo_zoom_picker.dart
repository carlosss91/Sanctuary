import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/cv_profile_model.dart';
import '../../../data/services/api_service.dart';
import 'image_crop_dialog.dart';

class PhotoZoomPicker extends StatefulWidget {
  final CvProfileModel profile;
  final ValueChanged<CvProfileModel> onProfileChanged;
  final ApiService? apiService;

  const PhotoZoomPicker({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    this.apiService,
  });

  @override
  State<PhotoZoomPicker> createState() => _PhotoZoomPickerState();
}

class _PhotoZoomPickerState extends State<PhotoZoomPicker> {
  bool _showAdjustmentControls = false;
  bool _isUploading = false;

  final List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400&auto=format&fit=crop&q=80',
  ];

  Future<void> _pickAndCropImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isNotEmpty) {
        final pickedFile = files.first;
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isEmpty) return;

        if (!mounted) return;
        final cropResult = await ImageCropDialog.show(
          context,
          imageBytes: bytes,
          initialShape: widget.profile.photoShape,
          initialZoom: 1.0,
          initialPanX: 0.0,
          initialPanY: 0.0,
        );

        if (cropResult != null) {
          setState(() => _isUploading = true);

          String? finalUrl;
          if (widget.apiService != null) {
            finalUrl = await widget.apiService!.uploadImage(cropResult.effectiveBytes, pickedFile.name);
          }
          finalUrl ??= 'data:image/png;base64,${base64Encode(cropResult.effectiveBytes)}';

          if (mounted) {
            setState(() => _isUploading = false);
            widget.onProfileChanged(
              widget.profile.copyWith(
                photoUrl: finalUrl,
                photoShape: cropResult.shape,
                photoZoom: 1.0,
                photoPanX: 0.0,
                photoPanY: 0.0,
              ),
            );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Fotografía encuadrada y guardada con éxito!'),
                backgroundColor: AppTheme.emerald,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _recropCurrentImage() async {
    final photoUrl = widget.profile.photoUrl;
    if (photoUrl.isEmpty) return;

    Uint8List? bytes;
    try {
      if (photoUrl.startsWith('data:image')) {
        final commaIdx = photoUrl.indexOf(',');
        final base64Data = commaIdx >= 0 ? photoUrl.substring(commaIdx + 1) : photoUrl;
        bytes = base64Decode(base64Data);
      } else if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        }
      }
    } catch (_) {}

    if (bytes == null || bytes.isEmpty) {
      setState(() => _showAdjustmentControls = !_showAdjustmentControls);
      return;
    }

    if (!mounted) return;
    final cropResult = await ImageCropDialog.show(
      context,
      imageBytes: bytes,
      initialShape: widget.profile.photoShape,
      initialZoom: widget.profile.photoZoom,
      initialPanX: widget.profile.photoPanX,
      initialPanY: widget.profile.photoPanY,
    );

    if (cropResult != null && mounted) {
      final base64String = 'data:image/png;base64,${base64Encode(cropResult.effectiveBytes)}';
      widget.onProfileChanged(
        widget.profile.copyWith(
          photoUrl: base64String,
          photoShape: cropResult.shape,
          photoZoom: 1.0,
          photoPanX: 0.0,
          photoPanY: 0.0,
        ),
      );
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Elegir Fotografía de Ficha Muestra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _sampleAvatars.map((url) {
                  return GestureDetector(
                    onTap: () {
                      widget.onProfileChanged(widget.profile.copyWith(photoUrl: url));
                      Navigator.pop(context);
                    },
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(url),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showUrlInputDialog() {
    final controller = TextEditingController(text: widget.profile.photoUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enlace Web de Imagen'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Introduce URL de la imagen (https://...)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onProfileChanged(widget.profile.copyWith(photoUrl: controller.text.trim()));
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhotoContent(String photoUrl) {
    if (photoUrl.isEmpty) {
      return Center(
        child: Text(
          widget.profile.fullName.isNotEmpty
              ? widget.profile.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
              : 'FOTO',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.emerald),
        ),
      );
    }

    Widget imgWidget;
    if (photoUrl.startsWith('data:image')) {
      try {
        final commaIdx = photoUrl.indexOf(',');
        final base64Data = commaIdx >= 0 ? photoUrl.substring(commaIdx + 1) : photoUrl;
        final bytes = base64Decode(base64Data);
        imgWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, size: 48, color: Colors.grey)),
        );
      } catch (_) {
        imgWidget = const Center(child: Icon(Icons.person, size: 48, color: Colors.grey));
      }
    } else {
      imgWidget = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, size: 48, color: Colors.grey)),
      );
    }

    const double avatarSize = 104.0;
    return Transform.translate(
      offset: Offset(widget.profile.photoPanX * avatarSize, widget.profile.photoPanY * avatarSize),
      child: Transform.scale(
        scale: widget.profile.photoZoom,
        child: SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: imgWidget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoUrl = widget.profile.photoUrl;
    final isCircle = widget.profile.photoShape != 'square';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInput.withOpacity(0.6) : AppTheme.lightInput,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo View with Round / Square Frame & Zoom & Pan
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: !isCircle ? BorderRadius.circular(16) : null,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  border: Border.all(color: AppTheme.emerald, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emerald.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _isUploading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
                    : _buildPhotoContent(photoUrl),
              ),

              const SizedBox(width: 18),

              // Title, Shape selector and Actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isCircle ? 'Encuadre Circular' : 'Encuadre Cuadrado',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCircle ? 'Circular' : 'Cuadrado',
                            style: const TextStyle(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sube una imagen desde tu PC con recorte automático (redondo o cuadrado), o ajusta el zoom y centrado.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Shape Toggle Buttons (Redondo vs Cuadrado)
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            widget.onProfileChanged(widget.profile.copyWith(photoShape: 'circle'));
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCircle ? AppTheme.emerald.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isCircle ? AppTheme.emerald : Colors.grey.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle_outlined, size: 14, color: isCircle ? AppTheme.emerald : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Redondo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isCircle ? FontWeight.bold : FontWeight.normal,
                                    color: isCircle ? AppTheme.emerald : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            widget.onProfileChanged(widget.profile.copyWith(photoShape: 'square'));
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: !isCircle ? AppTheme.emerald.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: !isCircle ? AppTheme.emerald : Colors.grey.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.crop_square, size: 14, color: !isCircle ? AppTheme.emerald : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Cuadrado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: !isCircle ? FontWeight.bold : FontWeight.normal,
                                    color: !isCircle ? AppTheme.emerald : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Action buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickAndCropImage,
                          icon: const Icon(Icons.upload_file, size: 15),
                          label: const Text('Subir Foto del PC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        if (photoUrl.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: _recropCurrentImage,
                            icon: const Icon(Icons.crop, size: 14, color: AppTheme.emerald),
                            label: const Text('Re-encuadrar', style: TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: const BorderSide(color: AppTheme.emerald),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _showAdjustmentControls = !_showAdjustmentControls),
                          icon: const Icon(Icons.tune, size: 14),
                          label: const Text('Ajuste fino', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showAvatarPicker,
                          icon: const Icon(Icons.account_box_outlined, size: 14),
                          label: const Text('Foto muestra', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showUrlInputDialog,
                          icon: const Icon(Icons.link, size: 14),
                          label: const Text('URL web', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                        if (photoUrl.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              widget.onProfileChanged(widget.profile.copyWith(photoUrl: ''));
                            },
                            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                            label: const Text('Quitar', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Collapsible Zoom & Pan sliders
          if (_showAdjustmentControls) ...[
            const SizedBox(height: 14),
            const Divider(),
            Row(
              children: [
                const SizedBox(width: 80, child: Text('Zoom:', style: TextStyle(fontSize: 12))),
                Expanded(
                  child: Slider(
                    value: widget.profile.photoZoom.clamp(0.5, 3.5),
                    min: 0.5,
                    max: 3.5,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) {
                      widget.onProfileChanged(widget.profile.copyWith(photoZoom: val));
                    },
                  ),
                ),
                Text('${(widget.profile.photoZoom * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 80, child: Text('Posición X:', style: TextStyle(fontSize: 12))),
                Expanded(
                  child: Slider(
                    value: widget.profile.photoPanX.clamp(-2.0, 2.0),
                    min: -2.0,
                    max: 2.0,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) {
                      widget.onProfileChanged(widget.profile.copyWith(photoPanX: val));
                    },
                  ),
                ),
                Text(widget.profile.photoPanX.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 80, child: Text('Posición Y:', style: TextStyle(fontSize: 12))),
                Expanded(
                  child: Slider(
                    value: widget.profile.photoPanY.clamp(-2.0, 2.0),
                    min: -2.0,
                    max: 2.0,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) {
                      widget.onProfileChanged(widget.profile.copyWith(photoPanY: val));
                    },
                  ),
                ),
                Text(widget.profile.photoPanY.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
