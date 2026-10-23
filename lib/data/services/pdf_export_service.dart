import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/cv_maker/widgets/watermark_painter.dart';
import '../models/cv_profile_model.dart';

class PdfExportService {
  static Future<void> printOrSavePdf(CvProfileModel profile) async {
    final pdfBytes = await generatePdfBytes(profile);
    final safeName = profile.fullName.trim().isEmpty
        ? 'Curriculum_Vitae'
        : profile.fullName.trim().replaceAll(' ', '_');

    // On Web & Mobile, sharePdf initiates a direct, lossless binary download to the user's device
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${safeName}_CV.pdf',
    );
  }

  static Future<void> printPdf(CvProfileModel profile) async {
    final pdfBytes = await generatePdfBytes(profile);
    final safeName = profile.fullName.trim().isEmpty
        ? 'Curriculum_Vitae'
        : profile.fullName.trim().replaceAll(' ', '_');

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${safeName}_CV.pdf',
    );
  }

  static Future<Uint8List> generatePdfBytes(CvProfileModel rawProfile) async {
    // 1. Sanitize all text fields so dashes (–, —), bullets (•), and quotes never show as [X] boxes in PDF
    final profile = _sanitizeProfileForPdf(rawProfile);
    final safeName = profile.fullName.trim().isEmpty ? 'Curriculum' : profile.fullName.trim();
    final jsonPayload = base64Encode(utf8.encode(jsonEncode(profile.toJson())));

    // 2. Load Google Fonts if available for true Unicode rendering, fallback safely
    pw.ThemeData? docTheme;
    try {
      final baseFont = await PdfGoogleFonts.interRegular().timeout(const Duration(milliseconds: 1500));
      final boldFont = await PdfGoogleFonts.interBold().timeout(const Duration(milliseconds: 1500));
      docTheme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      );
    } catch (_) {
      // Fallback safely to standard Helvetica (all text sanitized for WinAnsi)
    }

    final doc = pw.Document(
      title: 'Curriculum Vitae - $safeName',
      author: safeName,
      creator: 'Sanctuary Platform',
      subject: 'SanctuaryCV::$jsonPayload',
      keywords: 'SanctuaryCV,Curriculum,CV',
      theme: docTheme,
    );

    final isEn = profile.isEnglishVersion;
    final accentPdfColor = _hexToPdfColor(profile.accentColor);
    final accentHexStr = profile.accentColor.replaceAll('#', '').trim();
    final accentColorValue = int.tryParse('FF$accentHexStr', radix: 16) ?? 0xFF00A3C4;
    final flutterAccentColor = Color(accentColorValue);
    final textDarkColor = PdfColor.fromInt(0xFF0F172A);
    final textMutedColor = PdfColor.fromInt(0xFF475569);
    final bgCardColor = PdfColor.fromInt(0xFFF8FAFC);
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);

    // Fetch or decode photo bytes
    final photoBytes = await _fetchOrDecodePhoto(profile.photoUrl);
    final pw.MemoryImage? photoImage =
        photoBytes != null ? pw.MemoryImage(photoBytes) : null;

    // Pre-render watermarks with exact dimensions matching A4SheetPreview
    pw.MemoryImage? sidebarWatermarkImg;
    pw.MemoryImage? bannerWatermarkImg;
    pw.MemoryImage? pillWatermarkImg;
    pw.MemoryImage? modernBannerWatermarkImg;
    pw.MemoryImage? techHeroWatermarkImg;

    if (profile.showWatermark &&
        profile.watermarkPattern != 'none' &&
        profile.watermarkOpacity > 0) {
      try {
        // Sidebar watermark for sidebar_dark template (185 x 806 pt logical)
        final sidebarBytes = await WatermarkPainter.renderWatermarkPng(
          pattern: profile.watermarkPattern,
          opacity: profile.watermarkOpacity,
          density: profile.watermarkDensity,
          randomness: profile.watermarkRandomness,
          customWatermarkUrl: profile.customWatermarkUrl,
          width: 185,
          height: 806,
          backgroundColor: flutterAccentColor,
          borderRadius: 10,
        );
        if (sidebarBytes != null) {
          sidebarWatermarkImg = pw.MemoryImage(sidebarBytes);
        }

        // Header Banner watermark for sidebar_dark (358 x 54 pt logical)
        final bannerBytes = await WatermarkPainter.renderWatermarkPng(
          pattern: profile.watermarkPattern,
          opacity: profile.watermarkOpacity,
          density: profile.watermarkDensity,
          randomness: profile.watermarkRandomness,
          customWatermarkUrl: profile.customWatermarkUrl,
          width: 358,
          height: 54,
          backgroundColor: flutterAccentColor,
          borderRadius: 8,
        );
        if (bannerBytes != null) {
          bannerWatermarkImg = pw.MemoryImage(bannerBytes);
        }

        // Section Pill watermark for sidebar_dark (358 x 22 pt logical)
        final pillBytes = await WatermarkPainter.renderWatermarkPng(
          pattern: profile.watermarkPattern,
          opacity: profile.watermarkOpacity,
          density: profile.watermarkDensity,
          randomness: profile.watermarkRandomness,
          customWatermarkUrl: profile.customWatermarkUrl,
          width: 358,
          height: 22,
          backgroundColor: flutterAccentColor,
          borderRadius: 12,
        );
        if (pillBytes != null) {
          pillWatermarkImg = pw.MemoryImage(pillBytes);
        }

        // Wide Header Banner watermark for modern_header template (559 x 120 pt logical)
        final modernBannerBytes = await WatermarkPainter.renderWatermarkPng(
          pattern: profile.watermarkPattern,
          opacity: profile.watermarkOpacity,
          density: profile.watermarkDensity,
          randomness: profile.watermarkRandomness,
          customWatermarkUrl: profile.customWatermarkUrl,
          width: 559,
          height: 120,
        );
        if (modernBannerBytes != null) {
          modernBannerWatermarkImg = pw.MemoryImage(modernBannerBytes);
        }

        // Hero Card watermark for tech_cards template (559 x 80 pt logical)
        final techHeroBytes = await WatermarkPainter.renderWatermarkPng(
          pattern: profile.watermarkPattern,
          opacity: (profile.watermarkOpacity * 0.75).clamp(0.0, 1.0),
          density: profile.watermarkDensity,
          randomness: profile.watermarkRandomness,
          customWatermarkUrl: profile.customWatermarkUrl,
          width: 559,
          height: 80,
        );
        if (techHeroBytes != null) {
          techHeroWatermarkImg = pw.MemoryImage(techHeroBytes);
        }
      } catch (e) {
        debugPrint('[PdfExportService] Failed to pre-render watermark: $e');
      }
    }

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
                bannerWatermarkImg: modernBannerWatermarkImg,
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
                techHeroWatermarkImg: techHeroWatermarkImg,
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
                sidebarWatermarkImg: sidebarWatermarkImg,
                bannerWatermarkImg: bannerWatermarkImg,
                pillWatermarkImg: pillWatermarkImg,
              );
          }
        },
      ),
    );

    final docBytes = await doc.save();

    // Append an uncompressed comment marker with the base64 JSON payload.
    // In ISO 32000 PDF standard, lines starting with % are comments and fully ignored
    // by all PDF viewers, but remain 100% intact and readable without decompression.
    final marker = utf8.encode('\n%SanctuaryCV::$jsonPayload%\n');
    final combined = Uint8List(docBytes.length + marker.length);
    combined.setRange(0, docBytes.length, docBytes);
    combined.setRange(docBytes.length, combined.length, marker);
    return combined;
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
    bool isEn, {
    pw.MemoryImage? sidebarWatermarkImg,
    pw.MemoryImage? bannerWatermarkImg,
    pw.MemoryImage? pillWatermarkImg,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Left Column (Sidebar: 185pt wide matching A4 preview)
        pw.Container(
          width: 185,
          child: pw.Stack(
            children: [
              if (sidebarWatermarkImg != null)
                pw.Image(sidebarWatermarkImg, fit: pw.BoxFit.fill)
              else
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  ),
                ),
              pw.Padding(
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

                    if (profile.phone.isNotEmpty) _buildContactRowWhiteIcon(_svgPhoneWhite, profile.phone),
                    if (profile.email.isNotEmpty) _buildContactRowWhiteIcon(_svgEmailWhite, profile.email),
                    if (profile.location.isNotEmpty) _buildContactRowWhiteIcon(_svgLocationWhite, profile.location),
                    if (profile.availability.isNotEmpty) _buildContactRowWhiteIcon(_svgTimeWhite, profile.availability),
                    if (profile.drivingLicense.isNotEmpty) _buildContactRowWhiteIcon(_svgCarWhite, profile.drivingLicense),

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
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 16),

        // Right Column
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              pw.Container(
                child: pw.Stack(
                  alignment: pw.Alignment.center,
                  children: [
                    if (bannerWatermarkImg != null)
                      pw.Image(bannerWatermarkImg, fit: pw.BoxFit.fill)
                    else
                      pw.Container(
                        height: 54,
                        decoration: pw.BoxDecoration(
                          color: accentColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                      ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    ],
                  ),
                ),

              pw.SizedBox(height: 12),

              _buildSectionPill(
                isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL',
                accentColor,
                pillWatermarkImg,
              ),
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
                pillWatermarkImg,
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
    bool isEn, {
    pw.MemoryImage? bannerWatermarkImg,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Full width header banner
        pw.Container(
          decoration: pw.BoxDecoration(
            color: accentColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 8,
            verticalRadius: 8,
            child: pw.Stack(
              children: [
                if (bannerWatermarkImg != null)
                  pw.Positioned.fill(
                    child: pw.Image(bannerWatermarkImg, fit: pw.BoxFit.cover),
                  ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(14),
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
                          _buildMiniBadgeWhite('${isEn ? "Location" : "Ubicación"}: ${profile.location}'),
                        if (profile.drivingLicense.isNotEmpty)
                          _buildMiniBadgeWhite('${isEn ? "License" : "Permiso"}: ${profile.drivingLicense}'),
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
                        _buildContactRowDark(isEn ? 'Availability:' : 'Disponibilidad:', profile.availability, accentColor, textDarkColor),
                      if (profile.drivingLicense.isNotEmpty)
                        _buildContactRowDark(isEn ? 'Driving License:' : 'Permiso conducir:', profile.drivingLicense, accentColor, textDarkColor),
                    ],
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
    bool isEn, {
    pw.MemoryImage? techHeroWatermarkImg,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Top Tech Header Card
        pw.Container(
          decoration: pw.BoxDecoration(
            color: bgCardColor,
            border: pw.Border.all(color: borderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Stack(
              children: [
                if (techHeroWatermarkImg != null)
                  pw.Positioned.fill(
                    child: pw.Image(techHeroWatermarkImg, fit: pw.BoxFit.cover),
                  ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(12),
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
              ],
            ),
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

  static pw.Widget _buildSectionPill(String title, PdfColor color, [pw.MemoryImage? watermarkImg]) {
    final textWidget = pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
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

    if (watermarkImg != null) {
      return pw.Container(
        height: 22,
        alignment: pw.Alignment.center,
        child: pw.Stack(
          alignment: pw.Alignment.center,
          children: [
            pw.Image(watermarkImg, fit: pw.BoxFit.fill),
            textWidget,
          ],
        ),
      );
    }

    return pw.Container(
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: textWidget,
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

  static const _svgPhoneWhite =
      '<svg viewBox="0 0 24 24"><path fill="#FFFFFF" d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>';

  static const _svgEmailWhite =
      '<svg viewBox="0 0 24 24"><path fill="#FFFFFF" d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"/></svg>';

  static const _svgLocationWhite =
      '<svg viewBox="0 0 24 24"><path fill="#FFFFFF" d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>';

  static const _svgTimeWhite =
      '<svg viewBox="0 0 24 24"><path fill="#FFFFFF" d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/></svg>';

  static const _svgCarWhite =
      '<svg viewBox="0 0 24 24"><path fill="#FFFFFF" d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z"/></svg>';

  static pw.Widget _buildContactRowWhiteIcon(String svgIcon, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 8.5,
            height: 8.5,
            margin: const pw.EdgeInsets.only(top: 1, right: 5.5),
            child: pw.SvgImage(svg: svgIcon),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 7.5, lineSpacing: 1.2),
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

  // ==============================================================================
  // UNICODE SANITIZATION FOR PDF EXPORT
  // ==============================================================================
  /// Sanitizes text to eliminate missing glyph boxes ([X] / .notdef) in PDF export.
  /// Translates Unicode bullets, dashes, non-standard quotes, and spaces into
  /// standard characters guaranteed to render cleanly in all PDF viewers.
  static String _cleanPdfText(String text) {
    if (text.isEmpty) return text;
    var result = text;
    // Strip invisible zero-width characters
    result = result.replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF\u200E\u200F]'), '');
    // Replace non-breaking spaces with standard space
    result = result.replaceAll('\u00A0', ' ');
    // Bullets & list dots -> standard ASCII dash with space
    result = result.replaceAll(
      RegExp(r'[\u2022\u2023\u2043\u2219\u25AA\u25AB\u25CF\u25CB\u25B6\u25B8\u25E6\u25D8\u25D9\u204C\u204D]'),
      '- ',
    );
    // Dashes & hyphens (en-dash \u2013, em-dash \u2014, figure dash \u2012, minus \u2212, horizontal bar \u2015, etc.) -> standard ASCII hyphen
    result = result.replaceAll(
      RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'),
      '-',
    );
    // Double spaces after bullet replacement: "-  " -> "- "
    result = result.replaceAll('-  ', '- ');
    // Typographic quotes -> standard ASCII
    result = result.replaceAll(RegExp(r'[\u201C\u201D\u00AB\u00BB\u201E\u201F]'), '"');
    result = result.replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B]'), "'");
    // Common symbols
    result = result.replaceAll('…', '...');
    result = result.replaceAll('→', '->');
    result = result.replaceAll('←', '<-');
    result = result.replaceAll(RegExp(r'[✓✔]'), 'v');
    return result;
  }

  /// Returns a clean copy of the profile with all text properties sanitized for PDF.
  static CvProfileModel _sanitizeProfileForPdf(CvProfileModel p) {
    return p.copyWith(
      fullName: _cleanPdfText(p.fullName),
      jobTitle: _cleanPdfText(p.jobTitle),
      moduleBadge: _cleanPdfText(p.moduleBadge),
      workshopTitle: _cleanPdfText(p.workshopTitle),
      phone: _cleanPdfText(p.phone),
      email: _cleanPdfText(p.email),
      location: _cleanPdfText(p.location),
      availability: _cleanPdfText(p.availability),
      drivingLicense: _cleanPdfText(p.drivingLicense),
      summary: _cleanPdfText(p.summary),
      skills: p.skills.map(_cleanPdfText).toList(),
      skillItems: p.skillItems
          .map((s) => s.copyWith(
                name: _cleanPdfText(s.name),
                description: _cleanPdfText(s.description),
              ))
          .toList(),
      experiences: p.experiences
          .map((e) => e.copyWith(
                jobTitle: _cleanPdfText(e.jobTitle),
                company: _cleanPdfText(e.company),
                period: _cleanPdfText(e.period),
                description: _cleanPdfText(e.description),
              ))
          .toList(),
      educations: p.educations
          .map((e) => e.copyWith(
                degree: _cleanPdfText(e.degree),
                institution: _cleanPdfText(e.institution),
                period: _cleanPdfText(e.period),
                details: _cleanPdfText(e.details),
              ))
          .toList(),
    );
  }
}
