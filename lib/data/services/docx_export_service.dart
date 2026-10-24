import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../models/cv_profile_model.dart';
import '../../features/cv_maker/widgets/watermark_painter.dart';

/// Pre-rendered pill badge asset with dimensions.
class PillBadgeAsset {
  final Uint8List bytes;
  final double width;
  final double height;
  const PillBadgeAsset({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

/// Pre-rendered assets bundle for high-fidelity DOCX generation matching the PDF and A4 Preview.
class DocxAssets {
  final Uint8List? photoBytes;
  final Uint8List? sidebarBgBytes;
  final Uint8List? bannerBgBytes;
  final Uint8List? pillBgBytes;
  final Uint8List? whitePillBytes;
  final Uint8List? iconPhoneBytes;
  final Uint8List? iconEmailBytes;
  final Uint8List? iconLocationBytes;
  final Uint8List? iconClockBytes;
  final Uint8List? iconCarBytes;
  final PillBadgeAsset? pillContact;
  final PillBadgeAsset? pillAbout;
  final PillBadgeAsset? pillSkills;

  const DocxAssets({
    this.photoBytes,
    this.sidebarBgBytes,
    this.bannerBgBytes,
    this.pillBgBytes,
    this.whitePillBytes,
    this.iconPhoneBytes,
    this.iconEmailBytes,
    this.iconLocationBytes,
    this.iconClockBytes,
    this.iconCarBytes,
    this.pillContact,
    this.pillAbout,
    this.pillSkills,
  });
}

class DocxExportService {
  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _getInitials(CvProfileModel profile) {
    if (profile.fullName.trim().isEmpty) return 'CV';
    final parts = profile.fullName.trim().split(' ');
    final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase()).take(2).join();
    return initials.isNotEmpty ? initials : 'CV';
  }

  static int _scaleSz(int baseHalfPoints, double scale) {
    return (baseHalfPoints * scale).round();
  }

  static Future<Uint8List?> fetchOrDecodePhoto(String photoUrl) async {
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

  // ==============================================================================
  // ASSET RENDERING (Canvas Vector Icons, Themed Watermarks, Avatar Badges)
  // ==============================================================================

  static Future<Uint8List> renderThemedWatermarkPng({
    required String pattern,
    required Color backgroundColor,
    required double opacity,
    required double density,
    required double randomness,
    required double width,
    required double height,
    double borderRadius = 0.0,
    double pixelRatio = 2.0,
    String customWatermarkUrl = '',
  }) async {
    final bytes = await WatermarkPainter.renderWatermarkPng(
      pattern: pattern,
      opacity: opacity,
      density: density,
      randomness: randomness,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      customWatermarkUrl: customWatermarkUrl,
      pixelRatio: pixelRatio,
    );
    return bytes ?? Uint8List(0);
  }

  static Future<Uint8List> renderCanvasContactIconPng(String type, Color cutoutColor, [double size = 48.0]) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    final s = size / 24.0;
    canvas.scale(s, s);

    final whiteFill = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final whiteStroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final cutoutFill = Paint()..color = cutoutColor..style = PaintingStyle.fill;

    switch (type) {
      case 'phone':
        final p = Path();
        p.moveTo(6.62, 10.79);
        p.cubicTo(8.06, 13.62, 10.38, 15.93, 13.21, 17.38);
        p.lineTo(15.41, 15.18);
        p.cubicTo(15.68, 14.91, 16.08, 14.82, 16.43, 14.94);
        p.cubicTo(17.55, 15.31, 18.76, 15.51, 20.0, 15.51);
        p.cubicTo(20.55, 15.51, 21.0, 15.96, 21.0, 16.51);
        p.lineTo(21.0, 20.0);
        p.cubicTo(21.0, 20.55, 20.55, 21.0, 20.0, 21.0);
        p.cubicTo(10.61, 21.0, 3.0, 13.39, 3.0, 4.0);
        p.cubicTo(3.0, 3.45, 3.45, 3.0, 4.0, 3.0);
        p.lineTo(7.5, 3.0);
        p.cubicTo(8.05, 3.0, 8.5, 3.45, 8.5, 4.0);
        p.cubicTo(8.5, 5.25, 8.7, 6.45, 9.07, 7.57);
        p.cubicTo(9.18, 7.92, 9.1, 8.31, 8.82, 8.59);
        p.close();
        canvas.drawPath(p, whiteFill);
        break;
      case 'email':
        final rrect = RRect.fromRectAndRadius(const Rect.fromLTWH(2.5, 4.5, 19, 14.5), const Radius.circular(2.5));
        canvas.drawRRect(rrect, whiteFill);
        final flap = Path()
          ..moveTo(3.5, 6.0)
          ..lineTo(12.0, 12.5)
          ..lineTo(20.5, 6.0);
        canvas.drawPath(flap, Paint()..color = cutoutColor..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round);
        break;
      case 'location':
        final p = Path();
        p.moveTo(12, 2.5);
        p.cubicTo(8.4, 2.5, 5.5, 5.4, 5.5, 9.0);
        p.cubicTo(5.5, 14.2, 12, 21.5, 12, 21.5);
        p.cubicTo(12, 21.5, 18.5, 14.2, 18.5, 9.0);
        p.cubicTo(18.5, 5.4, 15.6, 2.5, 12, 2.5);
        p.close();
        canvas.drawPath(p, whiteFill);
        canvas.drawCircle(const Offset(12, 9), 2.8, cutoutFill);
        break;
      case 'clock':
        canvas.drawCircle(const Offset(12, 12), 8.5, whiteStroke);
        final hands = Path()
          ..moveTo(12, 7.5)
          ..lineTo(12, 12)
          ..lineTo(15.5, 14);
        canvas.drawPath(hands, whiteStroke);
        break;
      case 'car':
        final p = Path();
        p.moveTo(4.5, 11.5);
        p.lineTo(6.5, 6.5);
        p.lineTo(17.5, 6.5);
        p.lineTo(19.5, 11.5);
        p.lineTo(21.0, 13.0);
        p.lineTo(21.0, 16.5);
        p.lineTo(19.5, 16.5);
        p.lineTo(19.5, 15.5);
        p.lineTo(4.5, 15.5);
        p.lineTo(4.5, 16.5);
        p.lineTo(3.0, 16.5);
        p.lineTo(3.0, 13.0);
        p.close();
        canvas.drawPath(p, whiteFill);
        canvas.drawCircle(const Offset(6.8, 16.5), 2.2, whiteFill);
        canvas.drawCircle(const Offset(17.2, 16.5), 2.2, whiteFill);
        canvas.drawCircle(const Offset(5.5, 13.5), 1.0, cutoutFill);
        canvas.drawCircle(const Offset(18.5, 13.5), 1.0, cutoutFill);
        break;
    }

    final pic = recorder.endRecording();
    final outImg = await pic.toImage(size.round(), size.round());
    final byteData = await outImg.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<PillBadgeAsset> renderPillBadgePng({
    required String text,
    required Color accentColor,
    double height = 22.0,
    String fontFamily = 'Segoe UI',
  }) async {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: accentColor,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final width = (textPainter.width + 24.0).clamp(55.0, 160.0);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width * 2, height * 2));
    canvas.scale(2.0, 2.0);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(height / 2),
    );

    final bgPaint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;
    canvas.drawRRect(rrect, bgPaint);

    final textOffset = Offset(
      (width - textPainter.width) / 2,
      (height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    final pic = recorder.endRecording();
    final outImg = await pic.toImage((width * 2).round(), (height * 2).round());
    final byteData = await outImg.toByteData(format: ui.ImageByteFormat.png);
    return PillBadgeAsset(
      bytes: byteData!.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }

  static Future<Uint8List> renderAvatarBadgePng({
    Uint8List? photoBytes,
    required String initials,
    required Color accentColor,
    required bool isSquare,
    required bool isWhiteBorder,
    double size = 160.0,
    double photoZoom = 1.0,
    double photoPanX = 0.0,
    double photoPanY = 0.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    final center = Offset(size / 2, size / 2);
    final rect = Rect.fromLTWH(4, 4, size - 8, size - 8);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(isSquare ? size * 0.16 : (size - 8) * 0.5));

    if (photoBytes != null && photoBytes.isNotEmpty) {
      try {
        final codec = await ui.instantiateImageCodec(photoBytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        canvas.save();
        canvas.clipRRect(rrect);
        final innerSize = size - 8;
        // Match A4SheetPreview: center at (size/2, size/2), apply pan and zoom with BoxFit.cover
        canvas.translate(center.dx + (photoPanX * innerSize), center.dy + (photoPanY * innerSize));
        canvas.scale(photoZoom.clamp(0.5, 3.0));

        final imgAspect = image.width / image.height;
        double drawW, drawH;
        if (imgAspect > 1.0) {
          drawH = innerSize;
          drawW = innerSize * imgAspect;
        } else {
          drawH = innerSize / imgAspect;
          drawW = innerSize;
        }
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: drawW, height: drawH),
          Paint()
            ..isAntiAlias = true
            ..filterQuality = ui.FilterQuality.high,
        );
        canvas.restore();

        final borderPaint = Paint()
          ..color = isWhiteBorder ? Colors.white : accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..isAntiAlias = true;
        canvas.drawRRect(rrect, borderPaint);

        final pic = recorder.endRecording();
        final outImg = await pic.toImage(size.round(), size.round());
        final byteData = await outImg.toByteData(format: ui.ImageByteFormat.png);
        return byteData!.buffer.asUint8List();
      } catch (_) {}
    }

    // Initials fallback
    final bgPaint = Paint()..color = isWhiteBorder ? Colors.white : const Color(0xFFE2E8F0);
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = isWhiteBorder ? Colors.white : accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..isAntiAlias = true;
    canvas.drawRRect(rrect, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
          color: accentColor,
          fontFamily: 'Segoe UI',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2));
    textPainter.paint(canvas, textOffset);

    final pic = recorder.endRecording();
    final outImg = await pic.toImage(size.round(), size.round());
    final byteData = await outImg.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<DocxAssets> prepareAssets(
    CvProfileModel profile, [
    Uint8List? preloadedPhotoBytes,
  ]) async {
    final accentHex = profile.accentColor.replaceAll('#', '').trim();
    final accentInt = int.tryParse('FF$accentHex', radix: 16) ?? 0xFF00A3C4;
    final accentColor = Color(accentInt);
    final initials = _getInitials(profile);

    final photoBytes = preloadedPhotoBytes ?? await fetchOrDecodePhoto(profile.photoUrl);

    final showWatermark = profile.showWatermark && profile.watermarkPattern != 'none' && profile.watermarkOpacity > 0;
    final pattern = showWatermark ? profile.watermarkPattern : 'none';
    final opacity = showWatermark ? profile.watermarkOpacity : 0.0;
    final density = profile.watermarkDensity.clamp(0.4, 3.0);
    final randomness = profile.watermarkRandomness.clamp(0.0, 1.0);

    // Sidebar: 185pt wide x 806pt high, radius 10pt (matching full printable height of A4)
    final sidebarBgBytes = await renderThemedWatermarkPng(
      pattern: pattern,
      backgroundColor: accentColor,
      opacity: (opacity * 0.95).clamp(0.0, 1.0),
      density: density,
      randomness: randomness,
      customWatermarkUrl: profile.customWatermarkUrl,
      width: 185,
      height: 806,
      borderRadius: 10,
    );

    // Banner: 358pt wide x 48pt high, radius 8pt
    final bannerBgBytes = await renderThemedWatermarkPng(
      pattern: pattern,
      backgroundColor: accentColor,
      opacity: opacity,
      density: density,
      randomness: randomness,
      customWatermarkUrl: profile.customWatermarkUrl,
      width: 358,
      height: 48,
      borderRadius: 8,
    );

    // Section Pill: 358pt wide x 22pt high, radius 11pt
    final pillBgBytes = await renderThemedWatermarkPng(
      pattern: pattern,
      backgroundColor: accentColor,
      opacity: opacity,
      density: density,
      randomness: randomness,
      customWatermarkUrl: profile.customWatermarkUrl,
      width: 358,
      height: 22,
      borderRadius: 11,
    );

    // White Sidebar Pill fallback: 145pt wide x 20pt high, radius 10pt
    final whitePillBytes = await renderThemedWatermarkPng(
      pattern: 'none',
      backgroundColor: Colors.white,
      opacity: 0.0,
      density: 1.0,
      randomness: 0.0,
      width: 145,
      height: 20,
      borderRadius: 10,
    );

    // Subtitle Pill Badges with text centered in true capsule shapes
    final isEn = profile.isEnglishVersion;
    final fontName = profile.fontFamily.trim().isNotEmpty ? profile.fontFamily.trim() : 'Segoe UI';
    final pillContact = await renderPillBadgePng(
      text: isEn ? 'CONTACT DETAILS' : 'DATOS',
      accentColor: accentColor,
      fontFamily: fontName,
    );
    final pillAbout = await renderPillBadgePng(
      text: isEn ? 'ABOUT ME' : 'SOBRE MÍ',
      accentColor: accentColor,
      fontFamily: fontName,
    );
    final pillSkills = await renderPillBadgePng(
      text: isEn ? 'KEY SKILLS' : 'COMPETENCIAS',
      accentColor: accentColor,
      fontFamily: fontName,
    );

    // Photo/Avatar badge
    final isSquare = profile.photoShape == 'square';
    final avatarBadgeBytes = await renderAvatarBadgePng(
      photoBytes: photoBytes,
      initials: initials,
      accentColor: accentColor,
      isSquare: isSquare,
      isWhiteBorder: true,
      size: 160.0,
      photoZoom: profile.photoZoom,
      photoPanX: profile.photoPanX,
      photoPanY: profile.photoPanY,
    );

    // Canvas contact icons
    final iconPhoneBytes = await renderCanvasContactIconPng('phone', accentColor);
    final iconEmailBytes = await renderCanvasContactIconPng('email', accentColor);
    final iconLocationBytes = await renderCanvasContactIconPng('location', accentColor);
    final iconClockBytes = await renderCanvasContactIconPng('clock', accentColor);
    final iconCarBytes = await renderCanvasContactIconPng('car', accentColor);

    return DocxAssets(
      photoBytes: avatarBadgeBytes,
      sidebarBgBytes: sidebarBgBytes,
      bannerBgBytes: bannerBgBytes,
      pillBgBytes: pillBgBytes,
      whitePillBytes: whitePillBytes,
      iconPhoneBytes: iconPhoneBytes,
      iconEmailBytes: iconEmailBytes,
      iconLocationBytes: iconLocationBytes,
      iconClockBytes: iconClockBytes,
      iconCarBytes: iconCarBytes,
      pillContact: pillContact,
      pillAbout: pillAbout,
      pillSkills: pillSkills,
    );
  }

  // ==============================================================================
  // MAIN DOCX GENERATION
  // ==============================================================================

  static Uint8List generateDocxBytes(
    CvProfileModel profile, [
    Uint8List? preloadedPhotoBytes,
    Uint8List? sidebarWatermarkBytes,
    Uint8List? bannerWatermarkBytes,
    DocxAssets? preloadedAssets,
  ]) {
    final archive = Archive();
    final isEn = profile.isEnglishVersion;
    final accentHex = profile.accentColor.replaceAll('#', '').toUpperCase();
    final initials = _getInitials(profile);

    void addXml(String path, String xml) {
      final bytes = utf8.encode(xml);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    final hasAssets = preloadedAssets != null;

    // Resolve media assets
    final Uint8List? sidebarBg = preloadedAssets?.sidebarBgBytes ?? sidebarWatermarkBytes;
    final Uint8List? bannerBg = preloadedAssets?.bannerBgBytes ?? bannerWatermarkBytes;
    final Uint8List? pillBg = preloadedAssets?.pillBgBytes;
    final Uint8List? whitePill = preloadedAssets?.whitePillBytes;
    final Uint8List? photoBytes = preloadedAssets?.photoBytes ?? preloadedPhotoBytes;
    final PillBadgeAsset? pillContact = preloadedAssets?.pillContact;
    final PillBadgeAsset? pillAbout = preloadedAssets?.pillAbout;
    final PillBadgeAsset? pillSkills = preloadedAssets?.pillSkills;

    if (sidebarBg != null && sidebarBg.isNotEmpty) {
      archive.addFile(ArchiveFile('word/media/sidebar_bg.png', sidebarBg.length, sidebarBg));
      // Backward compatibility for legacy tests
      archive.addFile(ArchiveFile('word/media/watermark_sidebar.png', sidebarBg.length, sidebarBg));
    }
    if (bannerBg != null && bannerBg.isNotEmpty) {
      archive.addFile(ArchiveFile('word/media/banner_bg.png', bannerBg.length, bannerBg));
      // Backward compatibility for legacy tests
      archive.addFile(ArchiveFile('word/media/watermark_banner.png', bannerBg.length, bannerBg));
    }
    if (pillBg != null && pillBg.isNotEmpty) {
      archive.addFile(ArchiveFile('word/media/pill_bg.png', pillBg.length, pillBg));
    }
    if (whitePill != null && whitePill.isNotEmpty) {
      archive.addFile(ArchiveFile('word/media/white_pill.png', whitePill.length, whitePill));
    }
    if (photoBytes != null && photoBytes.isNotEmpty) {
      archive.addFile(ArchiveFile('word/media/photo.png', photoBytes.length, photoBytes));
      archive.addFile(ArchiveFile('word/media/image1.png', photoBytes.length, photoBytes));
    }
    if (pillContact != null) {
      archive.addFile(ArchiveFile('word/media/pill_contact.png', pillContact.bytes.length, pillContact.bytes));
    }
    if (pillAbout != null) {
      archive.addFile(ArchiveFile('word/media/pill_about.png', pillAbout.bytes.length, pillAbout.bytes));
    }
    if (pillSkills != null) {
      archive.addFile(ArchiveFile('word/media/pill_skills.png', pillSkills.bytes.length, pillSkills.bytes));
    }

    if (hasAssets) {
      if (preloadedAssets.iconPhoneBytes != null) {
        archive.addFile(ArchiveFile('word/media/icon_phone.png', preloadedAssets.iconPhoneBytes!.length, preloadedAssets.iconPhoneBytes!));
      }
      if (preloadedAssets.iconEmailBytes != null) {
        archive.addFile(ArchiveFile('word/media/icon_email.png', preloadedAssets.iconEmailBytes!.length, preloadedAssets.iconEmailBytes!));
      }
      if (preloadedAssets.iconLocationBytes != null) {
        archive.addFile(ArchiveFile('word/media/icon_location.png', preloadedAssets.iconLocationBytes!.length, preloadedAssets.iconLocationBytes!));
      }
      if (preloadedAssets.iconClockBytes != null) {
        archive.addFile(ArchiveFile('word/media/icon_clock.png', preloadedAssets.iconClockBytes!.length, preloadedAssets.iconClockBytes!));
      }
      if (preloadedAssets.iconCarBytes != null) {
        archive.addFile(ArchiveFile('word/media/icon_car.png', preloadedAssets.iconCarBytes!.length, preloadedAssets.iconCarBytes!));
      }
    }

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/>
</Types>''';
    addXml('[Content_Types].xml', contentTypesXml);

    // 2. _rels/.rels
    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    addXml('_rels/.rels', rootRelsXml);

    // 3. word/_rels/document.xml.rels
    final docRelsXml = StringBuffer();
    docRelsXml.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rIdFontTable" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>''');
    if (sidebarBg != null && sidebarBg.isNotEmpty) {
      docRelsXml.write('\n  <Relationship Id="rIdSidebarBg" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/sidebar_bg.png"/>');
    }
    if (photoBytes != null && photoBytes.isNotEmpty) {
      docRelsXml.write('\n  <Relationship Id="rIdPhoto" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/photo.png"/>');
    }
    if (bannerBg != null && bannerBg.isNotEmpty) {
      docRelsXml.write('\n  <Relationship Id="rIdBannerBg" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/banner_bg.png"/>');
      docRelsXml.write('\n  <Relationship Id="rIdWatermarkBanner" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/watermark_banner.png"/>');
    }
    if (pillBg != null && pillBg.isNotEmpty) {
      docRelsXml.write('\n  <Relationship Id="rIdPillBg" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/pill_bg.png"/>');
    }
    if (whitePill != null && whitePill.isNotEmpty) {
      docRelsXml.write('\n  <Relationship Id="rIdWhitePill" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/white_pill.png"/>');
    }
    if (pillContact != null) {
      docRelsXml.write('\n  <Relationship Id="rIdPillContact" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/pill_contact.png"/>');
    }
    if (pillAbout != null) {
      docRelsXml.write('\n  <Relationship Id="rIdPillAbout" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/pill_about.png"/>');
    }
    if (pillSkills != null) {
      docRelsXml.write('\n  <Relationship Id="rIdPillSkills" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/pill_skills.png"/>');
    }
    if (hasAssets) {
      docRelsXml.write('\n  <Relationship Id="rIdIconPhone" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/icon_phone.png"/>');
      docRelsXml.write('\n  <Relationship Id="rIdIconEmail" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/icon_email.png"/>');
      docRelsXml.write('\n  <Relationship Id="rIdIconLocation" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/icon_location.png"/>');
      docRelsXml.write('\n  <Relationship Id="rIdIconClock" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/icon_clock.png"/>');
      docRelsXml.write('\n  <Relationship Id="rIdIconCar" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/icon_car.png"/>');
    }
    docRelsXml.write('\n</Relationships>');
    addXml('word/_rels/document.xml.rels', docRelsXml.toString());

    // 4. word/fontTable.xml (Define selected font family + clean sans-serif/serif fallbacks)
    final rawFamily = profile.fontFamily.trim();
    final docFontFamily = rawFamily.isNotEmpty ? rawFamily : 'Inter';

    String altFontName = 'Segoe UI';
    String fontFamilyType = 'swiss';
    if (docFontFamily == 'Merriweather' || docFontFamily == 'Lora') {
      altFontName = 'Georgia';
      fontFamilyType = 'roman';
    } else if (docFontFamily == 'Fira Code' || docFontFamily.toLowerCase().contains('mono')) {
      altFontName = 'Consolas';
      fontFamilyType = 'modern';
    } else if (docFontFamily == 'Roboto') {
      altFontName = 'Arial';
      fontFamilyType = 'swiss';
    } else if (docFontFamily == 'Outfit' || docFontFamily == 'Montserrat') {
      altFontName = 'Century Gothic';
      fontFamilyType = 'swiss';
    }

    final fontTag = '<w:rFonts w:ascii="$docFontFamily" w:hAnsi="$docFontFamily" w:cs="$docFontFamily"/>';

    final fontTableXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:font w:name="$docFontFamily">
    <w:altName w:val="$altFontName"/>
    <w:family w:val="$fontFamilyType"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Inter">
    <w:altName w:val="Segoe UI"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Outfit">
    <w:altName w:val="Century Gothic"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Roboto">
    <w:altName w:val="Arial"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Montserrat">
    <w:altName w:val="Century Gothic"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Poppins">
    <w:altName w:val="Segoe UI"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Raleway">
    <w:altName w:val="Segoe UI"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Merriweather">
    <w:altName w:val="Georgia"/>
    <w:family w:val="roman"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Lora">
    <w:altName w:val="Georgia"/>
    <w:family w:val="roman"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Fira Code">
    <w:altName w:val="Consolas"/>
    <w:family w:val="modern"/>
    <w:pitch w:val="fixed"/>
  </w:font>
  <w:font w:name="Segoe UI">
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Arial">
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Century Gothic">
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Calibri">
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Georgia">
    <w:family w:val="roman"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Consolas">
    <w:family w:val="modern"/>
    <w:pitch w:val="fixed"/>
  </w:font>
  <w:font w:name="Segoe UI Symbol">
    <w:family w:val="auto"/>
    <w:pitch w:val="variable"/>
  </w:font>
</w:fonts>''';
    addXml('word/fontTable.xml', fontTableXml);

    // 5. word/styles.xml (Explicit font inheritance across body & tables to eliminate Times New Roman)
    final baseSz = _scaleSz(17, profile.fontSizeScale);
    final trackingTwips = (profile.fontSpacing * 20).round();
    final lineSpacingDxa = (220 * profile.lineSpacing).round();

    final stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rFonts w:ascii="$docFontFamily" w:hAnsi="$docFontFamily" w:eastAsia="$docFontFamily" w:cs="$docFontFamily"/>
      <w:sz w:val="$baseSz"/>
      <w:spacing w:val="$trackingTwips"/>
      <w:color w:val="1E293B"/>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:spacing w:line="$lineSpacingDxa" w:lineRule="auto"/>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:rPr>
      <w:rFonts w:ascii="$docFontFamily" w:hAnsi="$docFontFamily" w:eastAsia="$docFontFamily" w:cs="$docFontFamily"/>
      <w:sz w:val="$baseSz"/>
      <w:color w:val="1E293B"/>
    </w:rPr>
  </w:style>
  <w:style w:type="table" w:default="1" w:styleId="TableNormal">
    <w:name w:val="Normal Table"/>
    <w:uiPriority w:val="99"/>
    <w:semiHidden/>
    <w:unhideWhenUsed/>
    <w:rPr>
      <w:rFonts w:ascii="$docFontFamily" w:hAnsi="$docFontFamily" w:eastAsia="$docFontFamily" w:cs="$docFontFamily"/>
      <w:sz w:val="$baseSz"/>
      <w:color w:val="1E293B"/>
    </w:rPr>
  </w:style>
</w:styles>''';
    addXml('word/styles.xml', stylesXml);

    // 6. word/document.xml
    final docXml = StringBuffer();
    docXml.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
            xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
''');

    // Build layout based on active template
    switch (profile.template) {
      case 'modern_header':
        _buildModernHeaderDocx(docXml, profile, accentHex, isEn, initials, photoBytes != null, bannerBg != null, fontTag: fontTag);
        break;
      case 'minimalist':
        _buildMinimalistDocx(docXml, profile, accentHex, isEn, initials, photoBytes != null, fontTag: fontTag);
        break;
      case 'tech_cards':
        _buildTechCardsDocx(docXml, profile, accentHex, isEn, initials, photoBytes != null, bannerBg != null, fontTag: fontTag);
        break;
      case 'sidebar_dark':
      default:
        _buildSidebarDarkDocx(
          docXml,
          profile,
          accentHex,
          isEn,
          initials,
          hasPhoto: photoBytes != null,
          hasAssets: hasAssets,
          hasPillBg: pillBg != null,
          hasBannerBg: bannerBg != null,
          hasWhitePill: whitePill != null,
          hasSidebarBg: sidebarBg != null && sidebarBg.isNotEmpty,
          pillContact: pillContact,
          pillAbout: pillAbout,
          pillSkills: pillSkills,
          fontTag: fontTag,
        );
        break;
    }

    // Page setup: A4 format (11906 x 16838 dxa) with 360 dxa (18pt) margins for full-bleed single-page layout
    docXml.write('''
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="360" w:right="360" w:bottom="360" w:left="360" w:header="0" w:footer="0"/>
    </w:sectPr>
  </w:body>
</w:document>''');

    addXml('word/document.xml', docXml.toString());

    final zipEncoder = ZipEncoder();
    final bytes = zipEncoder.encode(archive);
    return Uint8List.fromList(bytes);
  }

  // ==============================================================================
  // 1. DOCX: SIDEBAR DARK (Table with Full-Height Sidebar & Circuit Watermark)
  // ==============================================================================
  static void _buildSidebarDarkDocx(
    StringBuffer docXml,
    CvProfileModel profile,
    String accentHex,
    bool isEn,
    String initials, {
    required bool hasPhoto,
    required bool hasAssets,
    required bool hasPillBg,
    required bool hasBannerBg,
    required bool hasWhitePill,
    required bool hasSidebarBg,
    PillBadgeAsset? pillContact,
    PillBadgeAsset? pillAbout,
    PillBadgeAsset? pillSkills,
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  }) {
    final col1W = hasAssets ? 3700 : 3300;
    final col2W = hasAssets ? 7486 : 7166;
    final tblW = col1W + col2W;

    docXml.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="$tblW" w:type="dxa"/>
        <w:tblLayout w:type="fixed"/>
        <w:tblCellMar>
          <w:top w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/>
          <w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/>
        </w:tblCellMar>
        <w:tblBorders>
          <w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/>
          <w:insideH w:val="none"/><w:insideV w:val="none"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="$col1W"/>
        <w:gridCol w:w="$col2W"/>
      </w:tblGrid>
      <w:tr>
        <!-- LEFT COLUMN: SIDEBAR -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="$col1W" w:type="dxa"/>
            ${hasSidebarBg ? '<w:shd w:val="none"/>' : '<w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>'}
            <w:tcMar>
              <w:top w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/>
              <w:left w:w="240" w:type="dxa"/><w:right w:w="240" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
''');

    // Sidebar Background Watermark inside Document Body (reaching full printable height to bottom margin)
    if (hasSidebarBg) {
      docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:before="0" w:after="0" w:line="1" w:lineRule="exact"/></w:pPr>
            <w:r>
              <w:drawing>
                <wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="0" behindDoc="1" locked="1" layoutInCell="0" allowOverlap="1">
                  <wp:simplePos x="0" y="0"/>
                  <wp:positionH relativeFrom="margin"><wp:posOffset>0</wp:posOffset></wp:positionH>
                  <wp:positionV relativeFrom="margin"><wp:posOffset>0</wp:posOffset></wp:positionV>
                  <wp:extent cx="2349500" cy="10234930"/>
                  <wp:effectExtent l="0" t="0" r="0" b="0"/>
                  <wp:wrapNone/>
                  <wp:docPr id="1001" name="SidebarBackground"/><wp:cNvGraphicFramePr/>
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:pic>
                        <pic:nvPicPr><pic:cNvPr id="1001" name="SidebarBackground"/><pic:cNvPicPr/></pic:nvPicPr>
                        <pic:blipFill><a:blip r:embed="rIdSidebarBg"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="2349500" cy="10234930"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:anchor>
              </w:drawing>
            </w:r>
          </w:p>''');
    }

    // Photo / Initials Badge (Centered inside sidebar with balanced top padding)
    if (hasAssets && hasPhoto) {
      docXml.write('''
          <w:p>
            <w:pPr><w:jc w:val="center"/><w:spacing w:before="160" w:after="60"/></w:pPr>
            <w:r>
              <w:drawing>
                <wp:inline distT="0" distB="0" distL="0" distR="0">
                  <wp:extent cx="1016000" cy="1016000"/>
                  <wp:docPr id="1009" name="Photo"/><wp:cNvGraphicFramePr/>
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:pic>
                        <pic:nvPicPr><pic:cNvPr id="1009" name="Photo"/><pic:cNvPicPr/></pic:nvPicPr>
                        <pic:blipFill><a:blip r:embed="rIdPhoto"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1016000" cy="1016000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:inline>
              </w:drawing>
            </w:r>
          </w:p>''');
    } else {
      _addDocxPhotoOrInitials(docXml, hasPhoto, initials, isWhite: true, profile: profile, sizeDxa: 1016000, jc: 'center', fontTag: fontTag);
    }

    // Datos de Contacto
    _addSidebarPill(docXml, isEn ? 'CONTACT DETAILS' : 'DATOS', accentHex, profile: profile, badge: pillContact, relId: 'rIdPillContact', hasWhitePill: hasWhitePill, fontTag: fontTag);
    if (hasAssets) {
      if (profile.phone.isNotEmpty) _addSidebarContactItem(docXml, 'rIdIconPhone', profile.phone, fontTag);
      if (profile.email.isNotEmpty) _addSidebarContactItem(docXml, 'rIdIconEmail', profile.email, fontTag);
      if (profile.location.isNotEmpty) _addSidebarContactItem(docXml, 'rIdIconLocation', profile.location, fontTag);
      if (profile.availability.isNotEmpty) _addSidebarContactItem(docXml, 'rIdIconClock', profile.availability, fontTag);
      if (profile.drivingLicense.isNotEmpty) _addSidebarContactItem(docXml, 'rIdIconCar', profile.drivingLicense, fontTag);
    } else {
      if (profile.phone.isNotEmpty) _addWhiteSidebarContactRow(docXml, '📞', profile.phone, fontTag);
      if (profile.email.isNotEmpty) _addWhiteSidebarContactRow(docXml, '✉', profile.email, fontTag);
      if (profile.location.isNotEmpty) _addWhiteSidebarContactRow(docXml, '📍', profile.location, fontTag);
      if (profile.availability.isNotEmpty) _addWhiteSidebarContactRow(docXml, '⏱', profile.availability, fontTag);
      if (profile.drivingLicense.isNotEmpty) _addWhiteSidebarContactRow(docXml, '🚗', profile.drivingLicense, fontTag);
    }

    // Sobre Mí
    if (profile.summary.trim().isNotEmpty) {
      docXml.write('<w:p><w:pPr><w:spacing w:before="0" w:after="160"/></w:pPr></w:p>');
      _addSidebarPill(docXml, isEn ? 'ABOUT ME' : 'SOBRE MÍ', accentHex, profile: profile, badge: pillAbout, relId: 'rIdPillAbout', hasWhitePill: hasWhitePill, fontTag: fontTag);
      final summarySz = _scaleSz(14, profile.fontSizeScale);
      docXml.write('''
          <w:p>
            <w:pPr>
              <w:spacing w:before="0" w:after="50" w:line="220" w:lineRule="auto"/>
              <w:jc w:val="both"/>
              <w:ind w:left="100" w:right="100"/>
            </w:pPr>
            <w:r><w:rPr>$fontTag<w:sz w:val="$summarySz"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>${_escapeXml(profile.summary)}</w:t>
            </w:r>
          </w:p>''');
    }

    // Competencias
    final skillsList = _getSkillsList(profile);
    if (skillsList.isNotEmpty) {
      docXml.write('<w:p><w:pPr><w:spacing w:before="0" w:after="160"/></w:pPr></w:p>');
      _addSidebarPill(docXml, isEn ? 'KEY SKILLS' : 'COMPETENCIAS', accentHex, profile: profile, badge: pillSkills, relId: 'rIdPillSkills', hasWhitePill: hasWhitePill, fontTag: fontTag);
      for (final item in skillsList) {
        final dots = _formatRatingDots(item.level, profile.skillRatingStyle);
        final skillSz = _scaleSz(13, profile.fontSizeScale);
        final descSz = _scaleSz(12, profile.fontSizeScale);
        docXml.write('''
          <w:p>
            <w:pPr>
              <w:tabs><w:tab w:val="right" w:pos="3020"/></w:tabs>
              <w:spacing w:before="45" w:after="5"/>
              <w:ind w:left="100" w:right="100"/>
            </w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="$skillSz"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(item.name.toUpperCase())}</w:t>
            </w:r>
            <w:r><w:tab/></w:r>
            <w:r>
              <w:rPr><w:sz w:val="$skillSz"/><w:color w:val="F59E0B"/><w:rFonts w:ascii="Segoe UI Symbol" w:hAnsi="Segoe UI Symbol"/></w:rPr>
              <w:t>$dots</w:t>
            </w:r>
          </w:p>''');
        if (item.description.isNotEmpty) {
          docXml.write('''
          <w:p>
            <w:pPr>
              <w:ind w:left="100" w:right="100"/>
              <w:spacing w:before="0" w:after="40" w:line="200" w:lineRule="auto"/>
            </w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:sz w:val="$descSz"/><w:color w:val="E2E8F0"/></w:rPr>
              <w:t>${_escapeXml(item.description)}</w:t>
            </w:r>
          </w:p>''');
        }
      }
    }

    docXml.write('''
        </w:tc>

        <!-- RIGHT COLUMN: MAIN CONTENT -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="$col2W" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="0" w:type="dxa"/><w:bottom w:w="260" w:type="dxa"/>
              <w:left w:w="320" w:type="dxa"/><w:right w:w="120" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
''');

    // Header Banner Box (Full circuit watermark with rounded corners & vertically centered text)
    final nameSz = _scaleSz(28, profile.fontSizeScale);
    final jobSz = _scaleSz(17, profile.fontSizeScale);
    final hasJob = profile.jobTitle.trim().isNotEmpty;

    if (hasBannerBg) {
      final bannerVOffset = hasJob ? -101600 : -177800;
      final nameBefore = hasJob ? 160 : 280;
      final nameAfter = hasJob ? 20 : 280;
      docXml.write('''
          <w:tbl>
            <w:tblPr>
              <w:tblW w:w="7160" w:type="dxa"/>
              <w:tblLayout w:type="fixed"/>
              <w:tblCellMar>
                <w:top w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/>
                <w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/>
              </w:tblCellMar>
              <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/></w:tblBorders>
            </w:tblPr>
            <w:tblGrid><w:gridCol w:w="7160"/></w:tblGrid>
            <w:tr>
              <w:trPr><w:trHeight w:val="960" w:hRule="exact"/></w:trPr>
              <w:tc>
                <w:tcPr>
                  <w:tcW w:w="7160" w:type="dxa"/>
                  <w:shd w:val="none"/>
                  <w:tcMar>
                    <w:top w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/>
                    <w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/>
                  </w:tcMar>
                  <w:vAlign w:val="top"/>
                </w:tcPr>
                <w:p>
                  <w:pPr><w:jc w:val="center"/><w:spacing w:before="$nameBefore" w:after="$nameAfter" w:line="280" w:lineRule="exact"/></w:pPr>
                  <w:r>
                    <w:drawing>
                      <wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="0" behindDoc="1" locked="1" layoutInCell="1" allowOverlap="1">
                        <wp:simplePos x="0" y="0"/>
                        <wp:positionH relativeFrom="column"><wp:posOffset>0</wp:posOffset></wp:positionH>
                        <wp:positionV relativeFrom="paragraph"><wp:posOffset>$bannerVOffset</wp:posOffset></wp:positionV>
                        <wp:extent cx="4546600" cy="609600"/>
                        <wp:effectExtent l="0" t="0" r="0" b="0"/>
                        <wp:wrapNone/>
                        <wp:docPr id="1005" name="HeaderBanner"/><wp:cNvGraphicFramePr/>
                        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                            <pic:pic>
                              <pic:nvPicPr><pic:cNvPr id="1005" name="HeaderBanner"/><pic:cNvPicPr/></pic:nvPicPr>
                              <pic:blipFill><a:blip r:embed="rIdBannerBg"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                              <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="4546600" cy="609600"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                            </pic:pic>
                          </a:graphicData>
                        </a:graphic>
                      </wp:anchor>
                    </w:drawing>
                  </w:r>
                  <w:r>
                    <w:rPr>$fontTag<w:b/><w:sz w:val="$nameSz"/><w:color w:val="FFFFFF"/><w:spacing w:val="20"/></w:rPr>
                    <w:t>${_escapeXml(profile.fullName.isNotEmpty ? profile.fullName.toUpperCase() : 'NOMBRE Y APELLIDOS')}</w:t>
                  </w:r>
                </w:p>''');
      if (profile.jobTitle.isNotEmpty) {
        docXml.write('''
                <w:p>
                  <w:pPr><w:jc w:val="center"/><w:spacing w:before="20" w:after="160" w:line="220" w:lineRule="exact"/></w:pPr>
                  <w:r>
                    <w:rPr>$fontTag<w:b/><w:sz w:val="$jobSz"/><w:color w:val="FFFFFF"/><w:spacing w:val="16"/></w:rPr>
                    <w:t>${_escapeXml(profile.jobTitle.toUpperCase())}</w:t>
                  </w:r>
                </w:p>''');
      }
      docXml.write('''
              </w:tc>
            </w:tr>
          </w:tbl>
          <w:p><w:pPr><w:spacing w:before="0" w:after="160"/></w:pPr></w:p>''');
    } else {
      _addBoxedHeaderBannerFallback(docXml, profile, accentHex, nameSz, jobSz, fontTag);
    }

    // Work Experience Section
    _addSectionHeaderPill(docXml, isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL', accentHex, hasPillBg: hasPillBg, profile: profile, fontTag: fontTag);
    if (profile.experiences.isEmpty) {
      final msg = isEn ? 'No work experience records yet.' : 'Sin experiencia laboral registrada aún.';
      docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:before="60" w:after="100"/></w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:i/><w:sz w:val="16"/><w:color w:val="94A3B8"/></w:rPr>
              <w:t xml:space="preserve">$msg</w:t>
            </w:r>
          </w:p>''');
    } else {
      for (final exp in profile.experiences) {
        _addDocxExperience(docXml, exp, accentHex, fontTag);
      }
    }

    // Breathing space between Experience and Education sections
    docXml.write('<w:p><w:pPr><w:spacing w:before="0" w:after="260"/></w:pPr></w:p>');

    // Education Section
    _addSectionHeaderPill(docXml, isEn ? 'EDUCATION & CERTIFICATIONS' : 'FORMACIÓN Y CERTIFICACIONES', accentHex, hasPillBg: hasPillBg, profile: profile, fontTag: fontTag);
    if (profile.educations.isEmpty) {
      final msg = isEn ? 'No education records yet.' : 'Sin formación registrada aún.';
      docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:before="60" w:after="100"/></w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:i/><w:sz w:val="16"/><w:color w:val="94A3B8"/></w:rPr>
              <w:t xml:space="preserve">$msg</w:t>
            </w:r>
          </w:p>''');
    } else {
      for (final edu in profile.educations) {
        _addDocxEducation(docXml, edu, accentHex, fontTag);
      }
    }

    docXml.write('''
        </w:tc>
      </w:tr>
    </w:tbl>''');
  }

  // ==============================================================================
  // 2. DOCX: MODERN HEADER (Full Width Header Row + 2 Columns Below)
  // ==============================================================================
  static void _buildModernHeaderDocx(
    StringBuffer docXml,
    CvProfileModel profile,
    String accentHex,
    bool isEn,
    String initials,
    bool hasPhoto,
    bool hasBannerWatermark, {
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  }) {
    docXml.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="11186" w:type="dxa"/>
        <w:tblLayout w:type="fixed"/>
        <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/></w:tblBorders>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="2400"/>
        <w:gridCol w:w="8786"/>
      </w:tblGrid>
      <w:tr>
        <!-- PHOTO CELL IN HEADER -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="2400" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
            <w:tcMar><w:top w:w="200" w:type="dxa"/><w:bottom w:w="200" w:type="dxa"/><w:left w:w="200" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar>
          </w:tcPr>
''');

    _addDocxPhotoOrInitials(docXml, hasPhoto, initials, isWhite: true, profile: profile, sizeDxa: 960000, jc: 'center', fontTag: fontTag);

    docXml.write('''
        </w:tc>
        <!-- TEXT CELL IN HEADER -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="8786" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
            <w:tcMar><w:top w:w="200" w:type="dxa"/><w:bottom w:w="200" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="240" w:type="dxa"/></w:tcMar>
          </w:tcPr>
          <w:p>
            <w:pPr><w:spacing w:after="40"/></w:pPr>
            <w:r><w:rPr>$fontTag<w:b/><w:sz w:val="42"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>${_escapeXml(profile.fullName)}</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:pPr><w:spacing w:after="80"/></w:pPr>
            <w:r><w:rPr>$fontTag<w:b/><w:sz w:val="22"/><w:color w:val="F1F5F9"/></w:rPr>
              <w:t>${_escapeXml(profile.jobTitle.toUpperCase())}</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:r><w:rPr>$fontTag<w:sz w:val="17"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>${_escapeXml([profile.phone, profile.email, profile.location, profile.availability].where((s) => s.isNotEmpty).join('   |   '))}</w:t>
            </w:r>
          </w:p>
        </w:tc>
      </w:tr>
    </w:tbl>

    <!-- 2 COLUMNS BELOW -->
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="11186" w:type="dxa"/>
        <w:tblLayout w:type="fixed"/>
        <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/></w:tblBorders>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="6400"/>
        <w:gridCol w:w="4786"/>
      </w:tblGrid>
      <w:tr>
        <!-- LEFT SUB-COLUMN: Experience & Profile -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="6400" w:type="dxa"/>
            <w:tcMar><w:top w:w="200" w:type="dxa"/><w:right w:w="200" w:type="dxa"/></w:tcMar>
          </w:tcPr>
''');

    _addSectionHeader(docXml, isEn ? 'PROFESSIONAL PROFILE' : 'PERFIL PROFESIONAL', accentHex, profile, fontTag);
    docXml.write('''
          <w:p><w:pPr><w:spacing w:after="120"/></w:pPr><w:r><w:rPr>$fontTag<w:sz w:val="17"/><w:color w:val="1E293B"/></w:rPr><w:t>${_escapeXml(profile.summary)}</w:t></w:r></w:p>''');

    _addSectionHeader(docXml, isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL', accentHex, profile, fontTag);
    for (final exp in profile.experiences) {
      _addDocxExperience(docXml, exp, accentHex, fontTag);
    }

    docXml.write('''
        </w:tc>
        <!-- RIGHT SUB-COLUMN: Skills & Education -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="4786" w:type="dxa"/>
            <w:tcMar><w:top w:w="200" w:type="dxa"/><w:left w:w="200" w:type="dxa"/></w:tcMar>
          </w:tcPr>
''');

    _addSectionHeader(docXml, isEn ? 'KEY SKILLS' : 'COMPETENCIAS CLAVE', accentHex, profile, fontTag);
    for (final item in _getSkillsList(profile)) {
      final dots = _formatRatingDots(item.level, profile.skillRatingStyle);
      docXml.write('''
          <w:p><w:pPr><w:spacing w:after="30"/></w:pPr>
            <w:r><w:rPr>$fontTag<w:b/><w:sz w:val="16"/><w:color w:val="$accentHex"/></w:rPr><w:t>✔ ${_escapeXml(item.name)}  </w:t></w:r>
            <w:r><w:rPr><w:sz w:val="14"/><w:color w:val="F59E0B"/><w:rFonts w:ascii="Segoe UI Symbol" w:hAnsi="Segoe UI Symbol"/></w:rPr><w:t>$dots</w:t></w:r>
          </w:p>''');
    }

    _addSectionHeader(docXml, isEn ? 'EDUCATION' : 'FORMACIÓN ACADÉMICA', accentHex, profile, fontTag);
    for (final edu in profile.educations) {
      _addDocxEducation(docXml, edu, accentHex, fontTag);
    }

    docXml.write('''
        </w:tc>
      </w:tr>
    </w:tbl>''');
  }

  // ==============================================================================
  // 3. DOCX: MINIMALIST (Centered 1 Column)
  // ==============================================================================
  static void _buildMinimalistDocx(
    StringBuffer docXml,
    CvProfileModel profile,
    String accentHex,
    bool isEn,
    String initials,
    bool hasPhoto, {
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  }) {
    _addDocxPhotoOrInitials(docXml, hasPhoto, initials, isWhite: false, profile: profile, sizeDxa: 1150000, jc: 'center', fontTag: fontTag);

    docXml.write('''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:before="60" w:after="40"/></w:pPr>
      <w:r><w:rPr>$fontTag<w:b/><w:sz w:val="46"/><w:color w:val="0F172A"/></w:rPr>
        <w:t>${_escapeXml(profile.fullName)}</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr>$fontTag<w:b/><w:sz w:val="22"/><w:color w:val="$accentHex"/></w:rPr>
        <w:t>${_escapeXml(profile.jobTitle.toUpperCase())}</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="140"/></w:pPr>
      <w:r><w:rPr>$fontTag<w:sz w:val="18"/><w:color w:val="64748B"/></w:rPr>
        <w:t>${_escapeXml([profile.phone, profile.email, profile.location, profile.drivingLicense].where((s) => s.isNotEmpty).join('   •   '))}</w:t>
      </w:r>
    </w:p>''');

    _addHorizontalRule(docXml, accentHex);

    _addSectionHeader(docXml, isEn ? 'PROFILE' : 'PERFIL PROFESIONAL', accentHex, profile, fontTag);
    docXml.write('''
    <w:p><w:pPr><w:spacing w:after="140"/></w:pPr><w:r><w:rPr>$fontTag<w:sz w:val="17"/><w:color w:val="1E293B"/></w:rPr><w:t>${_escapeXml(profile.summary)}</w:t></w:r></w:p>''');

    _addSectionHeader(docXml, isEn ? 'EXPERIENCE' : 'EXPERIENCIA LABORAL', accentHex, profile, fontTag);
    for (final exp in profile.experiences) {
      _addDocxExperience(docXml, exp, accentHex, fontTag);
    }

    _addSectionHeader(docXml, isEn ? 'EDUCATION' : 'FORMACIÓN ACADÉMICA', accentHex, profile, fontTag);
    for (final edu in profile.educations) {
      _addDocxEducation(docXml, edu, accentHex, fontTag);
    }

    _addSectionHeader(docXml, isEn ? 'SKILLS & COMPETENCIES' : 'HABILIDADES Y COMPETENCIAS', accentHex, profile, fontTag);
    for (final s in _getSkillsList(profile)) {
      final dots = _formatRatingDots(s.level, profile.skillRatingStyle);
      docXml.write('''
    <w:p><w:pPr><w:spacing w:after="30"/></w:pPr>
      <w:r><w:rPr>$fontTag<w:sz w:val="16"/><w:color w:val="0F172A"/></w:rPr><w:t>• ${_escapeXml(s.name)}  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="14"/><w:color w:val="F59E0B"/><w:rFonts w:ascii="Segoe UI Symbol" w:hAnsi="Segoe UI Symbol"/></w:rPr><w:t>$dots</w:t></w:r>
    </w:p>''');
    }
  }

  // ==============================================================================
  // 4. DOCX: TECH CARDS (Modular Card Layout)
  // ==============================================================================
  static void _buildTechCardsDocx(
    StringBuffer docXml,
    CvProfileModel profile,
    String accentHex,
    bool isEn,
    String initials,
    bool hasPhoto,
    bool hasBannerWatermark, {
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  }) {
    docXml.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="11186" w:type="dxa"/>
        <w:tblLayout w:type="fixed"/>
        <w:tblBorders><w:top w:val="single" w:sz="6" w:color="CBD5E1"/><w:left w:val="single" w:sz="24" w:color="$accentHex"/><w:bottom w:val="single" w:sz="6" w:color="CBD5E1"/><w:right w:val="single" w:sz="6" w:color="CBD5E1"/></w:tblBorders>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="2200"/>
        <w:gridCol w:w="8986"/>
      </w:tblGrid>
      <w:tr>
        <!-- PHOTO CELL IN CARD -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="2200" w:type="dxa"/>
            <w:shd w:fill="F8FAFC"/>
            <w:tcMar><w:top w:w="160" w:type="dxa"/><w:bottom w:w="160" w:type="dxa"/><w:left w:w="180" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar>
          </w:tcPr>
''');

    _addDocxPhotoOrInitials(docXml, hasPhoto, initials, isWhite: false, profile: profile, sizeDxa: 920000, jc: 'center', fontTag: fontTag);

    docXml.write('''
        </w:tc>
        <!-- TEXT CELL IN CARD -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="8986" w:type="dxa"/>
            <w:shd w:fill="F8FAFC"/>
            <w:tcMar><w:top w:w="160" w:type="dxa"/><w:bottom w:w="160" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:right w:w="180" w:type="dxa"/></w:tcMar>
          </w:tcPr>
          <w:p><w:r><w:rPr>$fontTag<w:b/><w:sz w:val="38"/><w:color w:val="0F172A"/></w:rPr><w:t>${_escapeXml(profile.fullName)}</w:t></w:r></w:p>
          <w:p><w:r><w:rPr>$fontTag<w:b/><w:sz w:val="20"/><w:color w:val="$accentHex"/></w:rPr><w:t>${_escapeXml(profile.jobTitle.toUpperCase())}</w:t></w:r></w:p>
          <w:p><w:r><w:rPr>$fontTag<w:sz w:val="17"/><w:color w:val="64748B"/></w:rPr><w:t>${_escapeXml('${profile.phone}  |  ${profile.email}  |  ${profile.location}')}</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
    <w:p><w:pPr><w:spacing w:after="100"/></w:pPr></w:p>
''');

    _addSectionHeader(docXml, isEn ? 'ABOUT ME' : 'SOBRE MÍ', accentHex, profile, fontTag);
    docXml.write('''
    <w:p><w:pPr><w:spacing w:after="120"/></w:pPr><w:r><w:rPr>$fontTag<w:sz w:val="17"/><w:color w:val="1E293B"/></w:rPr><w:t>${_escapeXml(profile.summary)}</w:t></w:r></w:p>''');

    _addSectionHeader(docXml, isEn ? 'COMPETENCIES' : 'COMPETENCIAS', accentHex, profile, fontTag);
    for (final s in _getSkillsList(profile)) {
      final dots = _formatRatingDots(s.level, profile.skillRatingStyle);
      docXml.write('''
    <w:p><w:pPr><w:spacing w:after="30"/></w:pPr>
      <w:r><w:rPr>$fontTag<w:b/><w:color w:val="$accentHex"/></w:rPr><w:t>◆ ${_escapeXml(s.name)}  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="14"/><w:color w:val="F59E0B"/><w:rFonts w:ascii="Segoe UI Symbol" w:hAnsi="Segoe UI Symbol"/></w:rPr><w:t>$dots</w:t></w:r>
    </w:p>''');
    }

    _addSectionHeader(docXml, isEn ? 'EXPERIENCE' : 'EXPERIENCIA', accentHex, profile, fontTag);
    for (final e in profile.experiences) {
      _addDocxExperience(docXml, e, accentHex, fontTag);
    }

    _addSectionHeader(docXml, isEn ? 'EDUCATION' : 'FORMACIÓN', accentHex, profile, fontTag);
    for (final ed in profile.educations) {
      _addDocxEducation(docXml, ed, accentHex, fontTag);
    }
  }

  // ==============================================================================
  // XML HELPER METHODS
  // ==============================================================================

  static void _addDocxPhotoOrInitials(
    StringBuffer docXml,
    bool hasPhoto,
    String initials, {
    required bool isWhite,
    required CvProfileModel profile,
    int sizeDxa = 1016000,
    String jc = 'center',
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  }) {
    final isSquare = profile.photoShape == 'square';
    final geom = isSquare ? 'roundRect' : 'ellipse';
    final accentHex = profile.accentColor.replaceAll('#', '').toUpperCase();
    final borderColor = isWhite ? 'FFFFFF' : accentHex;

    if (hasPhoto) {
      docXml.write('''
          <w:p>
            <w:pPr><w:jc w:val="$jc"/><w:spacing w:before="40" w:after="60"/></w:pPr>
            <w:r>
              <w:drawing>
                <wp:inline distT="0" distB="0" distL="0" distR="0">
                  <wp:extent cx="$sizeDxa" cy="$sizeDxa"/>
                  <wp:docPr id="1" name="Photo"/>
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:pic>
                        <pic:nvPicPr><pic:cNvPr id="0" name="Photo"/><pic:cNvPicPr/></pic:nvPicPr>
                        <pic:blipFill><a:blip r:embed="rIdPhoto"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                        <pic:spPr>
                          <a:xfrm><a:off x="0" y="0"/><a:ext cx="$sizeDxa" cy="$sizeDxa"/></a:xfrm>
                          <a:prstGeom prst="$geom"><a:avLst/></a:prstGeom>
                          <a:ln w="25400"><a:solidFill><a:srgbClr val="$borderColor"/></a:solidFill></a:ln>
                        </pic:spPr>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:inline>
              </w:drawing>
            </w:r>
          </w:p>''');
    } else {
      docXml.write('''
          <w:p>
            <w:pPr><w:jc w:val="$jc"/><w:spacing w:before="40" w:after="80"/></w:pPr>
            <w:r>
              <w:rPr>
                $fontTag
                <w:b/><w:sz w:val="38"/>
                <w:color w:val="${isWhite ? accentHex : 'FFFFFF'}"/>
                <w:shd w:val="clear" w:color="auto" w:fill="${isWhite ? 'FFFFFF' : accentHex}"/>
              </w:rPr>
              <w:t xml:space="preserve">  $initials  </w:t>
            </w:r>
          </w:p>''');
    }
  }

  static void _addSidebarPill(
    StringBuffer docXml,
    String label,
    String accentHex, {
    CvProfileModel? profile,
    PillBadgeAsset? badge,
    String? relId,
    bool hasWhitePill = false,
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  }) {
    final sz = profile != null ? _scaleSz(15, profile.fontSizeScale) : 15;
    final pillDocId = 2000 + (label.hashCode.abs() % 4000);

    if (badge != null && relId != null) {
      final wEmu = (badge.width * 12700).round();
      final hEmu = (badge.height * 12700).round();
      docXml.write('''
          <w:p>
            <w:pPr>
              <w:jc w:val="center"/>
              <w:spacing w:before="120" w:after="70"/>
            </w:pPr>
            <w:r>
              <w:drawing>
                <wp:inline distT="0" distB="0" distL="0" distR="0">
                  <wp:extent cx="$wEmu" cy="$hEmu"/>
                  <wp:docPr id="$pillDocId" name="Pill"/><wp:cNvGraphicFramePr/>
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:pic>
                        <pic:nvPicPr><pic:cNvPr id="$pillDocId" name="Pill"/><pic:cNvPicPr/></pic:nvPicPr>
                        <pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$wEmu" cy="$hEmu"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:inline>
              </w:drawing>
            </w:r>
          </w:p>''');
      return;
    }

    if (hasWhitePill) {
      docXml.write('''
          <w:p>
            <w:pPr>
              <w:jc w:val="center"/>
              <w:spacing w:before="60" w:after="0" w:line="240" w:lineRule="exact"/>
            </w:pPr>
            <w:r>
              <w:drawing>
                <wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="0" behindDoc="1" locked="1" layoutInCell="1" allowOverlap="1">
                  <wp:simplePos x="0" y="0"/>
                  <wp:positionH relativeFrom="column"><wp:align>center</wp:align></wp:positionH>
                  <wp:positionV relativeFrom="paragraph"><wp:posOffset>-25400</wp:posOffset></wp:positionV>
                  <wp:extent cx="1841500" cy="254000"/>
                  <wp:effectExtent l="0" t="0" r="0" b="0"/>
                  <wp:wrapNone/>
                  <wp:docPr id="$pillDocId" name="WhitePill"/><wp:cNvGraphicFramePr/>
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:pic>
                        <pic:nvPicPr><pic:cNvPr id="$pillDocId" name="WhitePill"/><pic:cNvPicPr/></pic:nvPicPr>
                        <pic:blipFill><a:blip r:embed="rIdWhitePill"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1841500" cy="254000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:anchor>
              </w:drawing>
            </w:r>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="$sz"/><w:color w:val="$accentHex"/><w:spacing w:val="14"/></w:rPr>
              <w:t>${_escapeXml(label)}</w:t>
            </w:r>
          </w:p>
          <w:p><w:pPr><w:spacing w:before="0" w:after="80"/></w:pPr></w:p>''');
      return;
    }

    docXml.write('''
          <w:tbl>
            <w:tblPr>
              <w:tblW w:w="2400" w:type="dxa"/>
              <w:jc w:val="center"/>
              <w:tblLayout w:type="fixed"/>
              <w:tblCellMar>
                <w:top w:w="40" w:type="dxa"/><w:bottom w:w="40" w:type="dxa"/>
                <w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/>
              </w:tblCellMar>
              <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/></w:tblBorders>
            </w:tblPr>
            <w:tblGrid><w:gridCol w:w="2400"/></w:tblGrid>
            <w:tr>
              <w:trPr><w:trHeight w:val="340" w:hRule="exact"/></w:trPr>
              <w:tc>
                <w:tcPr>
                  <w:tcW w:w="2400" w:type="dxa"/>
                  <w:shd w:val="clear" w:color="auto" w:fill="FFFFFF"/>
                  <w:tcMar>
                    <w:top w:w="40" w:type="dxa"/><w:bottom w:w="40" w:type="dxa"/>
                    <w:left w:w="60" w:type="dxa"/><w:right w:w="60" w:type="dxa"/>
                  </w:tcMar>
                  <w:vAlign w:val="center"/>
                </w:tcPr>
                <w:p>
                  <w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="0" w:line="220" w:lineRule="exact"/></w:pPr>
                  <w:r>
                    <w:rPr>$fontTag<w:b/><w:sz w:val="$sz"/><w:color w:val="$accentHex"/><w:spacing w:val="12"/></w:rPr>
                    <w:t>${_escapeXml(label)}</w:t>
                  </w:r>
                </w:p>
              </w:tc>
            </w:tr>
          </w:tbl>
          <w:p><w:pPr><w:spacing w:before="0" w:after="90"/></w:pPr></w:p>''');
  }

  static void _addSidebarContactItem(
    StringBuffer docXml,
    String relId,
    String value, [
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  ]) {
    if (value.trim().isEmpty) return;
    docXml.write('''
          <w:p>
            <w:pPr>
              <w:spacing w:before="20" w:after="34" w:line="220" w:lineRule="auto"/>
              <w:ind w:left="100"/>
            </w:pPr>
            <w:r>
              <w:drawing>
                <wp:inline distT="0" distB="0" distL="0" distR="0">
                  <wp:extent cx="137160" cy="137160"/>
                  <wp:docPr id="1020" name="Icon"/><wp:cNvGraphicFramePr/>
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:pic>
                        <pic:nvPicPr><pic:cNvPr id="1020" name="Icon"/><pic:cNvPicPr/></pic:nvPicPr>
                        <pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="137160" cy="137160"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:inline>
              </w:drawing>
            </w:r>
            <w:r>
              <w:rPr>$fontTag<w:sz w:val="15"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t xml:space="preserve">  ${_escapeXml(value)}</w:t>
            </w:r>
          </w:p>''');
  }

  static void _addWhiteSidebarContactRow(
    StringBuffer docXml,
    String iconSymbol,
    String value, [
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  ]) {
    if (value.trim().isEmpty) return;
    docXml.write('''
          <w:p>
            <w:pPr>
              <w:ind w:left="100"/>
              <w:spacing w:before="20" w:after="40"/>
            </w:pPr>
            <w:r>
              <w:rPr><w:sz w:val="18"/><w:color w:val="FFFFFF"/><w:rFonts w:ascii="Segoe UI Symbol" w:hAnsi="Segoe UI Symbol"/></w:rPr>
              <w:t xml:space="preserve">$iconSymbol  </w:t>
            </w:r>
            <w:r>
              <w:rPr>$fontTag<w:sz w:val="15"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>${_escapeXml(value)}</w:t>
            </w:r>
          </w:p>''');
  }

  static void _addSectionHeaderPill(
    StringBuffer docXml,
    String title,
    String accentHex, {
    required bool hasPillBg,
    CvProfileModel? profile,
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  }) {
    final sz = profile != null ? _scaleSz(16, profile.fontSizeScale) : 16;

    if (hasPillBg) {
      docXml.write('''
          <w:tbl>
            <w:tblPr>
              <w:tblW w:w="7160" w:type="dxa"/>
              <w:tblLayout w:type="fixed"/>
              <w:tblCellMar>
                <w:top w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/>
                <w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/>
              </w:tblCellMar>
              <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/></w:tblBorders>
            </w:tblPr>
            <w:tblGrid><w:gridCol w:w="7160"/></w:tblGrid>
            <w:tr>
              <w:trPr><w:trHeight w:val="440" w:hRule="exact"/></w:trPr>
              <w:tc>
                <w:tcPr>
                  <w:tcW w:w="7160" w:type="dxa"/>
                  <w:shd w:val="none"/>
                  <w:tcMar>
                    <w:top w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/>
                    <w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/>
                  </w:tcMar>
                  <w:vAlign w:val="center"/>
                </w:tcPr>
                <w:p>
                  <w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="exact"/></w:pPr>
                  <w:r>
                    <w:drawing>
                      <wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="0" behindDoc="1" locked="1" layoutInCell="1" allowOverlap="1">
                        <wp:simplePos x="0" y="0"/>
                        <wp:positionH relativeFrom="column"><wp:align>center</wp:align></wp:positionH>
                        <wp:positionV relativeFrom="paragraph"><wp:posOffset>-63500</wp:posOffset></wp:positionV>
                        <wp:extent cx="4546600" cy="279400"/>
                        <wp:effectExtent l="0" t="0" r="0" b="0"/>
                        <wp:wrapNone/>
                        <wp:docPr id="1030" name="Pill"/><wp:cNvGraphicFramePr/>
                        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                            <pic:pic>
                              <pic:nvPicPr><pic:cNvPr id="1030" name="Pill"/><pic:cNvPicPr/></pic:nvPicPr>
                              <pic:blipFill><a:blip r:embed="rIdPillBg"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                              <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="4546600" cy="279400"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                            </pic:pic>
                          </a:graphicData>
                        </a:graphic>
                      </wp:anchor>
                    </w:drawing>
                  </w:r>
                  <w:r>
                    <w:rPr>$fontTag<w:b/><w:sz w:val="$sz"/><w:color w:val="FFFFFF"/><w:spacing w:val="14"/></w:rPr>
                    <w:t>${_escapeXml(title.toUpperCase())}</w:t>
                  </w:r>
                </w:p>
              </w:tc>
            </w:tr>
          </w:tbl>
          <w:p><w:pPr><w:spacing w:before="0" w:after="90"/></w:pPr></w:p>''');
    } else {
      _addBoxedSectionHeader(docXml, title, accentHex, profile, fontTag);
    }
  }

  static void _addBoxedHeaderBannerFallback(
    StringBuffer docXml,
    CvProfileModel profile,
    String accentHex,
    int nameSz,
    int jobSz, [
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  ]) {
    docXml.write('''
          <w:tbl>
            <w:tblPr>
              <w:tblW w:w="7166" w:type="dxa"/>
              <w:tblLayout w:type="fixed"/>
              <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/></w:tblBorders>
            </w:tblPr>
            <w:tblGrid><w:gridCol w:w="7166"/></w:tblGrid>
            <w:tr>
              <w:tc>
                <w:tcPr>
                  <w:tcW w:w="7166" w:type="dxa"/>
                  <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
                  <w:tcMar>
                    <w:top w:w="140" w:type="dxa"/><w:bottom w:w="140" w:type="dxa"/>
                    <w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/>
                  </w:tcMar>
                </w:tcPr>
                <w:p>
                  <w:pPr><w:jc w:val="center"/><w:spacing w:before="40" w:after="20"/></w:pPr>
                  <w:r>
                    <w:rPr>$fontTag<w:b/><w:sz w:val="$nameSz"/><w:color w:val="FFFFFF"/></w:rPr>
                    <w:t>${_escapeXml(profile.fullName.isNotEmpty ? profile.fullName.toUpperCase() : 'NOMBRE Y APELLIDOS')}</w:t>
                  </w:r>
                </w:p>''');

    if (profile.jobTitle.isNotEmpty) {
      docXml.write('''
                <w:p>
                  <w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="40"/></w:pPr>
                  <w:r>
                    <w:rPr>$fontTag<w:b/><w:sz w:val="$jobSz"/><w:color w:val="FFFFFF"/></w:rPr>
                    <w:t>${_escapeXml(profile.jobTitle.toUpperCase())}</w:t>
                  </w:r>
                </w:p>''');
    }

    docXml.write('''
              </w:tc>
            </w:tr>
          </w:tbl>
          <w:p><w:pPr><w:spacing w:before="0" w:after="120"/></w:pPr></w:p>''');
  }

  static void _addBoxedSectionHeader(
    StringBuffer docXml,
    String title,
    String accentHex, [
    CvProfileModel? profile,
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  ]) {
    final sz = profile != null ? _scaleSz(17, profile.fontSizeScale) : 17;

    docXml.write('''
          <w:tbl>
            <w:tblPr>
              <w:tblW w:w="7166" w:type="dxa"/>
              <w:tblLayout w:type="fixed"/>
              <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/></w:tblBorders>
            </w:tblPr>
            <w:tblGrid><w:gridCol w:w="7166"/></w:tblGrid>
            <w:tr>
              <w:tc>
                <w:tcPr>
                  <w:tcW w:w="7166" w:type="dxa"/>
                  <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
                  <w:tcMar>
                    <w:top w:w="70" w:type="dxa"/><w:bottom w:w="70" w:type="dxa"/>
                    <w:left w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/>
                  </w:tcMar>
                </w:tcPr>
                <w:p>
                  <w:pPr><w:jc w:val="center"/><w:spacing w:before="20" w:after="20"/></w:pPr>
                  <w:r>
                    <w:rPr>$fontTag<w:b/><w:sz w:val="$sz"/><w:color w:val="FFFFFF"/></w:rPr>
                    <w:t>${_escapeXml(title.toUpperCase())}</w:t>
                  </w:r>
                </w:p>
              </w:tc>
            </w:tr>
          </w:tbl>
          <w:p><w:pPr><w:spacing w:before="0" w:after="80"/></w:pPr></w:p>''');
  }

  static void _addSectionHeader(
    StringBuffer docXml,
    String title,
    String accentHex, [
    CvProfileModel? profile,
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  ]) {
    final sz = profile != null ? _scaleSz(21, profile.fontSizeScale) : 21;

    docXml.write('''
          <w:p>
            <w:pPr>
              <w:spacing w:before="180" w:after="80"/>
              <w:pBdr><w:bottom w:val="single" w:sz="12" w:space="4" w:color="$accentHex"/></w:pBdr>
            </w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="$sz"/><w:color w:val="$accentHex"/></w:rPr>
              <w:t>${_escapeXml(title.toUpperCase())}</w:t>
            </w:r>
          </w:p>''');
  }

  static void _addHorizontalRule(StringBuffer docXml, String colorHex) {
    docXml.write('''
          <w:p>
            <w:pPr>
              <w:spacing w:before="40" w:after="80"/>
              <w:pBdr><w:bottom w:val="single" w:sz="12" w:space="2" w:color="$colorHex"/></w:pBdr>
            </w:pPr>
          </w:p>''');
  }

  static void _addDocxExperience(
    StringBuffer docXml,
    CvExperience exp,
    String accentHex, [
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  ]) {
    final title = exp.jobTitle.isNotEmpty ? exp.jobTitle.toUpperCase() : 'PUESTO / OFICIO';
    docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:before="80" w:after="15"/></w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="17"/><w:color w:val="0F172A"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(title)}</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:pPr>
              <w:tabs><w:tab w:val="right" w:pos="6800"/></w:tabs>
              <w:spacing w:before="0" w:after="25"/>
            </w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="15"/><w:color w:val="$accentHex"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(exp.company)}</w:t>
            </w:r>
            <w:r><w:tab/></w:r>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="14"/><w:color w:val="64748B"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(exp.period)}</w:t>
            </w:r>
          </w:p>''');

    if (exp.description.isNotEmpty) {
      final lines = exp.description
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty);
      for (final line in lines) {
        docXml.write('''
          <w:p>
            <w:pPr>
              <w:ind w:left="100"/>
              <w:spacing w:after="30" w:line="215" w:lineRule="auto"/>
            </w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:sz w:val="14"/><w:color w:val="475569"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(line)}</w:t>
            </w:r>
          </w:p>''');
      }
    }
  }

  static void _addDocxEducation(
    StringBuffer docXml,
    CvEducation edu,
    String accentHex, [
    String fontTag = '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>',
  ]) {
    final title = edu.degree.isNotEmpty ? edu.degree.toUpperCase() : 'TITULACIÓN / CERTIFICADO';
    docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:before="75" w:after="15"/></w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="17"/><w:color w:val="0F172A"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(title)}</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:pPr>
              <w:tabs><w:tab w:val="right" w:pos="6800"/></w:tabs>
              <w:spacing w:before="0" w:after="25"/>
            </w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="15"/><w:color w:val="$accentHex"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(edu.institution)}</w:t>
            </w:r>
            <w:r><w:tab/></w:r>
            <w:r>
              <w:rPr>$fontTag<w:b/><w:sz w:val="14"/><w:color w:val="64748B"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(edu.period)}</w:t>
            </w:r>
          </w:p>''');

    if (edu.details.isNotEmpty) {
      final lines = edu.details
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty);
      for (final line in lines) {
        docXml.write('''
          <w:p>
            <w:pPr>
              <w:ind w:left="100"/>
              <w:spacing w:after="30" w:line="215" w:lineRule="auto"/>
            </w:pPr>
            <w:r>
              <w:rPr>$fontTag<w:sz w:val="14"/><w:color w:val="475569"/></w:rPr>
              <w:t xml:space="preserve">${_escapeXml(line)}</w:t>
            </w:r>
          </w:p>''');
      }
    }
  }

  static List<CvSkillItem> _getSkillsList(CvProfileModel profile) {
    if (profile.skillItems.isNotEmpty) return profile.skillItems;
    if (profile.skills.isNotEmpty) {
      return profile.skills.map((s) => CvSkillItem(name: s, level: 5)).toList();
    }
    return [];
  }

  static String _formatRatingDots(int level, [String style = 'dots']) {
    final lvl = level.clamp(1, 5);
    if (style == 'stars') {
      return '${'★' * lvl}${'☆' * (5 - lvl)}';
    }
    return '${'●' * lvl}${'○' * (5 - lvl)}';
  }

  // ==============================================================================
  // PUBLIC HIGH-LEVEL API
  // ==============================================================================

  static Future<Uint8List> generateDocx(
    CvProfileModel profile, [
    Uint8List? preloadedPhotoBytes,
  ]) async {
    final photoBytes = preloadedPhotoBytes ?? await fetchOrDecodePhoto(profile.photoUrl);
    final assets = await prepareAssets(profile, photoBytes);
    return generateDocxBytes(profile, photoBytes, null, null, assets);
  }

  static Future<void> downloadDocx(CvProfileModel profile) async {
    final photoBytes = await fetchOrDecodePhoto(profile.photoUrl);
    final assets = await prepareAssets(profile, photoBytes);
    final bytes = generateDocxBytes(profile, photoBytes, null, null, assets);

    final safeName = profile.fullName.trim().isEmpty ? 'Curriculum_Vitae' : profile.fullName.trim().replaceAll(' ', '_');
    final filename = '${safeName}_CV.docx';

    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
