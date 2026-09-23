import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/cv_profile_model.dart';

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
  double _scale = 0.52;

  void _zoomIn() {
    setState(() => _scale = (_scale + 0.08).clamp(0.25, 1.8));
  }

  void _zoomOut() {
    setState(() => _scale = (_scale - 0.08).clamp(0.25, 1.8));
  }

  void _resetZoom() {
    setState(() => _scale = 1.0);
  }

  void _autoFit() {
    setState(() => _scale = 0.52);
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

  Widget _buildWatermarkOverlay({double? opacity}) {
    if (!widget.profile.showWatermark ||
        widget.profile.watermarkPattern == 'none') {
      return const SizedBox.shrink();
    }

    final effectiveOpacity = (opacity ?? widget.profile.watermarkOpacity).clamp(0.0, 1.0);
    if (effectiveOpacity <= 0.0) return const SizedBox.shrink();

    if (widget.profile.watermarkPattern == 'custom' && widget.profile.customWatermarkUrl.isNotEmpty) {
      return Opacity(
        opacity: effectiveOpacity,
        child: Image.network(
          widget.profile.customWatermarkUrl,
          fit: BoxFit.cover,
          color: Colors.white.withOpacity(0.7),
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    return CustomPaint(
      painter: WatermarkPainter(
        pattern: widget.profile.watermarkPattern,
        opacity: effectiveOpacity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _parseAccent(widget.profile.accentColor);
    final isEn = widget.profile.isEnglishVersion;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard.withOpacity(0.9) : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        children: [
          // Top Toolbar with quick export, lang and zoom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('${(_scale * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

          // Main Sheet Canvas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Center(
                child: Transform.scale(
                  scale: _scale,
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
          ),

          // ================================================================
          // BOTTOM TOOLBAR: REVERSIBLE LANGUAGE TOGGLE & CV DOWNLOAD
          // ================================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Reversible Language Toggle Button (ES ⇄ EN)
                if (widget.onToggleLanguage != null)
                  InkWell(
                    onTap: widget.onToggleLanguage,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.emerald.withOpacity(0.6), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.translate, size: 15, color: AppTheme.emerald),
                          const SizedBox(width: 8),
                          Text(
                            isEn ? 'English (EN)' : 'Español (ES)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isEn ? '⇄ ES' : '⇄ EN',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Spacer(),

                // Export to PDF
                if (widget.onExportPdf != null)
                  ElevatedButton.icon(
                    onPressed: widget.onExportPdf,
                    icon: const Icon(Icons.picture_as_pdf, size: 15),
                    label: const Text('Exportar PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      elevation: 2,
                    ),
                  ),

                // Download Word DOCX
                if (widget.onExportWord != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.onExportWord,
                    icon: const Icon(Icons.description, size: 15),
                    label: const Text('Descargar Word', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      elevation: 2,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      Column(
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
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: _buildWatermarkOverlay(),
            ),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: _getTextStyle(
                color: Colors.white,
                fontSize: 8.2,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
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
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
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

// ==============================================================================
// WATERMARK PATTERN PAINTER
// ==============================================================================
class WatermarkPainter extends CustomPainter {
  final String pattern;
  final double opacity;

  WatermarkPainter({required this.pattern, this.opacity = 0.14});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.0) return;

    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0) * 0.5)
      ..style = PaintingStyle.fill;

    switch (pattern) {
      case 'gears':
        _drawGears(canvas, size, strokePaint, fillPaint);
        break;
      case 'tools':
        _drawTools(canvas, size, strokePaint, fillPaint);
        break;
      case 'geometric':
        _drawHexagons(canvas, size, strokePaint, fillPaint);
        break;
      case 'shield':
        _drawShield(canvas, size, strokePaint, fillPaint);
        break;
      case 'lines':
        _drawBlueprintLines(canvas, size, strokePaint);
        break;
      case 'tech_dots':
        _drawTechDots(canvas, size, strokePaint, fillPaint);
        break;
      default:
        _drawGears(canvas, size, strokePaint, fillPaint);
    }
  }

  void _drawTechDots(Canvas canvas, Size size, Paint stroke, Paint fill) {
    // 1. Circuit test points
    for (double y = 16; y < size.height; y += 22) {
      for (double x = 12; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 1.6, fill);
        if (((x + y).toInt() % 44) == 0) {
          canvas.drawCircle(Offset(x, y), 3.2, stroke..strokeWidth = 0.8);
        }
      }
    }

    // 2. High-tech orthogonal circuit traces with 45-degree chamfers
    final tracePaint = stroke..strokeWidth = 1.0;
    for (double y = 30; y < size.height - 30; y += 80) {
      final p = Path()
        ..moveTo(10, y)
        ..lineTo(size.width * 0.35, y)
        ..lineTo(size.width * 0.45, y + 14)
        ..lineTo(size.width * 0.85, y + 14)
        ..lineTo(size.width * 0.92, y + 26);
      canvas.drawPath(p, tracePaint);
      canvas.drawCircle(Offset(size.width * 0.92, y + 26), 2.5, fill);
    }

    // 3. Mini Micro-controller IC blocks
    final icWidth = 24.0;
    final icHeight = 16.0;
    for (double y = 50; y < size.height - 40; y += 140) {
      final rect = Rect.fromLTWH(size.width * 0.55 - icWidth / 2, y, icWidth, icHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), stroke..strokeWidth = 1.0);
      for (double px = rect.left + 4; px < rect.right - 2; px += 5) {
        canvas.drawLine(Offset(px, rect.top), Offset(px, rect.top - 3), stroke..strokeWidth = 0.8);
        canvas.drawLine(Offset(px, rect.bottom), Offset(px, rect.bottom + 3), stroke..strokeWidth = 0.8);
      }
    }
  }

  void _drawGears(Canvas canvas, Size size, Paint stroke, Paint fill) {
    // Multi-gear engineering arrangement across the layout
    _drawSingleGear(canvas, Offset(size.width * 0.82, size.height * 0.08), 34.0, 10, stroke, fill);
    _drawSingleGear(canvas, Offset(size.width * 0.96, size.height * 0.15), 18.0, 8, stroke, fill);

    _drawSingleGear(canvas, Offset(size.width * 0.16, size.height * 0.28), 28.0, 9, stroke, fill);
    _drawSingleGear(canvas, Offset(size.width * 0.05, size.height * 0.35), 16.0, 7, stroke, fill);

    _drawSingleGear(canvas, Offset(size.width * 0.86, size.height * 0.50), 32.0, 10, stroke, fill);
    _drawSingleGear(canvas, Offset(size.width * 0.20, size.height * 0.70), 30.0, 9, stroke, fill);

    _drawSingleGear(canvas, Offset(size.width * 0.74, size.height * 0.88), 48.0, 12, stroke, fill);
    _drawSingleGear(canvas, Offset(size.width * 0.26, size.height * 0.94), 30.0, 8, stroke, fill);
    _drawSingleGear(canvas, Offset(size.width * 0.50, size.height * 0.92), 20.0, 7, stroke, fill);
  }

  void _drawSingleGear(Canvas canvas, Offset center, double radius, int teeth, Paint stroke, Paint fill) {
    // 1. Draw outer teeth with solid gear path
    final path = Path();
    final angleStep = (2 * math.pi) / teeth;
    final toothDepth = radius * 0.18;
    final innerR = radius - toothDepth;

    for (int i = 0; i < teeth; i++) {
      final a0 = i * angleStep;
      final a1 = a0 + angleStep * 0.25;
      final a2 = a0 + angleStep * 0.50;
      final a3 = a0 + angleStep * 0.75;
      final a4 = (i + 1) * angleStep;

      final p0 = Offset(center.dx + math.cos(a0) * innerR, center.dy + math.sin(a0) * innerR);
      final p1 = Offset(center.dx + math.cos(a1) * radius, center.dy + math.sin(a1) * radius);
      final p2 = Offset(center.dx + math.cos(a2) * radius, center.dy + math.sin(a2) * radius);
      final p3 = Offset(center.dx + math.cos(a3) * innerR, center.dy + math.sin(a3) * innerR);
      final p4 = Offset(center.dx + math.cos(a4) * innerR, center.dy + math.sin(a4) * innerR);

      if (i == 0) {
        path.moveTo(p0.dx, p0.dy);
      } else {
        path.lineTo(p0.dx, p0.dy);
      }
      path.lineTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke..strokeWidth = 1.4);

    // 2. Pitch circle
    canvas.drawCircle(center, innerR * 0.78, stroke..strokeWidth = 0.9);

    // 3. Central axle hub
    final hubR = innerR * 0.45;
    canvas.drawCircle(center, hubR, stroke..strokeWidth = 1.4);
    canvas.drawCircle(center, hubR * 0.45, fill);
    canvas.drawCircle(center, hubR * 0.45, stroke..strokeWidth = 1.0);

    // 4. Lightening holes in wheel body (4 spokes/holes)
    final holeR = hubR * 0.38;
    final holeDist = innerR * 0.62;
    for (int h = 0; h < 4; h++) {
      final ha = h * (math.pi / 2) + (math.pi / 4);
      final hc = Offset(center.dx + math.cos(ha) * holeDist, center.dy + math.sin(ha) * holeDist);
      canvas.drawCircle(hc, holeR, stroke..strokeWidth = 0.9);
    }
  }

  void _drawTools(Canvas canvas, Size size, Paint stroke, Paint fill) {
    _drawCrossedTools(canvas, Offset(size.width * 0.80, size.height * 0.10), 22, stroke, fill);
    _drawCrossedTools(canvas, Offset(size.width * 0.22, size.height * 0.32), 24, stroke, fill);
    _drawCrossedTools(canvas, Offset(size.width * 0.82, size.height * 0.54), 26, stroke, fill);
    _drawCrossedTools(canvas, Offset(size.width * 0.25, size.height * 0.74), 24, stroke, fill);

    // Bottom large engineering emblem
    _drawCrossedTools(canvas, Offset(size.width * 0.50, size.height * 0.89), 36, stroke, fill);
    _drawSingleGear(canvas, Offset(size.width * 0.50, size.height * 0.89), 42.0, 12, stroke, fill);
  }

  void _drawCrossedTools(Canvas canvas, Offset c, double radius, Paint stroke, Paint fill) {
    // 1. Wrench tool silhouette
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.pi / 4);

    // Wrench shaft & handle
    final wrenchShaft = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: radius * 2.2, height: radius * 0.26),
      const Radius.circular(2),
    );
    canvas.drawRRect(wrenchShaft, fill);
    canvas.drawRRect(wrenchShaft, stroke..strokeWidth = 1.2);

    // Wrench open head on right
    final headRect = Rect.fromCircle(center: Offset(radius * 1.0, 0), radius: radius * 0.45);
    canvas.drawArc(headRect, -math.pi / 2, math.pi, true, stroke..strokeWidth = 1.4);

    // Wrench closed loop on left
    canvas.drawCircle(Offset(-radius * 1.0, 0), radius * 0.38, stroke..strokeWidth = 1.2);
    canvas.drawCircle(Offset(-radius * 1.0, 0), radius * 0.18, stroke..strokeWidth = 1.0);

    canvas.restore();

    // 2. Screwdriver / Hammer tool silhouette
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-math.pi / 4);

    // Tool shaft
    final toolShaft = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: radius * 2.1, height: radius * 0.22),
      const Radius.circular(2),
    );
    canvas.drawRRect(toolShaft, fill);
    canvas.drawRRect(toolShaft, stroke..strokeWidth = 1.2);

    // Handle grip on left
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTWH(-radius * 1.1, -radius * 0.22, radius * 0.7, radius * 0.44),
      const Radius.circular(3),
    );
    canvas.drawRRect(handle, fill);
    canvas.drawRRect(handle, stroke..strokeWidth = 1.2);

    // Screwdriver tip on right
    final tip = Path()
      ..moveTo(radius * 1.0, -radius * 0.1)
      ..lineTo(radius * 1.2, -radius * 0.04)
      ..lineTo(radius * 1.2, radius * 0.04)
      ..lineTo(radius * 1.0, radius * 0.1)
      ..close();
    canvas.drawPath(tip, fill);
    canvas.drawPath(tip, stroke..strokeWidth = 1.0);

    canvas.restore();

    // 3. Central fastening bolt
    canvas.drawCircle(c, radius * 0.38, fill);
    canvas.drawCircle(c, radius * 0.38, stroke..strokeWidth = 1.4);
    canvas.drawCircle(c, radius * 0.16, stroke..strokeWidth = 1.0);
  }

  void _drawHexagons(Canvas canvas, Size size, Paint stroke, Paint fill) {
    const hexR = 14.0;
    final wStep = hexR * 1.732;
    final hStep = hexR * 1.5;

    for (double y = 14; y < size.height + 20; y += hStep) {
      final isOdd = ((y ~/ hStep) % 2 == 1);
      final startX = isOdd ? (wStep / 2) : 0.0;

      for (double x = startX - 10; x < size.width + 20; x += wStep) {
        final center = Offset(x, y);
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * math.pi / 3) - (math.pi / 6);
          final px = center.dx + hexR * math.cos(angle);
          final py = center.dy + hexR * math.sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();

        canvas.drawPath(path, stroke..strokeWidth = 0.9);
        canvas.drawCircle(center, 1.8, fill);

        // Nested miniature hexagon in selected nodes
        if (((x + y).toInt() % 48) == 0) {
          canvas.drawCircle(center, hexR * 0.45, stroke..strokeWidth = 0.8);
        }
      }
    }
  }

  void _drawShield(Canvas canvas, Size size, Paint stroke, Paint fill) {
    _drawSingleShield(canvas, Offset(size.width * 0.80, size.height * 0.10), 24, stroke, fill);
    _drawSingleShield(canvas, Offset(size.width * 0.20, size.height * 0.32), 26, stroke, fill);
    _drawSingleShield(canvas, Offset(size.width * 0.82, size.height * 0.53), 28, stroke, fill);
    _drawSingleShield(canvas, Offset(size.width * 0.22, size.height * 0.74), 26, stroke, fill);
    _drawSingleShield(canvas, Offset(size.width * 0.50, size.height * 0.88), 42, stroke, fill);
  }

  void _drawSingleShield(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    // Outer shield contour
    final outerPath = Path()
      ..moveTo(c.dx, c.dy - s)
      ..lineTo(c.dx + s * 0.85, c.dy - s * 0.45)
      ..quadraticBezierTo(c.dx + s * 0.8, c.dy + s * 0.4, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx - s * 0.8, c.dy + s * 0.4, c.dx - s * 0.85, c.dy - s * 0.45)
      ..close();

    canvas.drawPath(outerPath, fill);
    canvas.drawPath(outerPath, stroke..strokeWidth = 1.6);

    // Inner shield contour
    final innerS = s * 0.78;
    final innerPath = Path()
      ..moveTo(c.dx, c.dy - innerS)
      ..lineTo(c.dx + innerS * 0.85, c.dy - innerS * 0.45)
      ..quadraticBezierTo(c.dx + innerS * 0.8, c.dy + innerS * 0.4, c.dx, c.dy + innerS)
      ..quadraticBezierTo(c.dx - innerS * 0.8, c.dy + innerS * 0.4, c.dx - innerS * 0.85, c.dy - innerS * 0.45)
      ..close();
    canvas.drawPath(innerPath, stroke..strokeWidth = 0.9);

    // Central 5-point star emblem
    final starR = s * 0.35;
    final starPath = Path();
    for (int i = 0; i < 5; i++) {
      final a1 = (i * 4 * math.pi / 5) - (math.pi / 2);
      final px = c.dx + starR * math.cos(a1);
      final py = c.dy + starR * math.sin(a1);
      if (i == 0) {
        starPath.moveTo(px, py);
      } else {
        starPath.lineTo(px, py);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, fill);
    canvas.drawPath(starPath, stroke..strokeWidth = 1.0);
  }

  void _drawBlueprintLines(Canvas canvas, Size size, Paint stroke) {
    // Fine blueprint millimeter grid
    for (double y = 12; y < size.height; y += 14) {
      final isMajor = ((y ~/ 14) % 4 == 0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke..strokeWidth = isMajor ? 1.0 : 0.5);
    }
    for (double x = 12; x < size.width; x += 14) {
      final isMajor = ((x ~/ 14) % 4 == 0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke..strokeWidth = isMajor ? 1.0 : 0.5);
    }

    // Engineering registration crosshairs at key vertices
    final crossR = 6.0;
    for (double y = 42; y < size.height - 20; y += 112) {
      for (double x = 42; x < size.width - 20; x += 112) {
        canvas.drawLine(Offset(x - crossR, y), Offset(x + crossR, y), stroke..strokeWidth = 1.2);
        canvas.drawLine(Offset(x, y - crossR), Offset(x, y + crossR), stroke..strokeWidth = 1.2);
        canvas.drawCircle(Offset(x, y), crossR * 0.7, stroke..strokeWidth = 0.8);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) {
    return oldDelegate.pattern != pattern || oldDelegate.opacity != opacity;
  }
}
