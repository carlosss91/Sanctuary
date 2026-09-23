import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../models/cv_profile_model.dart';

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

  static String _getWatermarkMotif(CvProfileModel profile) {
    if (!profile.showWatermark || profile.watermarkPattern == 'none') return '';
    switch (profile.watermarkPattern) {
      case 'gears':
        return '⚙';
      case 'tools':
        return '🛠';
      case 'shield':
        return '🛡';
      case 'geometric':
        return '❖';
      case 'tech_dots':
        return '✦';
      case 'lines':
        return '═';
      default:
        return '⚙';
    }
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

  static Uint8List generateDocxBytes(CvProfileModel profile, [Uint8List? preloadedPhotoBytes]) {
    final archive = Archive();
    final isEn = profile.isEnglishVersion;
    final accentHex = profile.accentColor.replaceAll('#', '').toUpperCase();
    final initials = _getInitials(profile);

    // Resolve photo bytes: either preloaded or synchronously decoded from base64
    Uint8List? photoBytes = preloadedPhotoBytes;
    String photoExtension = 'png';
    if (photoBytes == null && profile.photoUrl.startsWith('data:image')) {
      try {
        final comma = profile.photoUrl.indexOf(',');
        if (comma >= 0) {
          final header = profile.photoUrl.substring(0, comma);
          if (header.contains('jpeg') || header.contains('jpg')) photoExtension = 'jpg';
          final base64Str = profile.photoUrl.substring(comma + 1);
          photoBytes = base64Decode(base64Str);
        }
      } catch (_) {}
    } else if (photoBytes != null) {
      if (profile.photoUrl.toLowerCase().contains('.jpg') || profile.photoUrl.toLowerCase().contains('.jpeg')) {
        photoExtension = 'jpg';
      }
    }

    final hasPhoto = photoBytes != null && photoBytes.isNotEmpty;
    if (hasPhoto) {
      archive.addFile(ArchiveFile('word/media/image1.$photoExtension', photoBytes.length, photoBytes));
    }

    // 1. [Content_Types].xml
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // 3. word/_rels/document.xml.rels
    final docRelsXml = StringBuffer();
    docRelsXml.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>''');
    if (hasPhoto) {
      docRelsXml.write('''
  <Relationship Id="rIdPhoto" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.$photoExtension"/>''');
    }
    docRelsXml.write('\n</Relationships>');
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml.toString())));

    // 4. word/styles.xml
    final docFontFamily = profile.fontFamily.trim().isNotEmpty ? profile.fontFamily.trim() : 'Calibri';
    final baseSz = _scaleSz(20, profile.fontSizeScale);
    final trackingTwips = (profile.fontSpacing * 20).round();
    final lineSpacingDxa = (240 * profile.lineSpacing).round();

    final stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rFonts w:ascii="$docFontFamily" w:hAnsi="$docFontFamily" w:cs="$docFontFamily"/>
      <w:sz w:val="$baseSz"/>
      <w:spacing w:val="$trackingTwips"/>
      <w:color w:val="1E293B"/>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:spacing w:line="$lineSpacingDxa" w:lineRule="auto"/>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>''';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 5. word/document.xml
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
        _buildModernHeaderDocx(docXml, profile, accentHex, isEn, initials, hasPhoto);
        break;
      case 'minimalist':
        _buildMinimalistDocx(docXml, profile, accentHex, isEn, initials, hasPhoto);
        break;
      case 'tech_cards':
        _buildTechCardsDocx(docXml, profile, accentHex, isEn, initials, hasPhoto);
        break;
      case 'sidebar_dark':
      default:
        _buildSidebarDarkDocx(docXml, profile, accentHex, isEn, initials, hasPhoto);
        break;
    }

    // Page setup (A4 format: 11906 x 16838 dxa with 720 dxa = 0.5 in margins)
    docXml.write('''
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/>
    </w:sectPr>
  </w:body>
</w:document>''');

    archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml.toString())));

    final zipEncoder = ZipEncoder();
    final bytes = zipEncoder.encode(archive);
    return Uint8List.fromList(bytes);
  }

  // ==============================================================================
  // 1. DOCX: SIDEBAR DARK (Table with Shaded Left Column)
  // ==============================================================================
  static void _buildSidebarDarkDocx(
    StringBuffer docXml,
    CvProfileModel profile,
    String accentHex,
    bool isEn,
    String initials,
    bool hasPhoto,
  ) {
    docXml.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="10466" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/>
          <w:insideH w:val="none"/><w:insideV w:val="none"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tr>
        <!-- LEFT COLUMN: ACCENT COLOR SHADING -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="3400" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
            <w:tcMar>
              <w:top w:w="240" w:type="dxa"/><w:bottom w:w="240" w:type="dxa"/>
              <w:left w:w="240" w:type="dxa"/><w:right w:w="240" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
''');

    // Photo or initials (centered in sidebar with white border)
    _addDocxPhotoOrInitials(docXml, hasPhoto, initials, isWhite: true, profile: profile, sizeDxa: 1100000, jc: 'center');

    // Datos de Contacto
    _addSidebarPill(docXml, isEn ? 'CONTACT DETAILS' : 'DATOS', profile);
    if (profile.phone.isNotEmpty) _addWhiteSidebarItem(docXml, isEn ? 'Tel' : 'Teléfono', profile.phone);
    if (profile.email.isNotEmpty) _addWhiteSidebarItem(docXml, 'Email', profile.email);
    if (profile.location.isNotEmpty) _addWhiteSidebarItem(docXml, isEn ? 'Location' : 'Ubicación', profile.location);
    if (profile.availability.isNotEmpty) _addWhiteSidebarItem(docXml, isEn ? 'Disp.' : 'Disponibilidad', profile.availability);
    if (profile.drivingLicense.isNotEmpty) _addWhiteSidebarItem(docXml, isEn ? 'License' : 'Permiso', profile.drivingLicense);

    // Sobre Mí
    if (profile.summary.trim().isNotEmpty) {
      _addSidebarPill(docXml, isEn ? 'ABOUT ME' : 'SOBRE MÍ', profile);
      final summarySz = _scaleSz(16, profile.fontSizeScale);
      docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:after="100"/></w:pPr>
            <w:r><w:rPr><w:sz w:val="$summarySz"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>${_escapeXml(profile.summary)}</w:t>
            </w:r>
          </w:p>''');
    }

    // Competencias
    final skillsList = _getSkillsList(profile);
    if (skillsList.isNotEmpty) {
      _addSidebarPill(docXml, isEn ? 'KEY SKILLS' : 'COMPETENCIAS', profile);
      for (final item in skillsList) {
        final dots = _formatRatingDots(item.level, profile.skillRatingStyle);
        final skillSz = _scaleSz(16, profile.fontSizeScale);
        final descSz = _scaleSz(13, profile.fontSizeScale);
        docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:before="60" w:after="20"/></w:pPr>
            <w:r>
              <w:rPr><w:b/><w:sz w:val="$skillSz"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>${_escapeXml(item.name.toUpperCase())}  </w:t>
            </w:r>
            <w:r>
              <w:rPr><w:sz w:val="14"/><w:color w:val="FBBF24"/></w:rPr>
              <w:t>$dots</w:t>
            </w:r>
          </w:p>''');
        if (item.description.isNotEmpty) {
          docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:after="50"/></w:pPr>
            <w:r>
              <w:rPr><w:sz w:val="$descSz"/><w:color w:val="E2E8F0"/></w:rPr>
              <w:t>  ${_escapeXml(item.description)}</w:t>
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
            <w:tcW w:w="7066" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="240" w:type="dxa"/><w:bottom w:w="240" w:type="dxa"/>
              <w:left w:w="300" w:type="dxa"/><w:right w:w="160" w:type="dxa"/>
            </w:tcMar>
          </w:tcPr>
''');

    // Header Banner Box matching Screenshot 3
    final motif = _getWatermarkMotif(profile);
    final motifPrefix = motif.isNotEmpty ? '$motif  ' : '';
    final motifSuffix = motif.isNotEmpty ? '  $motif' : '';
    final nameSz = _scaleSz(30, profile.fontSizeScale);
    final jobSz = _scaleSz(18, profile.fontSizeScale);

    docXml.write('''
          <w:p>
            <w:pPr>
              <w:jc w:val="center"/>
              <w:spacing w:before="60" w:after="20"/>
              <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
            </w:pPr>
            <w:r>
              <w:rPr><w:b/><w:sz w:val="$nameSz"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>  $motifPrefix${_escapeXml(profile.fullName.isNotEmpty ? profile.fullName.toUpperCase() : 'NOMBRE Y APELLIDOS')}$motifSuffix  </w:t>
            </w:r>
          </w:p>''');

    if (profile.jobTitle.isNotEmpty) {
      docXml.write('''
          <w:p>
            <w:pPr>
              <w:jc w:val="center"/>
              <w:spacing w:before="0" w:after="160"/>
              <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
            </w:pPr>
            <w:r>
              <w:rPr><w:b/><w:sz w:val="$jobSz"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>  $motifPrefix${_escapeXml(profile.jobTitle.toUpperCase())}$motifSuffix  </w:t>
            </w:r>
          </w:p>''');
    }

    // Experience with Boxed Recuadro Header matching Screenshot 3
    _addBoxedSectionHeader(docXml, isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL', accentHex, profile);
    for (final exp in profile.experiences) {
      _addDocxExperience(docXml, exp, accentHex);
    }

    // Education & Certifications with Boxed Recuadro Header matching Screenshot 3
    _addBoxedSectionHeader(docXml, isEn ? 'EDUCATION & CERTIFICATIONS' : 'FORMACIÓN Y CERTIFICACIONES', accentHex, profile);
    for (final edu in profile.educations) {
      _addDocxEducation(docXml, edu, accentHex);
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
  ) {
    // Top banner table with photo on left and details on right
    docXml.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="10466" w:type="dxa"/>
        <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/></w:tblBorders>
      </w:tblPr>
      <w:tr>
        <!-- PHOTO CELL IN HEADER -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="2200" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
            <w:tcMar><w:top w:w="200" w:type="dxa"/><w:bottom w:w="200" w:type="dxa"/><w:left w:w="200" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar>
          </w:tcPr>
''');

    _addDocxPhotoOrInitials(docXml, hasPhoto, initials, isWhite: true, profile: profile, sizeDxa: 960000, jc: 'center');

    docXml.write('''
        </w:tc>
        <!-- TEXT CELL IN HEADER -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="8266" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
            <w:tcMar><w:top w:w="200" w:type="dxa"/><w:bottom w:w="200" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="240" w:type="dxa"/></w:tcMar>
          </w:tcPr>
          <w:p>
            <w:pPr><w:spacing w:after="40"/></w:pPr>
            <w:r><w:rPr><w:b/><w:sz w:val="42"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>${_escapeXml(profile.fullName)}</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:pPr><w:spacing w:after="80"/></w:pPr>
            <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="F1F5F9"/></w:rPr>
              <w:t>${_escapeXml(profile.jobTitle.toUpperCase())}</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:r><w:rPr><w:sz w:val="17"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>${_escapeXml([profile.phone, profile.email, profile.location, profile.availability].where((s) => s.isNotEmpty).join('   |   '))}</w:t>
            </w:r>
          </w:p>
        </w:tc>
      </w:tr>
    </w:tbl>

    <!-- 2 COLUMNS BELOW -->
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="10466" w:type="dxa"/>
        <w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/></w:tblBorders>
      </w:tblPr>
      <w:tr>
        <!-- LEFT SUB-COLUMN: Experience & Profile -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="6000" w:type="dxa"/>
            <w:tcMar><w:top w:w="200" w:type="dxa"/><w:right w:w="200" w:type="dxa"/></w:tcMar>
          </w:tcPr>
''');

    _addSectionHeader(docXml, isEn ? 'PROFESSIONAL PROFILE' : 'PERFIL PROFESIONAL', accentHex, profile);
    docXml.write('''
          <w:p><w:pPr><w:spacing w:after="120"/></w:pPr><w:r><w:t>${_escapeXml(profile.summary)}</w:t></w:r></w:p>''');

    _addSectionHeader(docXml, isEn ? 'WORK EXPERIENCE' : 'EXPERIENCIA LABORAL', accentHex, profile);
    for (final exp in profile.experiences) {
      _addDocxExperience(docXml, exp, accentHex);
    }

    docXml.write('''
        </w:tc>
        <!-- RIGHT SUB-COLUMN: Skills & Education -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="4466" w:type="dxa"/>
            <w:tcMar><w:top w:w="200" w:type="dxa"/><w:left w:w="200" w:type="dxa"/></w:tcMar>
          </w:tcPr>
''');

    _addSectionHeader(docXml, isEn ? 'KEY SKILLS' : 'COMPETENCIAS CLAVE', accentHex, profile);
    for (final item in _getSkillsList(profile)) {
      final dots = _formatRatingDots(item.level, profile.skillRatingStyle);
      docXml.write('''
          <w:p><w:pPr><w:spacing w:after="30"/></w:pPr>
            <w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="$accentHex"/></w:rPr><w:t>✔ ${_escapeXml(item.name)}  </w:t></w:r>
            <w:r><w:rPr><w:sz w:val="14"/><w:color w:val="F59E0B"/></w:rPr><w:t>$dots</w:t></w:r>
          </w:p>''');
    }

    _addSectionHeader(docXml, isEn ? 'EDUCATION' : 'FORMACIÓN ACADÉMICA', accentHex, profile);
    for (final edu in profile.educations) {
      _addDocxEducation(docXml, edu, accentHex);
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
    bool hasPhoto,
  ) {
    // Centered Photo
    _addDocxPhotoOrInitials(docXml, hasPhoto, initials, isWhite: false, profile: profile, sizeDxa: 1150000, jc: 'center');

    // Centered Name
    docXml.write('''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:before="60" w:after="40"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="46"/><w:color w:val="0F172A"/></w:rPr>
        <w:t>${_escapeXml(profile.fullName)}</w:t>
      </w:r>
    </w:p>''');

    // Centered Job Title
    docXml.write('''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="60"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="$accentHex"/></w:rPr>
        <w:t>${_escapeXml(profile.jobTitle.toUpperCase())}</w:t>
      </w:r>
    </w:p>''');

    // Centered Contact Line
    docXml.write('''
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="140"/></w:pPr>
      <w:r><w:rPr><w:sz w:val="18"/><w:color w:val="64748B"/></w:rPr>
        <w:t>${_escapeXml([profile.phone, profile.email, profile.location, profile.drivingLicense].where((s) => s.isNotEmpty).join('   •   '))}</w:t>
      </w:r>
    </w:p>''');

    _addHorizontalRule(docXml, accentHex);

    // Profile
    _addSectionHeader(docXml, isEn ? 'PROFILE' : 'PERFIL PROFESIONAL', accentHex, profile);
    docXml.write('''
    <w:p><w:pPr><w:spacing w:after="140"/></w:pPr><w:r><w:t>${_escapeXml(profile.summary)}</w:t></w:r></w:p>''');

    // Experience
    _addSectionHeader(docXml, isEn ? 'EXPERIENCE' : 'EXPERIENCIA LABORAL', accentHex, profile);
    for (final exp in profile.experiences) {
      _addDocxExperience(docXml, exp, accentHex);
    }

    // Education
    _addSectionHeader(docXml, isEn ? 'EDUCATION' : 'FORMACIÓN ACADÉMICA', accentHex, profile);
    for (final edu in profile.educations) {
      _addDocxEducation(docXml, edu, accentHex);
    }

    // Skills
    _addSectionHeader(docXml, isEn ? 'SKILLS & COMPETENCIES' : 'HABILIDADES Y COMPETENCIAS', accentHex, profile);
    for (final s in _getSkillsList(profile)) {
      final dots = _formatRatingDots(s.level, profile.skillRatingStyle);
      docXml.write('''
    <w:p><w:pPr><w:spacing w:after="30"/></w:pPr>
      <w:r><w:t>• ${_escapeXml(s.name)}  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="14"/><w:color w:val="F59E0B"/></w:rPr><w:t>$dots</w:t></w:r>
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
  ) {
    // Header card with photo on left and details on right
    docXml.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="10466" w:type="dxa"/>
        <w:tblBorders><w:top w:val="single" w:sz="6" w:color="CBD5E1"/><w:left w:val="single" w:sz="24" w:color="$accentHex"/><w:bottom w:val="single" w:sz="6" w:color="CBD5E1"/><w:right w:val="single" w:sz="6" w:color="CBD5E1"/></w:tblBorders>
      </w:tblPr>
      <w:tr>
        <!-- PHOTO CELL IN CARD -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="2000" w:type="dxa"/>
            <w:shd w:fill="F8FAFC"/>
            <w:tcMar><w:top w:w="160" w:type="dxa"/><w:bottom w:w="160" w:type="dxa"/><w:left w:w="180" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar>
          </w:tcPr>
''');

    _addDocxPhotoOrInitials(docXml, hasPhoto, initials, isWhite: false, profile: profile, sizeDxa: 920000, jc: 'center');

    docXml.write('''
        </w:tc>
        <!-- TEXT CELL IN CARD -->
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="8466" w:type="dxa"/>
            <w:shd w:fill="F8FAFC"/>
            <w:tcMar><w:top w:w="160" w:type="dxa"/><w:bottom w:w="160" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:right w:w="180" w:type="dxa"/></w:tcMar>
          </w:tcPr>
          <w:p><w:r><w:rPr><w:b/><w:sz w:val="38"/><w:color w:val="0F172A"/></w:rPr><w:t>${_escapeXml(profile.fullName)}</w:t></w:r></w:p>
          <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="$accentHex"/></w:rPr><w:t>${_escapeXml(profile.jobTitle.toUpperCase())}</w:t></w:r></w:p>
          <w:p><w:r><w:rPr><w:sz w:val="17"/><w:color w:val="64748B"/></w:rPr><w:t>${_escapeXml('${profile.phone}  |  ${profile.email}  |  ${profile.location}')}</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
    <w:p><w:pPr><w:spacing w:after="100"/></w:pPr></w:p>
''');

    _addSectionHeader(docXml, isEn ? 'ABOUT ME' : 'SOBRE MÍ', accentHex, profile);
    docXml.write('''
    <w:p><w:pPr><w:spacing w:after="120"/></w:pPr><w:r><w:t>${_escapeXml(profile.summary)}</w:t></w:r></w:p>''');

    _addSectionHeader(docXml, isEn ? 'COMPETENCIES' : 'COMPETENCIAS', accentHex, profile);
    for (final s in _getSkillsList(profile)) {
      final dots = _formatRatingDots(s.level, profile.skillRatingStyle);
      docXml.write('''
    <w:p><w:pPr><w:spacing w:after="30"/></w:pPr>
      <w:r><w:rPr><w:b/><w:color w:val="$accentHex"/></w:rPr><w:t>◆ ${_escapeXml(s.name)}  </w:t></w:r>
      <w:r><w:rPr><w:sz w:val="14"/><w:color w:val="F59E0B"/></w:rPr><w:t>$dots</w:t></w:r>
    </w:p>''');
    }

    _addSectionHeader(docXml, isEn ? 'EXPERIENCE' : 'EXPERIENCIA', accentHex, profile);
    for (final e in profile.experiences) {
      _addDocxExperience(docXml, e, accentHex);
    }

    _addSectionHeader(docXml, isEn ? 'EDUCATION' : 'FORMACIÓN', accentHex, profile);
    for (final ed in profile.educations) {
      _addDocxEducation(docXml, ed, accentHex);
    }
  }

  // --- XML Helper Methods ---

  static void _addDocxPhotoOrInitials(
    StringBuffer docXml,
    bool hasPhoto,
    String initials, {
    required bool isWhite,
    required CvProfileModel profile,
    int sizeDxa = 1080000,
    String jc = 'center',
  }) {
    final isSquare = profile.photoShape == 'square';
    final geom = isSquare ? 'roundRect' : 'ellipse';
    final accentHex = profile.accentColor.replaceAll('#', '').toUpperCase();
    final borderColor = isWhite ? 'FFFFFF' : accentHex;

    if (hasPhoto) {
      // Inline image drawing OpenXML with exact geometry and border
      docXml.write('''
          <w:p>
            <w:pPr><w:jc w:val="$jc"/><w:spacing w:before="100" w:after="100"/></w:pPr>
            <w:r>
              <w:drawing>
                <wp:inline distT="0" distB="0" distL="0" distR="0">
                  <wp:extent cx="$sizeDxa" cy="$sizeDxa"/>
                  <wp:docPr id="1" name="Photo"/>
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:pic>
                        <pic:nvPicPr>
                          <pic:cNvPr id="0" name="Photo"/>
                          <pic:cNvPicPr/>
                        </pic:nvPicPr>
                        <pic:blipFill>
                          <a:blip r:embed="rIdPhoto"/>
                          <a:stretch><a:fillRect/></a:stretch>
                        </pic:blipFill>
                        <pic:spPr>
                          <a:xfrm><a:off x="0" y="0"/><a:ext cx="$sizeDxa" cy="$sizeDxa"/></a:xfrm>
                          <a:prstGeom prst="$geom"><a:avLst/></a:prstGeom>
                          <a:ln w="25400">
                            <a:solidFill><a:srgbClr val="$borderColor"/></a:solidFill>
                          </a:ln>
                        </pic:spPr>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:inline>
              </w:drawing>
            </w:r>
          </w:p>''');
    } else {
      // Initials frame
      docXml.write('''
          <w:p>
            <w:pPr><w:jc w:val="$jc"/><w:spacing w:before="100" w:after="120"/></w:pPr>
            <w:r>
              <w:rPr>
                <w:b/><w:sz w:val="38"/>
                <w:color w:val="${isWhite ? "FFFFFF" : accentHex}"/>
                <w:shd w:fill="${isWhite ? "FFFFFF" : "E2E8F0"}" w:themeFillTint="${isWhite ? "33" : "FF"}"/>
              </w:rPr>
              <w:t>  $initials  </w:t>
            </w:r>
          </w:p>''');
    }
  }

  static void _addSidebarPill(StringBuffer docXml, String label, [CvProfileModel? profile]) {
    final motif = profile != null ? _getWatermarkMotif(profile) : '';
    final motifPrefix = motif.isNotEmpty ? '$motif  ' : '';
    final motifSuffix = motif.isNotEmpty ? '  $motif' : '';
    final sz = profile != null ? _scaleSz(17, profile.fontSizeScale) : 17;

    docXml.write('''
          <w:p>
            <w:pPr><w:jc w:val="center"/><w:spacing w:before="140" w:after="80"/></w:pPr>
            <w:r>
              <w:rPr><w:b/><w:sz w:val="$sz"/><w:color w:val="FFFFFF"/><w:shd w:fill="FFFFFF" w:themeFillTint="33"/></w:rPr>
              <w:t>  $motifPrefix$label$motifSuffix  </w:t>
            </w:r>
          </w:p>''');
  }

  static void _addWhiteSidebarItem(StringBuffer docXml, String label, String value) {
    docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:after="40"/></w:pPr>
            <w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="FFFFFF"/></w:rPr><w:t>$label: </w:t></w:r>
            <w:r><w:rPr><w:sz w:val="16"/><w:color w:val="FFFFFF"/></w:rPr><w:t>${_escapeXml(value)}</w:t></w:r>
          </w:p>''');
  }

  static void _addBoxedSectionHeader(StringBuffer docXml, String title, String accentHex, [CvProfileModel? profile]) {
    final motif = profile != null ? _getWatermarkMotif(profile) : '';
    final motifPrefix = motif.isNotEmpty ? '$motif  ' : '';
    final motifSuffix = motif.isNotEmpty ? '  $motif' : '';
    final sz = profile != null ? _scaleSz(18, profile.fontSizeScale) : 18;

    docXml.write('''
          <w:p>
            <w:pPr>
              <w:jc w:val="center"/>
              <w:spacing w:before="180" w:after="100"/>
              <w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>
            </w:pPr>
            <w:r>
              <w:rPr><w:b/><w:sz w:val="$sz"/><w:color w:val="FFFFFF"/></w:rPr>
              <w:t>  $motifPrefix${_escapeXml(title)}$motifSuffix  </w:t>
            </w:r>
          </w:p>''');
  }

  static void _addSectionHeader(StringBuffer docXml, String title, String accentHex, [CvProfileModel? profile]) {
    final motif = profile != null ? _getWatermarkMotif(profile) : '';
    final motifPrefix = motif.isNotEmpty ? '$motif  ' : '■  ';
    final sz = profile != null ? _scaleSz(22, profile.fontSizeScale) : 22;

    docXml.write('''
          <w:p>
            <w:pPr>
              <w:spacing w:before="180" w:after="80"/>
              <w:pBdr><w:bottom w:val="single" w:sz="10" w:space="4" w:color="$accentHex"/></w:pBdr>
            </w:pPr>
            <w:r>
              <w:rPr><w:b/><w:sz w:val="$sz"/><w:color w:val="$accentHex"/></w:rPr>
              <w:t>$motifPrefix${_escapeXml(title)}</w:t>
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

  static void _addDocxExperience(StringBuffer docXml, CvExperience exp, String accentHex) {
    docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:before="60" w:after="20"/></w:pPr>
            <w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="0F172A"/></w:rPr>
              <w:t>${_escapeXml(exp.jobTitle.isNotEmpty ? exp.jobTitle : "Puesto")}</w:t>
            </w:r>
            <w:r><w:t>   </w:t></w:r>
            <w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="$accentHex"/><w:shd w:fill="F1F5F9"/></w:rPr>
              <w:t>  ${_escapeXml(exp.period)}  </w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:pPr><w:spacing w:after="30"/></w:pPr>
            <w:r><w:rPr><w:b/><w:sz w:val="17"/><w:color w:val="64748B"/></w:rPr>
              <w:t>${_escapeXml(exp.company)}</w:t>
            </w:r>
          </w:p>''');
    if (exp.description.isNotEmpty) {
      docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:after="100"/></w:pPr>
            <w:r><w:rPr><w:sz w:val="17"/><w:color w:val="475569"/></w:rPr>
              <w:t>${_escapeXml(exp.description)}</w:t>
            </w:r>
          </w:p>''');
    }
  }

  static void _addDocxEducation(StringBuffer docXml, CvEducation edu, String accentHex) {
    docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:before="60" w:after="20"/></w:pPr>
            <w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="0F172A"/></w:rPr>
              <w:t>${_escapeXml(edu.degree.isNotEmpty ? edu.degree : "Titulación")}</w:t>
            </w:r>
            <w:r><w:t>   </w:t></w:r>
            <w:r><w:rPr><w:sz w:val="16"/><w:color w:val="64748B"/></w:rPr>
              <w:t>${_escapeXml(edu.period)}</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:pPr><w:spacing w:after="20"/></w:pPr>
            <w:r><w:rPr><w:b/><w:sz w:val="17"/><w:color w:val="$accentHex"/></w:rPr>
              <w:t>${_escapeXml(edu.institution)}</w:t>
            </w:r>
          </w:p>''');
    if (edu.details.isNotEmpty) {
      docXml.write('''
          <w:p>
            <w:pPr><w:spacing w:after="100"/></w:pPr>
            <w:r><w:rPr><w:sz w:val="17"/><w:color w:val="64748B"/></w:rPr>
              <w:t>${_escapeXml(edu.details)}</w:t>
            </w:r>
          </w:p>''');
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

  static Future<void> downloadDocx(CvProfileModel profile) async {
    final photoBytes = await fetchOrDecodePhoto(profile.photoUrl);
    final bytes = generateDocxBytes(profile, photoBytes);
    final safeName = profile.fullName.trim().isEmpty ? 'Curriculum_Vitae' : profile.fullName.trim().replaceAll(' ', '_');
    final filename = '${safeName}_CV.docx';

    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
