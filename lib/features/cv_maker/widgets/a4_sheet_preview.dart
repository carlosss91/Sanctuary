import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/cv_profile_model.dart';
export 'watermark_painter.dart';
import 'watermark_painter.dart';

class A4SheetPreview extends StatefulWidget {
  final CvProfileModel profile;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportWord;
  final VoidCallback? onToggleLanguage;

  const A4SheetPreview({
    super.key,
    required this.profile,
    this.onExportPdf,
    this.onExportWord,
    this.onToggleLanguage,
  });

  @override
  State<A4SheetPreview> createState() => _A4SheetPreviewState();
}

class _A4SheetPreviewState extends State<A4SheetPreview> {
  double? _customScale;
  double _lastAutoFitScale = 0.85;
  late TextEditingController _zoomTextCtrl;
  late FocusNode _zoomFocusNode;

  @override
  void initState() {
    super.initState();
    _zoomTextCtrl = TextEditingController(text: '85%');
    _zoomFocusNode = FocusNode();
    _zoomFocusNode.addListener(() {
      if (!_zoomFocusNode.hasFocus) {
        _applyZoomFromText();
      }
    });
  }

  @override
  void dispose() {
    _zoomTextCtrl.dispose();
    _zoomFocusNode.dispose();
    super.dispose();
  }

  void _syncZoomText(double scale) {
    if (!_zoomFocusNode.hasFocus) {
      final formatted = '${(scale * 100).round()}%';
      if (_zoomTextCtrl.text != formatted) {
        _zoomTextCtrl.text = formatted;
      }
    }
  }

  void _applyZoomFromText() {
    final raw = _zoomTextCtrl.text.replaceAll('%', '').replaceAll(',', '.').trim();
    final parsed = double.tryParse(raw);
    if (parsed != null && parsed > 0) {
      final clampedScale = (parsed / 100.0).clamp(0.3, 2.0);
      setState(() => _customScale = clampedScale);
      _zoomTextCtrl.text = '${(clampedScale * 100).round()}%';
    } else {
      final current = _customScale ?? _lastAutoFitScale;
      _zoomTextCtrl.text = '${(current * 100).round()}%';
    }
  }

  void _zoomIn() {
    final current = _customScale ?? _lastAutoFitScale;
    final next = (current + 0.08).clamp(0.3, 1.8);
    setState(() => _customScale = next);
    _zoomTextCtrl.text = '${(next * 100).round()}%';
  }

  void _zoomOut() {
    final current = _customScale ?? _lastAutoFitScale;
    final next = (current - 0.08).clamp(0.3, 1.8);
    setState(() => _customScale = next);
    _zoomTextCtrl.text = '${(next * 100).round()}%';
  }

  void _resetZoom() {
    setState(() => _customScale = 1.0);
    _zoomTextCtrl.text = '100%';
  }

  void _autoFit() {
    setState(() => _customScale = null);
  }

  Color _parseAccent(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF0D9488);
  }

  Widget _buildPhotoWidget({required double size, bool isWhiteBorder = true}) {
    final photoUrl = widget.profile.photoUrl;
    final isSquare = widget.profile.photoShape == 'square';
    final borderRadius = isSquare ? BorderRadius.circular(size * 0.16) : BorderRadius.circular(size * 0.5);

    Widget imageContent;
    if (photoUrl.isEmpty) {
      imageContent = Center(
        child: Text(
          widget.profile.fullName.isNotEmpty
              ? widget.profile.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
              : 'CV',
          style: TextStyle(
            color: isWhiteBorder ? Colors.white : AppTheme.emerald,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (photoUrl.startsWith('data:image')) {
      try {
        final commaIdx = photoUrl.indexOf(',');
        final base64Data = commaIdx >= 0 ? photoUrl.substring(commaIdx + 1) : photoUrl;
        final bytes = base64Decode(base64Data);
        imageContent = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: Icon(Icons.person, size: size * 0.5, color: Colors.white70)),
        );
      } catch (_) {
        imageContent = Center(child: Icon(Icons.person, size: size * 0.5, color: Colors.white70));
      }
    } else {
      imageContent = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(child: Icon(Icons.person, size: size * 0.5, color: Colors.white70)),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isSquare ? borderRadius : null,
        color: isWhiteBorder ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
        border: Border.all(color: isWhiteBorder ? Colors.white : _parseAccent(widget.profile.accentColor), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Transform.translate(
          offset: Offset(widget.profile.photoPanX * size, widget.profile.photoPanY * size),
          child: Transform.scale(
            scale: widget.profile.photoZoom,
            child: SizedBox(
              width: size,
              height: size,
              child: imageContent,
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _getTextStyle({
    double fontSize = 9.0,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    final scaledSize = fontSize * widget.profile.fontSizeScale;
    final effectiveSpacing = (letterSpacing ?? 0.0) + widget.profile.fontSpacing;
    final effectiveHeight = height ?? widget.profile.lineSpacing;
    final family = widget.profile.fontFamily.trim().isNotEmpty ? widget.profile.fontFamily : 'Inter';

    try {
      return GoogleFonts.getFont(
        family,
        fontSize: scaledSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: effectiveSpacing,
        height: effectiveHeight,
        fontStyle: fontStyle,
        decoration: decoration,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: family,
        fontSize: scaledSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: effectiveSpacing,
        height: effectiveHeight,
        fontStyle: fontStyle,
        decoration: decoration,
      );
    }
  }

  Widget _buildWatermarkOverlay({double? opacity, double? density, double? randomness}) {
    if (!widget.profile.showWatermark ||
        widget.profile.watermarkPattern == 'none') {
      return const SizedBox.shrink();
    }

    final effectiveOpacity = (opacity ?? widget.profile.watermarkOpacity).clamp(0.0, 1.0);
    if (effectiveOpacity <= 0.0) return const SizedBox.shrink();
    final effectiveDensity = (density ?? widget.profile.watermarkDensity).clamp(0.4, 3.0);
    final effectiveRandomness = (randomness ?? widget.profile.watermarkRandomness).clamp(0.0, 1.0);

    if (widget.profile.watermarkPattern == 'custom' && widget.profile.customWatermarkUrl.isNotEmpty) {
      final img = widget.profile.customWatermarkUrl;
      final Widget imgWidget;
      if (img.startsWith('data:image')) {
        final commaIdx = img.indexOf(',');
        final b64 = commaIdx != -1 ? img.substring(commaIdx + 1) : img;
        imgWidget = Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          color: Colors.white.withOpacity(0.7),
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } else {
        imgWidget = Image.network(
          img,
          fit: BoxFit.cover,
          color: Colors.white.withOpacity(0.7),
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return Opacity(
        opacity: effectiveOpacity,
        child: imgWidget,
      );
    }

    return CustomPaint(
      painter: WatermarkPainter(
        pattern: widget.profile.watermarkPattern,
        opacity: effectiveOpacity,
        density: effectiveDensity,
        randomness: effectiveRandomness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _parseAccent(widget.profile.accentColor);
    final isEn = widget.profile.isEnglishVersion;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withOpacity(0.55) : Colors.white.withOpacity(0.68),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.70),
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              // Top Toolbar with quick export, lang and zoom
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06))),
                ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined, color: AppTheme.emerald, size: 18),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hoja A4 Oficial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      '210 × 297 mm · ${_getTemplateName(widget.profile.template)}',
                      style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),

                const Spacer(),

                InkWell(
                  onTap: _autoFit,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Ajustar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),

                InkWell(
                  onTap: _resetZoom,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('1:1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 13),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: _zoomOut,
                      ),
                      SizedBox(
                        width: 44,
                        child: TextField(
                          controller: _zoomTextCtrl,
                          focusNode: _zoomFocusNode,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 2),
                          ),
                          onSubmitted: (_) {
                            _applyZoomFromText();
                            _zoomFocusNode.unfocus();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 13),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: _zoomIn,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Sheet Canvas (Proportional A4 Layout, Auto-fits width gracefully)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth - 32;
                final autoScale = (availableWidth / 595).clamp(0.40, 1.25);
                _lastAutoFitScale = autoScale;
                final effectiveScale = _customScale ?? autoScale;
                _syncZoomText(effectiveScale);

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 84),
                  child: Center(
                    child: SizedBox(
                      width: 595 * effectiveScale,
                      height: 842 * effectiveScale,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 595,
                          height: 842,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: DefaultTextStyle.merge(
                            style: _getTextStyle(fontSize: 8.8, color: const Color(0xFF1E293B)),
                            child: _buildTemplateLayout(accentColor, isEn),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  String _getTemplateName(String tpl) {
    switch (tpl) {
      case 'modern_header':
        return 'Cabecera Moderna';
      case 'minimalist':
        return 'Minimalista Clásico';
      case 'tech_cards':
        return 'Tarjetas Modulares';
      case 'sidebar_dark':
      default:
        return 'Columna Lateral';
    }
  }

  Widget _buildTemplateLayout(Color accentColor, bool isEn) {
    switch (widget.profile.template) {
      case 'modern_header':
        return _buildModernHeaderLayout(accentColor, isEn);
      case 'minimalist':
        return _buildMinimalistLayout(accentColor, isEn);
      case 'tech_cards':
        return _buildTechCardsLayout(accentColor, isEn);
      case 'sidebar_dark':
      default:
        return _buildSidebarDarkLayout(accentColor, isEn);
    }
  }

  // ==============================================================================
  // 1. TEMPLATE: SIDEBAR DARK / COLUMNA LATERAL EJECUTIVA
  // ==============================================================================
  Widget _buildSidebarDarkLayout(Color accentColor, bool isEn) {
    final skillsList = _getSkillsList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column (Colored with Watermark)
        Container(
          width: 185,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Positioned.fill(child: _buildWatermarkOverlay()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildPhotoWidget(size: 86, isWhiteBorder: true),
                      const SizedBox(height: 14),

                      _buildPillOnColor(isEn ? 'CONTACT DETAILS' : 'DATOS'),
                      const SizedBox(height: 10),

                      _buildContactRowWhite(Icons.phone, widget.profile.phone),
                      _buildContactRowWhite(Icons.email, widget.profile.email),
                      _buildContactRowWhite(Icons.location_on, widget.profile.location),
                      _buildContactRowWhite(Icons.access_time, widget.profile.availability),
                      _buildContactRowWhite(Icons.directions_car, widget.profile.drivingLicense),

                      if (widget.profile.summary.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildPillOnColor(isEn ? 'ABOUT ME' : 'SOBRE MÍ'),
                        const SizedBox(height: 8),
                        Text(
                          widget.profile.summary,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 8.0,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ],

                      if (skillsList.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildPillOnColor(isEn ? 'KEY SKILLS' : 'COMPETENCIAS'),
                        const SizedBox(height: 10),
                        ...skillsList.map((item) => _buildCompetencyRow(item)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Right Column (Main content)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner with Name & Job Title
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: _buildWatermarkOverlay(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.profile.fullName.isNotEmpty
                                  ? widget.profile.fullName.toUpperCase()
                                  : 'NOMBRE Y APELLIDOS',
                              textAlign: TextAlign.center,
                              style: _getTextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (widget.profile.jobTitle.isNotEmpty) ...[
                              const SizedBox(height: 2.5),
                              Text(
                                widget.profile.jobTitle.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: _getTextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.95),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _buildSectionPill(isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL', accentColor),
              const SizedBox(height: 8),
              if (widget.profile.experiences.isEmpty)
                Text(
                  isEn ? 'No experience registered.' : 'Sin experiencia registrada.',
                  style: const TextStyle(fontSize: 8.5, color: Colors.grey),
                )
              else
                ...widget.profile.experiences.map((exp) => _buildExperienceItemWithIcon(exp, accentColor)),

              const SizedBox(height: 12),

              _buildSectionPill(isEn ? 'EDUCATION & CERTIFICATIONS' : 'FORMACIÓN Y CERTIFICACIONES', accentColor),
              const SizedBox(height: 8),
              if (widget.profile.educations.isEmpty)
                Text(
                  isEn ? 'No education registered.' : 'Sin formación registrada.',
                  style: const TextStyle(fontSize: 8.5, color: Colors.grey),
                )
              else
                ...widget.profile.educations.asMap().entries.map(
                      (entry) => _buildEducationItemWithIcon(entry.value, accentColor, entry.key),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================================
  // 2. TEMPLATE: MODERN HEADER / CABECERA MODERNA & 2 COLUMNAS
  // ==============================================================================
  Widget _buildModernHeaderLayout(Color accentColor, bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Full Width Top Banner with Watermark
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Positioned.fill(child: _buildWatermarkOverlay()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildPhotoWidget(size: 80, isWhiteBorder: true),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.profile.fullName.isNotEmpty ? widget.profile.fullName : 'NOMBRE Y APELLIDOS',
                              style: TextStyle(
                                fontFamily: widget.profile.fontFamily,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.profile.jobTitle.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Horizontal contact pills
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (widget.profile.phone.isNotEmpty) _buildHeaderContactChip(Icons.phone, widget.profile.phone),
                                if (widget.profile.email.isNotEmpty) _buildHeaderContactChip(Icons.email, widget.profile.email),
                                if (widget.profile.location.isNotEmpty) _buildHeaderContactChip(Icons.location_on, widget.profile.location),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Split in 2 Balanced Columns below
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (About me + Experience)
              Expanded(
                flex: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(isEn ? 'PROFESSIONAL PROFILE' : 'PERFIL PROFESIONAL', accentColor),
                    const SizedBox(height: 6),
                    Text(
                      widget.profile.summary,
                      style: const TextStyle(fontSize: 8.5, color: Color(0xFF334155), height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionTitle(isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL', accentColor),
                    const SizedBox(height: 8),
                    ...widget.profile.experiences.map((exp) => _buildExperienceItem(exp, accentColor)),
                  ],
                ),
              ),

              const SizedBox(width: 16),
              Container(width: 1, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 16),

              // Right Column (Education + Skills + Requirements)
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(isEn ? 'KEY SKILLS' : 'COMPETENCIAS CLAVE', accentColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: _getSkillsList().map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: accentColor.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(fontSize: 7.8, fontWeight: FontWeight.bold, color: accentColor),
                              ),
                              const SizedBox(width: 4),
                              _buildRatingDots(
                                item.level,
                                activeColor: const Color(0xFFF59E0B),
                                inactiveColor: const Color(0xFFCBD5E1),
                                dotSize: 3.8,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    _buildSectionTitle(isEn ? 'EDUCATION' : 'FORMACIÓN ACADÉMICA', accentColor),
                    const SizedBox(height: 8),
                    ...widget.profile.educations.map((edu) => _buildEducationItem(edu, accentColor)),

                    const SizedBox(height: 14),
                    _buildSectionTitle(isEn ? 'ADDITIONAL INFO' : 'DATOS DE INTERÉS', accentColor),
                    const SizedBox(height: 6),
                    if (widget.profile.availability.isNotEmpty)
                      _buildSimpleInfoRow(Icons.access_time, isEn ? 'Availability' : 'Disponibilidad', widget.profile.availability),
                    if (widget.profile.drivingLicense.isNotEmpty)
                      _buildSimpleInfoRow(Icons.directions_car, isEn ? 'License' : 'Permiso', widget.profile.drivingLicense),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================================
  // 3. TEMPLATE: MINIMALIST / MINIMALISTA CLÁSICO CENTRADO
  // ==============================================================================
  Widget _buildMinimalistLayout(Color accentColor, bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Centered Header
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPhotoWidget(size: 70, isWhiteBorder: false),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.profile.fullName.isNotEmpty ? widget.profile.fullName : 'NOMBRE Y APELLIDOS',
                  style: TextStyle(
                    fontFamily: widget.profile.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.profile.jobTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Centered Contact Line
        Text(
          [
            if (widget.profile.phone.isNotEmpty) widget.profile.phone,
            if (widget.profile.email.isNotEmpty) widget.profile.email,
            if (widget.profile.location.isNotEmpty) widget.profile.location,
            if (widget.profile.drivingLicense.isNotEmpty) widget.profile.drivingLicense,
          ].join('   •   '),
          style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 12),
        Container(height: 1.5, color: accentColor),
        const SizedBox(height: 14),

        // Sequential Sections
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSectionTitle(isEn ? 'PROFILE' : 'PERFIL PROFESIONAL', accentColor),
              const SizedBox(height: 6),
              Text(
                widget.profile.summary,
                style: const TextStyle(fontSize: 8.5, color: Color(0xFF334155), height: 1.45),
                textAlign: TextAlign.justify,
              ),

              const SizedBox(height: 14),
              _buildSectionTitle(isEn ? 'EXPERIENCE' : 'EXPERIENCIA LABORAL', accentColor),
              const SizedBox(height: 8),
              ...widget.profile.experiences.map((exp) => _buildExperienceItem(exp, accentColor)),

              const SizedBox(height: 14),
              _buildSectionTitle(isEn ? 'EDUCATION' : 'FORMACIÓN ACADÉMICA', accentColor),
              const SizedBox(height: 8),
              ...widget.profile.educations.map((edu) => _buildEducationItem(edu, accentColor)),

              const SizedBox(height: 14),
              _buildSectionTitle(isEn ? 'SKILLS' : 'HABILIDADES Y COMPETENCIAS', accentColor),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: _getSkillsList().map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 4),
                        _buildRatingDots(
                          item.level,
                          activeColor: const Color(0xFFF59E0B),
                          inactiveColor: const Color(0xFFCBD5E1),
                          dotSize: 3.8,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================================
  // 4. TEMPLATE: TECH CARDS / TARJETAS MODULARES CONTEMPORÁNEO
  // ==============================================================================
  Widget _buildTechCardsLayout(Color accentColor, bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Top Hero Card with Subtle Accent
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              _buildPhotoWidget(size: 68, isWhiteBorder: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.fullName.isNotEmpty ? widget.profile.fullName : 'NOMBRE Y APELLIDOS',
                      style: TextStyle(
                        fontFamily: widget.profile.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      widget.profile.jobTitle.toUpperCase(),
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: accentColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.profile.phone}  |  ${widget.profile.email}  |  ${widget.profile.location}',
                      style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Grid of modular cards
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card: About me
                    _buildCardBlock(
                      title: isEn ? 'ABOUT ME' : 'SOBRE MÍ',
                      accentColor: accentColor,
                      child: Text(widget.profile.summary, style: const TextStyle(fontSize: 8.2, height: 1.4)),
                    ),
                    const SizedBox(height: 10),
                    // Card: Experience
                    Expanded(
                      child: _buildCardBlock(
                        title: isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA',
                        accentColor: accentColor,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: widget.profile.experiences.map((e) => _buildExperienceItem(e, accentColor)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Right Column
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card: Skills
                    _buildCardBlock(
                      title: isEn ? 'COMPETENCIES' : 'COMPETENCIAS',
                      accentColor: accentColor,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _getSkillsList().map((item) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item.name, style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: accentColor)),
                                const SizedBox(width: 4),
                                _buildRatingDots(
                                  item.level,
                                  activeColor: const Color(0xFFF59E0B),
                                  inactiveColor: accentColor.withOpacity(0.2),
                                  dotSize: 3.6,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Card: Education
                    Expanded(
                      child: _buildCardBlock(
                        title: isEn ? 'EDUCATION' : 'FORMACIÓN',
                        accentColor: accentColor,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...widget.profile.educations.map((ed) => _buildEducationItem(ed, accentColor)),
                              const SizedBox(height: 10),
                              if (widget.profile.availability.isNotEmpty)
                                Text('Disp: ${widget.profile.availability}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                              if (widget.profile.drivingLicense.isNotEmpty)
                                Text('Permiso: ${widget.profile.drivingLicense}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helper Widgets ---

  Widget _buildCardBlock({required String title, required Color accentColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 3, height: 11, color: accentColor),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accentColor)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildHeaderContactChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label: $val',
              style: const TextStyle(fontSize: 8, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  List<CvSkillItem> _getSkillsList() {
    if (widget.profile.skillItems.isNotEmpty) {
      return widget.profile.skillItems;
    }
    if (widget.profile.skills.isNotEmpty) {
      return widget.profile.skills
          .map((s) => CvSkillItem(
                name: s,
                level: 5,
                description: '',
              ))
          .toList();
    }
    return [];
  }

  IconData _getSkillIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('equipo') || lower.contains('team') || lower.contains('compañer')) {
      return Icons.groups_outlined;
    }
    if (lower.contains('seguridad') ||
        lower.contains('epi') ||
        lower.contains('prevenci') ||
        lower.contains('riesgo') ||
        lower.contains('safety')) {
      return Icons.verified_user_outlined;
    }
    if (lower.contains('puntual') ||
        lower.contains('seriedad') ||
        lower.contains('horario') ||
        lower.contains('tiempo') ||
        lower.contains('time')) {
      return Icons.schedule_outlined;
    }
    if (lower.contains('herramienta') ||
        lower.contains('tool') ||
        lower.contains('maquinaria') ||
        lower.contains('util') ||
        lower.contains('taller')) {
      return Icons.build_outlined;
    }
    if (lower.contains('aprendiz') ||
        lower.contains('capac') ||
        lower.contains('learn') ||
        lower.contains('asimil') ||
        lower.contains('tecnic')) {
      return Icons.psychology_outlined;
    }
    if (lower.contains('jardin') || lower.contains('plant')) {
      return Icons.yard_outlined;
    }
    if (lower.contains('fontaner') || lower.contains('agua')) {
      return Icons.plumbing_outlined;
    }
    if (lower.contains('electr')) {
      return Icons.bolt_outlined;
    }
    return Icons.star_outline;
  }

  String _getSkillDescription(CvSkillItem item) {
    if (item.description.isNotEmpty) return item.description;
    final lower = item.name.toLowerCase();
    if (lower.contains('equipo')) return 'Compañerismo y coordinación en cuadrilla';
    if (lower.contains('epi') || lower.contains('prevenci')) return 'Seguridad y prevención de riesgos en obra';
    if (lower.contains('puntual')) return 'Compromiso riguroso con horarios y tareas';
    if (lower.contains('herramienta')) return 'Destreza con útiles manuales y eléctricos';
    if (lower.contains('aprendiz')) return 'Asimilación rápida de nuevas técnicas';
    return '';
  }

  Widget _buildRatingDots(
    int level, {
    Color activeColor = const Color(0xFFFBBF24),
    Color inactiveColor = Colors.white24,
    double dotSize = 4.6,
  }) {
    final isStars = widget.profile.skillRatingStyle == 'stars';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isFilled = (index + 1) <= level;
        if (isStars) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.6),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              size: dotSize * 1.6,
              color: isFilled ? activeColor : inactiveColor,
            ),
          );
        }
        return Container(
          width: dotSize,
          height: dotSize,
          margin: const EdgeInsets.symmetric(horizontal: 1.1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? activeColor : inactiveColor,
          ),
        );
      }),
    );
  }

  Widget _buildCompetencyRow(CvSkillItem item) {
    final icon = _getSkillIcon(item.name);
    final desc = _getSkillDescription(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 12.5, color: Colors.white.withOpacity(0.95)),
              const SizedBox(width: 4.5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 7.6,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildRatingDots(
                item.level,
                activeColor: const Color(0xFFFBBF24),
                inactiveColor: Colors.white.withOpacity(0.25),
                dotSize: 4.6,
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: Text(
                desc,
                style: TextStyle(
                  fontSize: 6.8,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.25,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionPill(String title, Color accentColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: _buildWatermarkOverlay(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: _getTextStyle(
                  color: Colors.white,
                  fontSize: 8.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceItemWithIcon(CvExperience exp, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5, right: 6),
            child: Icon(Icons.business_center_outlined, size: 12.5, color: accentColor),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exp.jobTitle.isNotEmpty ? exp.jobTitle.toUpperCase() : 'PUESTO / OFICIO',
                  style: TextStyle(
                    fontSize: 8.4,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        exp.company,
                        style: TextStyle(
                          fontSize: 7.8,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                    if (exp.period.isNotEmpty)
                      Text(
                        exp.period,
                        style: const TextStyle(
                          fontSize: 7.2,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
                if (exp.description.isNotEmpty) ...[
                  const SizedBox(height: 2.5),
                  Text(
                    exp.description,
                    style: const TextStyle(
                      fontSize: 7.5,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationItemWithIcon(CvEducation edu, Color accentColor, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5, right: 6),
            child: Icon(
              index == 0 ? Icons.school_outlined : Icons.workspace_premium_outlined,
              size: 12.5,
              color: accentColor,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edu.degree.isNotEmpty ? edu.degree.toUpperCase() : 'TITULACIÓN / CERTIFICADO',
                  style: TextStyle(
                    fontSize: 8.2,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        edu.institution,
                        style: TextStyle(
                          fontSize: 7.8,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                    if (edu.period.isNotEmpty)
                      Text(
                        edu.period,
                        style: const TextStyle(
                          fontSize: 7.2,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
                if (edu.details.isNotEmpty) ...[
                  const SizedBox(height: 2.5),
                  Text(
                    edu.details,
                    style: const TextStyle(
                      fontSize: 7.5,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillOnColor(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _parseAccent(widget.profile.accentColor),
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildContactRowWhite(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 10.5, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 7.8,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 12,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceItem(CvExperience exp, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  exp.jobTitle.isNotEmpty ? exp.jobTitle : 'Puesto / Oficio',
                  style: const TextStyle(
                    fontSize: 8.8,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (exp.period.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    exp.period,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          if (exp.company.isNotEmpty)
            Text(
              exp.company,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          if (exp.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              exp.description,
              style: const TextStyle(
                fontSize: 7.8,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEducationItem(CvEducation edu, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  edu.degree.isNotEmpty ? edu.degree : 'Titulación / Certificado',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (edu.period.isNotEmpty)
                Text(
                  edu.period,
                  style: const TextStyle(fontSize: 7.2, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
            ],
          ),
          if (edu.institution.isNotEmpty)
            Text(
              edu.institution,
              style: TextStyle(
                fontSize: 7.8,
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (edu.details.isNotEmpty)
            Text(
              edu.details,
              style: const TextStyle(fontSize: 7.5, color: Color(0xFF64748B)),
            ),
        ],
      ),
    );
  }
}
