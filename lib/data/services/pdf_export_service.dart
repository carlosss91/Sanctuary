import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/cv_profile_model.dart';

class PdfExportService {
  static Future<void> printOrSavePdf(CvProfileModel profile) async {
    final pdfBytes = await generatePdfBytes(profile);
    final safeName = profile.fullName.trim().isEmpty
        ? 'Curriculum_Vitae'
        : profile.fullName.trim().replaceAll(' ', '_');

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${safeName}_CV.pdf',
    );
  }

  static Future<Uint8List> generatePdfBytes(CvProfileModel profile) async {
    final doc = pw.Document();

    final isEn = profile.isEnglishVersion;
    final accentPdfColor = _hexToPdfColor(profile.accentColor);
    final textDarkColor = PdfColor.fromInt(0xFF0F172A);
    final textMutedColor = PdfColor.fromInt(0xFF475569);
    final bgCardColor = PdfColor.fromInt(0xFFF8FAFC);
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);

    // Fetch or decode photo bytes
    final photoBytes = await _fetchOrDecodePhoto(profile.photoUrl);
    final pw.MemoryImage? photoImage =
        photoBytes != null ? pw.MemoryImage(photoBytes) : null;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context context) {
          switch (profile.template) {
            case 'modern_header':
              return _buildModernHeaderLayout(
                profile,
                photoImage,
                accentPdfColor,
                textDarkColor,
                textMutedColor,
                bgCardColor,
                borderColor,
                isEn,
              );
            case 'minimalist':
              return _buildMinimalistLayout(
                profile,
                photoImage,
                accentPdfColor,
                textDarkColor,
                textMutedColor,
                borderColor,
                isEn,
              );
            case 'tech_cards':
              return _buildTechCardsLayout(
                profile,
                photoImage,
                accentPdfColor,
                textDarkColor,
                textMutedColor,
                bgCardColor,
                borderColor,
                isEn,
              );
            case 'sidebar_dark':
            default:
              return _buildSidebarDarkLayout(
                profile,
                photoImage,
                accentPdfColor,
                textDarkColor,
                textMutedColor,
                isEn,
              );
          }
        },
      ),
    );

    return doc.save();
  }

  // ==============================================================================
  // PHOTO FETCH & HELPER
  // ==============================================================================
  static Future<Uint8List?> _fetchOrDecodePhoto(String photoUrl) async {
    if (photoUrl.trim().isEmpty) return null;

    if (photoUrl.startsWith('data:image')) {
      try {
        final comma = photoUrl.indexOf(',');
        final base64Str = comma >= 0 ? photoUrl.substring(comma + 1) : photoUrl;
        return base64Decode(base64Str);
      } catch (_) {
        return null;
      }
    }

    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      try {
        final res = await http.get(Uri.parse(photoUrl)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          return res.bodyBytes;
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static pw.Widget _buildPhotoWidget({
    required CvProfileModel profile,
    required pw.MemoryImage? photoImage,
    required double size,
    required PdfColor accentColor,
    bool isWhiteBorder = true,
  }) {
    final isSquare = profile.photoShape == 'square';
    final radius = isSquare ? pw.Radius.circular(size * 0.16) : pw.Radius.circular(size * 0.5);

    if (photoImage != null) {
      final imgWidget = pw.Image(photoImage, fit: pw.BoxFit.cover);
      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          shape: isSquare ? pw.BoxShape.rectangle : pw.BoxShape.circle,
          borderRadius: isSquare ? pw.BorderRadius.all(radius) : null,
          border: pw.Border.all(
            color: isWhiteBorder ? PdfColors.white : accentColor,
            width: 2.5,
          ),
        ),
        child: isSquare
            ? pw.ClipRRect(
                horizontalRadius: size * 0.16,
                verticalRadius: size * 0.16,
                child: imgWidget,
              )
            : pw.ClipOval(child: imgWidget),
      );
    }

    // Initials fallback
    final initials = profile.fullName.isNotEmpty
        ? profile.fullName
            .trim()
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0].toUpperCase())
            .take(2)
            .join()
        : 'CV';

    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        shape: isSquare ? pw.BoxShape.rectangle : pw.BoxShape.circle,
        borderRadius: isSquare ? pw.BorderRadius.all(radius) : null,
        color: isWhiteBorder ? PdfColors.white : PdfColor.fromInt(0xFFE2E8F0),
        border: pw.Border.all(
          color: isWhiteBorder ? PdfColors.white : accentColor,
          width: 2.5,
        ),
      ),
      child: pw.Center(
        child: pw.Text(
          initials,
          style: pw.TextStyle(
            color: isWhiteBorder ? accentColor : accentColor,
            fontSize: size * 0.36,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==============================================================================
  // 1. TEMPLATE: SIDEBAR DARK (COLUMNA LATERAL)
  // ==============================================================================
  static pw.Widget _buildSidebarDarkLayout(
    CvProfileModel profile,
    pw.MemoryImage? photoImage,
    PdfColor accentColor,
    PdfColor textDarkColor,
    PdfColor textMutedColor,
    bool isEn,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Left Column
        pw.Container(
          width: 175,
          decoration: pw.BoxDecoration(
            color: accentColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildPhotoWidget(
                profile: profile,
                photoImage: photoImage,
                size: 80,
                accentColor: accentColor,
                isWhiteBorder: true,
              ),
              pw.SizedBox(height: 12),

              _buildPillOnColor(isEn ? 'CONTACT DETAILS' : 'DATOS'),
              pw.SizedBox(height: 8),

              if (profile.phone.isNotEmpty) _buildContactRowWhite('Tel:', profile.phone),
              if (profile.email.isNotEmpty) _buildContactRowWhite('Email:', profile.email),
              if (profile.location.isNotEmpty) _buildContactRowWhite('Ubicación:', profile.location),
              if (profile.availability.isNotEmpty) _buildContactRowWhite('Disp:', profile.availability),
              if (profile.drivingLicense.isNotEmpty) _buildContactRowWhite('Permiso:', profile.drivingLicense),

              if (profile.summary.trim().isNotEmpty) ...[
                pw.SizedBox(height: 12),
                _buildPillOnColor(isEn ? 'ABOUT ME' : 'SOBRE MÍ'),
                pw.SizedBox(height: 6),
                pw.Text(
                  profile.summary,
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 8, lineSpacing: 1.4),
                  textAlign: pw.TextAlign.justify,
                ),
              ],

              if (_getSkillsList(profile).isNotEmpty) ...[
                pw.SizedBox(height: 12),
                _buildPillOnColor(isEn ? 'KEY SKILLS' : 'COMPETENCIAS'),
                pw.SizedBox(height: 8),
                ..._getSkillsList(profile).map((s) => _buildPdfCompetencyRow(s, accentColor, profile.skillRatingStyle == 'stars')),
              ],

              pw.Spacer(),

              // Watermark representation
              if (profile.showWatermark && profile.watermarkPattern != 'none' && profile.watermarkOpacity > 0)
                _buildWatermarkTag(profile, PdfColors.white),
            ],
          ),
        ),

        pw.SizedBox(width: 14),

        // Right Column
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: accentColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      profile.fullName.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (profile.jobTitle.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        profile.jobTitle.toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              _buildSectionPill(isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL', accentColor),
              pw.SizedBox(height: 8),

              if (profile.experiences.isEmpty)
                pw.Text(
                  isEn ? 'No work experience registered yet.' : 'Sin experiencia laboral registrada aún.',
                  style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                )
              else
                ...profile.experiences.map((exp) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 9),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          exp.jobTitle.toUpperCase(),
                          style: pw.TextStyle(color: textDarkColor, fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 1.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              exp.company,
                              style: pw.TextStyle(color: accentColor, fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(exp.period, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5)),
                          ],
                        ),
                        if (exp.description.isNotEmpty) ...[
                          pw.SizedBox(height: 2.5),
                          pw.Text(
                            exp.description,
                            style: pw.TextStyle(color: textMutedColor, fontSize: 8, lineSpacing: 1.3),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

              pw.SizedBox(height: 10),

              _buildSectionPill(
                isEn ? 'EDUCATION & CERTIFICATIONS' : 'FORMACIÓN Y CERTIFICACIONES',
                accentColor,
              ),
              pw.SizedBox(height: 8),

              if (profile.educations.isEmpty)
                pw.Text(
                  isEn ? 'No education records yet.' : 'Sin estudios registrados aún.',
                  style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                )
              else
                ...profile.educations.map((edu) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 9),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          edu.degree.toUpperCase(),
                          style: pw.TextStyle(color: textDarkColor, fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 1.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              edu.institution,
                              style: pw.TextStyle(color: accentColor, fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(edu.period, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5)),
                          ],
                        ),
                        if (edu.details.isNotEmpty) ...[
                          pw.SizedBox(height: 2.5),
                          pw.Text(
                            edu.details,
                            style: pw.TextStyle(color: textMutedColor, fontSize: 8, lineSpacing: 1.3),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================================
  // 2. TEMPLATE: MODERN HEADER (CABECERA MODERNA & 2 COLUMNAS)
  // ==============================================================================
  static pw.Widget _buildModernHeaderLayout(
    CvProfileModel profile,
    pw.MemoryImage? photoImage,
    PdfColor accentColor,
    PdfColor textDarkColor,
    PdfColor textMutedColor,
    PdfColor bgCardColor,
    PdfColor borderColor,
    bool isEn,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Full width header banner
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: accentColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildPhotoWidget(
                profile: profile,
                photoImage: photoImage,
                size: 74,
                accentColor: accentColor,
                isWhiteBorder: true,
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      profile.fullName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (profile.jobTitle.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        profile.jobTitle.toUpperCase(),
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFFF1F5F9),
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 6),
                    pw.Wrap(
                      spacing: 8,
                      runSpacing: 3,
                      children: [
                        if (profile.email.isNotEmpty)
                          _buildMiniBadgeWhite('Email: ${profile.email}'),
                        if (profile.phone.isNotEmpty)
                          _buildMiniBadgeWhite('Tel: ${profile.phone}'),
                        if (profile.location.isNotEmpty)
                          _buildMiniBadgeWhite('Ubicación: ${profile.location}'),
                        if (profile.drivingLicense.isNotEmpty)
                          _buildMiniBadgeWhite('Permiso: ${profile.drivingLicense}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 14),

        // 2 Columns below
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left column: Experience & Education (60%)
              pw.Expanded(
                flex: 6,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionUnderline(isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL', accentColor),
                    pw.SizedBox(height: 8),
                    if (profile.experiences.isEmpty)
                      pw.Text(
                        isEn ? 'No experience registered.' : 'Sin experiencia registrada.',
                        style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8.5),
                      )
                    else
                      ...profile.experiences.map((exp) {
                        return pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 9),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                exp.jobTitle.toUpperCase(),
                                style: pw.TextStyle(color: textDarkColor, fontSize: 9, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(exp.company, style: pw.TextStyle(color: accentColor, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                  pw.Text(exp.period, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5)),
                                ],
                              ),
                              if (exp.description.isNotEmpty) ...[
                                pw.SizedBox(height: 2.5),
                                pw.Text(exp.description, style: pw.TextStyle(color: textMutedColor, fontSize: 8, lineSpacing: 1.3)),
                              ],
                            ],
                          ),
                        );
                      }),

                    pw.SizedBox(height: 12),
                    _buildSectionUnderline(isEn ? 'EDUCATION & CERTIFICATIONS' : 'FORMACIÓN Y CERTIFICACIONES', accentColor),
                    pw.SizedBox(height: 8),
                    if (profile.educations.isEmpty)
                      pw.Text(
                        isEn ? 'No education registered.' : 'Sin formación registrada.',
                        style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8.5),
                      )
                    else
                      ...profile.educations.map((edu) {
                        return pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 9),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                edu.degree.toUpperCase(),
                                style: pw.TextStyle(color: textDarkColor, fontSize: 9, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(edu.institution, style: pw.TextStyle(color: accentColor, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                  pw.Text(edu.period, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5)),
                                ],
                              ),
                              if (edu.details.isNotEmpty) ...[
                                pw.SizedBox(height: 2.5),
                                pw.Text(edu.details, style: pw.TextStyle(color: textMutedColor, fontSize: 8, lineSpacing: 1.3)),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              pw.SizedBox(width: 14),

              // Right column: Profile, Skills, Extras (40%)
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionUnderline(isEn ? 'PROFILE SUMMARY' : 'SOBRE MÍ', accentColor),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      profile.summary,
                      style: pw.TextStyle(color: textDarkColor, fontSize: 8, lineSpacing: 1.4),
                      textAlign: pw.TextAlign.justify,
                    ),

                    if (_getSkillsList(profile).isNotEmpty) ...[
                      pw.SizedBox(height: 12),
                      _buildSectionUnderline(isEn ? 'KEY SKILLS' : 'COMPETENCIAS', accentColor),
                      pw.SizedBox(height: 6),
                      pw.Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _getSkillsList(profile).map((s) {
                          return pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: pw.BoxDecoration(
                              color: bgCardColor,
                              border: pw.Border.all(color: borderColor),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text(
                                  s.name,
                                  style: pw.TextStyle(color: accentColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.SizedBox(width: 3),
                                _buildPdfRatingDots(s.level, isStars: profile.skillRatingStyle == 'stars', inactiveColor: PdfColors.grey300),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    if (profile.availability.isNotEmpty || profile.drivingLicense.isNotEmpty) ...[
                      pw.SizedBox(height: 12),
                      _buildSectionUnderline(isEn ? 'ADDITIONAL INFO' : 'DATOS ADICIONALES', accentColor),
                      pw.SizedBox(height: 6),
                      if (profile.availability.isNotEmpty)
                        _buildContactRowDark('Disponibilidad:', profile.availability, accentColor, textDarkColor),
                      if (profile.drivingLicense.isNotEmpty)
                        _buildContactRowDark('Permiso conducir:', profile.drivingLicense, accentColor, textDarkColor),
                    ],

                    pw.Spacer(),
                    if (profile.showWatermark && profile.watermarkPattern != 'none' && profile.watermarkOpacity > 0)
                      _buildWatermarkTag(profile, accentColor),
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
  // 3. TEMPLATE: MINIMALIST (MINIMALISTA CLÁSICO)
  // ==============================================================================
  static pw.Widget _buildMinimalistLayout(
    CvProfileModel profile,
    pw.MemoryImage? photoImage,
    PdfColor accentColor,
    PdfColor textDarkColor,
    PdfColor textMutedColor,
    PdfColor borderColor,
    bool isEn,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Minimal Top Header
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _buildPhotoWidget(
              profile: profile,
              photoImage: photoImage,
              size: 68,
              accentColor: accentColor,
              isWhiteBorder: false,
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    profile.fullName.toUpperCase(),
                    style: pw.TextStyle(
                      color: textDarkColor,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (profile.jobTitle.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      profile.jobTitle.toUpperCase(),
                      style: pw.TextStyle(
                        color: accentColor,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 4),
                  pw.Text(
                    [
                      if (profile.email.isNotEmpty) profile.email,
                      if (profile.phone.isNotEmpty) profile.phone,
                      if (profile.location.isNotEmpty) profile.location,
                      if (profile.drivingLicense.isNotEmpty) 'Permiso: ${profile.drivingLicense}',
                    ].join('   ·   '),
                    style: pw.TextStyle(color: textMutedColor, fontSize: 7.5),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),
        pw.Container(height: 1.5, color: accentColor),
        pw.SizedBox(height: 10),

        // Summary
        if (profile.summary.isNotEmpty) ...[
          _buildMinimalistHeading(isEn ? 'PROFILE' : 'PERFIL PROFESIONAL', accentColor),
          pw.SizedBox(height: 4),
          pw.Text(
            profile.summary,
            style: pw.TextStyle(color: textDarkColor, fontSize: 8, lineSpacing: 1.4),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),
        ],

        // Experience
        _buildMinimalistHeading(isEn ? 'EXPERIENCE' : 'EXPERIENCIA LABORAL', accentColor),
        pw.SizedBox(height: 6),
        if (profile.experiences.isEmpty)
          pw.Text(isEn ? 'No experience listed.' : 'Sin experiencia listada.', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8.5))
        else
          ...profile.experiences.map((exp) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(exp.jobTitle.toUpperCase(), style: pw.TextStyle(color: textDarkColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text(exp.period, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5)),
                    ],
                  ),
                  pw.Text(exp.company, style: pw.TextStyle(color: accentColor, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  if (exp.description.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(exp.description, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5, lineSpacing: 1.3)),
                  ],
                ],
              ),
            );
          }),

        pw.SizedBox(height: 10),

        // Education
        _buildMinimalistHeading(isEn ? 'EDUCATION' : 'FORMACIÓN Y ESTUDIOS', accentColor),
        pw.SizedBox(height: 6),
        if (profile.educations.isEmpty)
          pw.Text(isEn ? 'No education listed.' : 'Sin educación listada.', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8.5))
        else
          ...profile.educations.map((edu) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(edu.degree.toUpperCase(), style: pw.TextStyle(color: textDarkColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text(edu.period, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5)),
                    ],
                  ),
                  pw.Text(edu.institution, style: pw.TextStyle(color: accentColor, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  if (edu.details.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(edu.details, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5, lineSpacing: 1.3)),
                  ],
                ],
              ),
            );
          }),

        if (_getSkillsList(profile).isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _buildMinimalistHeading(isEn ? 'SKILLS & COMPETENCIES' : 'COMPETENCIAS Y HABILIDADES', accentColor),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _getSkillsList(profile).map((s) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: accentColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      s.name,
                      style: pw.TextStyle(color: textDarkColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(width: 3),
                    _buildPdfRatingDots(s.level, isStars: profile.skillRatingStyle == 'stars', inactiveColor: PdfColors.grey400),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        pw.Spacer(),
        if (profile.showWatermark && profile.watermarkPattern != 'none' && profile.watermarkOpacity > 0)
          _buildWatermarkTag(profile, accentColor),
      ],
    );
  }

  // ==============================================================================
  // 4. TEMPLATE: TECH CARDS (TARJETAS MODULARES CONTEMPORÁNEAS)
  // ==============================================================================
  static pw.Widget _buildTechCardsLayout(
    CvProfileModel profile,
    pw.MemoryImage? photoImage,
    PdfColor accentColor,
    PdfColor textDarkColor,
    PdfColor textMutedColor,
    PdfColor bgCardColor,
    PdfColor borderColor,
    bool isEn,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Top Tech Header Card
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: bgCardColor,
            border: pw.Border.all(color: borderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            children: [
              _buildPhotoWidget(
                profile: profile,
                photoImage: photoImage,
                size: 64,
                accentColor: accentColor,
                isWhiteBorder: false,
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      profile.fullName.toUpperCase(),
                      style: pw.TextStyle(
                        color: textDarkColor,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (profile.jobTitle.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        profile.jobTitle.toUpperCase(),
                        style: pw.TextStyle(
                          color: accentColor,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        if (profile.email.isNotEmpty) _buildMiniBadgeDark('Email: ${profile.email}', accentColor),
                        if (profile.phone.isNotEmpty) _buildMiniBadgeDark('Tel: ${profile.phone}', accentColor),
                        if (profile.location.isNotEmpty) _buildMiniBadgeDark('Ubicación: ${profile.location}', accentColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 10),

        // Modular Cards below
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left Column (60%): Experience & Education Cards
              pw.Expanded(
                flex: 6,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Experience Card
                    _buildTechCardContainer(
                      title: isEn ? 'EXPERIENCE LOG' : 'EXPERIENCIA LABORAL',
                      accentColor: accentColor,
                      bgCardColor: bgCardColor,
                      borderColor: borderColor,
                      child: profile.experiences.isEmpty
                          ? pw.Text(isEn ? 'No log.' : 'Sin registros.', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8))
                          : pw.Column(
                              children: profile.experiences.map((exp) {
                                return pw.Container(
                                  margin: const pw.EdgeInsets.only(bottom: 7),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text(exp.jobTitle.toUpperCase(), style: pw.TextStyle(color: textDarkColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                          pw.Text(exp.period, style: pw.TextStyle(color: textMutedColor, fontSize: 7)),
                                        ],
                                      ),
                                      pw.Text(exp.company, style: pw.TextStyle(color: accentColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                                      if (exp.description.isNotEmpty) ...[
                                        pw.SizedBox(height: 2),
                                        pw.Text(exp.description, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5, lineSpacing: 1.2)),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),

                    pw.SizedBox(height: 8),

                    // Education Card
                    _buildTechCardContainer(
                      title: isEn ? 'CERTIFICATIONS & EDUCATION' : 'FORMACIÓN Y CERTIFICACIONES',
                      accentColor: accentColor,
                      bgCardColor: bgCardColor,
                      borderColor: borderColor,
                      child: profile.educations.isEmpty
                          ? pw.Text(isEn ? 'No log.' : 'Sin registros.', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8))
                          : pw.Column(
                              children: profile.educations.map((edu) {
                                return pw.Container(
                                  margin: const pw.EdgeInsets.only(bottom: 7),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text(edu.degree.toUpperCase(), style: pw.TextStyle(color: textDarkColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                          pw.Text(edu.period, style: pw.TextStyle(color: textMutedColor, fontSize: 7)),
                                        ],
                                      ),
                                      pw.Text(edu.institution, style: pw.TextStyle(color: accentColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                                      if (edu.details.isNotEmpty) ...[
                                        pw.SizedBox(height: 2),
                                        pw.Text(edu.details, style: pw.TextStyle(color: textMutedColor, fontSize: 7.5, lineSpacing: 1.2)),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(width: 10),

              // Right Column (40%): Profile & Stack Cards
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Profile Card
                    _buildTechCardContainer(
                      title: isEn ? 'CORE PROFILE' : 'PERFIL TÉCNICO',
                      accentColor: accentColor,
                      bgCardColor: bgCardColor,
                      borderColor: borderColor,
                      child: pw.Text(
                        profile.summary,
                        style: pw.TextStyle(color: textDarkColor, fontSize: 8, lineSpacing: 1.3),
                        textAlign: pw.TextAlign.justify,
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    // Skills Card
                    if (_getSkillsList(profile).isNotEmpty)
                      _buildTechCardContainer(
                        title: isEn ? 'STACK & SKILLS' : 'STACK Y HABILIDADES',
                        accentColor: accentColor,
                        bgCardColor: bgCardColor,
                        borderColor: borderColor,
                        child: pw.Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _getSkillsList(profile).map((s) {
                            return pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                border: pw.Border.all(color: borderColor),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                              ),
                              child: pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text(
                                    s.name,
                                    style: pw.TextStyle(color: accentColor, fontSize: 7, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.SizedBox(width: 3),
                                  _buildPdfRatingDots(s.level, isStars: profile.skillRatingStyle == 'stars', inactiveColor: PdfColor(accentColor.red, accentColor.green, accentColor.blue, 0.25)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    pw.Spacer(),
                    if (profile.showWatermark && profile.watermarkPattern != 'none' && profile.watermarkOpacity > 0)
                      _buildWatermarkTag(profile, accentColor),
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
  // COMMON HELPER WIDGETS
  // ==============================================================================
  static pw.Widget _buildPillOnColor(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: const pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Text(
        title,
        style: const pw.TextStyle(
          color: PdfColors.black,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static List<CvSkillItem> _getSkillsList(CvProfileModel profile) {
    if (profile.skillItems.isNotEmpty) return profile.skillItems;
    if (profile.skills.isNotEmpty) {
      return profile.skills.map((s) => CvSkillItem(name: s, level: 5)).toList();
    }
    return [];
  }

  static pw.Widget _buildPdfRatingDots(
    int level, {
    bool isStars = false,
    PdfColor activeColor = const PdfColor.fromInt(0xFFF59E0B),
    PdfColor inactiveColor = const PdfColor.fromInt(0x44FFFFFF),
  }) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: List.generate(5, (index) {
        final isFilled = (index + 1) <= level;
        if (isStars) {
          return pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 0.8),
            child: pw.SvgImage(
              svg: '<svg viewBox="0 0 24 24"><polygon points="12,2 15,8.5 22,9.3 17,14.1 18.2,21 12,17.8 5.8,21 7,14.1 2,9.3 9,8.5" fill="${isFilled ? '#F59E0B' : '#94A3B8'}"/></svg>',
              width: 5.5,
              height: 5.5,
            ),
          );
        }
        return pw.Container(
          width: 4.2,
          height: 4.2,
          margin: const pw.EdgeInsets.symmetric(horizontal: 1.0),
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: isFilled ? activeColor : inactiveColor,
          ),
        );
      }),
    );
  }

  static pw.Widget _buildPdfCompetencyRow(CvSkillItem item, PdfColor accentColor, [bool isStars = false]) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6.5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  item.name.toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7.2,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 4),
              _buildPdfRatingDots(item.level, isStars: isStars),
            ],
          ),
          if (item.description.isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(
              item.description,
              style: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 6.5,
                lineSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildSectionPill(String title, PdfColor color) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Text(
        title,
        style: const pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static pw.Widget _buildSectionUnderline(String title, PdfColor accentColor) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 1.5)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(
        title,
        style: pw.TextStyle(color: accentColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6),
      ),
    );
  }

  static pw.Widget _buildMinimalistHeading(String title, PdfColor accentColor) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 1.0)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: accentColor,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  static pw.Widget _buildTechCardContainer({
    required String title,
    required PdfColor accentColor,
    required PdfColor bgCardColor,
    required PdfColor borderColor,
    required pw.Widget child,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bgCardColor,
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 3, height: 10, color: accentColor),
              pw.SizedBox(width: 4),
              pw.Text(
                title,
                style: pw.TextStyle(color: accentColor, fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  static pw.Widget _buildContactRowWhite(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 7.5),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildContactRowDark(String label, String value, PdfColor labelColor, PdfColor valColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(color: labelColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(color: valColor, fontSize: 7.5),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMiniBadgeWhite(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: const pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(color: PdfColors.black, fontSize: 7, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildMiniBadgeDark(String text, PdfColor accentColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: accentColor, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: accentColor, fontSize: 7, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildWatermarkTag(CvProfileModel profile, PdfColor color) {
    final pattern = profile.watermarkPattern;
    String symbol = '* SANCTUARY VERIFIED *';
    if (pattern == 'gears') symbol = '* INDUSTRIAL CERTIFIED *';
    if (pattern == 'tools') symbol = '* TECHNICAL CV *';
    if (pattern == 'shield') symbol = '* OFFICIAL PROFILE *';

    final alpha = (profile.watermarkOpacity * 255).clamp(0, 255).toInt();
    final watermarkColor = PdfColor(color.red, color.green, color.blue, alpha / 255.0);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        symbol,
        style: pw.TextStyle(
          color: watermarkColor,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  static PdfColor _hexToPdfColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      final r = int.parse(clean.substring(0, 2), radix: 16);
      final g = int.parse(clean.substring(2, 4), radix: 16);
      final b = int.parse(clean.substring(4, 6), radix: 16);
      return PdfColor(r / 255.0, g / 255.0, b / 255.0);
    }
    return PdfColor.fromInt(0xFF0D9488);
  }
}
