import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class SignatureStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const SignatureStroke({
    required this.points,
    required this.color,
    this.strokeWidth = 3.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }

  factory SignatureStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List<dynamic>?) ?? [];
    final pts = rawPoints.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList();
    return SignatureStroke(
      points: pts,
      color: Color(json['color'] as int? ?? 0xFF1D4ED8),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
    );
  }
}

class PlacedSignature {
  final String id;
  final String signerName;
  final String signerSurname;
  final String? nationalId;
  final DateTime signedAt;
  final List<SignatureStroke> strokes;
  final Uint8List? imageBytes;
  double normalizedX; // 0.0 to 1.0 (relative to page)
  double normalizedY; // 0.0 to 1.0
  double scale;
  int pageNumber;
  final String verificationHash;

  final String? userId;

  PlacedSignature({
    required this.id,
    required this.signerName,
    required this.signerSurname,
    this.nationalId,
    required this.signedAt,
    this.strokes = const [],
    this.imageBytes,
    this.normalizedX = 0.55,
    this.normalizedY = 0.78,
    this.scale = 1.0,
    this.pageNumber = 1,
    String? verificationHash,
    this.userId,
  }) : verificationHash = verificationHash ?? _generateHash(signerName, signerSurname, signedAt);

  String get fullName => '$signerName $signerSurname'.trim();

  PlacedSignature copyWith({
    String? id,
    String? signerName,
    String? signerSurname,
    String? nationalId,
    DateTime? signedAt,
    List<SignatureStroke>? strokes,
    Uint8List? imageBytes,
    double? normalizedX,
    double? normalizedY,
    double? scale,
    int? pageNumber,
    String? verificationHash,
    String? userId,
  }) {
    return PlacedSignature(
      id: id ?? this.id,
      signerName: signerName ?? this.signerName,
      signerSurname: signerSurname ?? this.signerSurname,
      nationalId: nationalId ?? this.nationalId,
      signedAt: signedAt ?? this.signedAt,
      strokes: strokes ?? this.strokes,
      imageBytes: imageBytes ?? this.imageBytes,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      scale: scale ?? this.scale,
      pageNumber: pageNumber ?? this.pageNumber,
      verificationHash: verificationHash ??
          (signerName != null || signerSurname != null || signedAt != null
              ? _generateHash(signerName ?? this.signerName, signerSurname ?? this.signerSurname, signedAt ?? this.signedAt)
              : this.verificationHash),
      userId: userId ?? this.userId,
    );
  }

  static String _generateHash(String name, String surname, DateTime dt) {
    final raw = '$name-$surname-${dt.millisecondsSinceEpoch}-sanctuary-sig';
    final bytes = utf8.encode(raw);
    var h = 0x811c9dc5;
    for (var b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return 'SEC-${h.toRadixString(16).toUpperCase().padLeft(8, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'signerName': signerName,
      'signerSurname': signerSurname,
      'nationalId': nationalId,
      'signedAt': signedAt.toIso8601String(),
      'strokes': strokes.map((s) => s.toJson()).toList(),
      if (imageBytes != null) 'imageBytes': base64Encode(imageBytes!),
      'normalizedX': normalizedX,
      'normalizedY': normalizedY,
      'scale': scale,
      'pageNumber': pageNumber,
      'verificationHash': verificationHash,
      if (userId != null) 'userId': userId,
    };
  }

  factory PlacedSignature.fromJson(Map<String, dynamic> json) {
    return PlacedSignature(
      id: json['id'] as String,
      signerName: json['signerName'] as String? ?? '',
      signerSurname: json['signerSurname'] as String? ?? '',
      nationalId: json['nationalId'] as String?,
      signedAt: DateTime.tryParse(json['signedAt'] as String? ?? '') ?? DateTime.now(),
      strokes: ((json['strokes'] as List<dynamic>?) ?? [])
          .map((s) => SignatureStroke.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      imageBytes: json['imageBytes'] != null ? base64Decode(json['imageBytes'] as String) : null,
      normalizedX: (json['normalizedX'] as num?)?.toDouble() ?? 0.55,
      normalizedY: (json['normalizedY'] as num?)?.toDouble() ?? 0.78,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      verificationHash: json['verificationHash'] as String?,
      userId: json['userId'] as String?,
    );
  }
}

class SignerNotification {
  final String id;
  final String signerName;
  final DateTime timestamp;
  final String message;

  const SignerNotification({
    required this.id,
    required this.signerName,
    required this.timestamp,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'signerName': signerName,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }

  factory SignerNotification.fromJson(Map<String, dynamic> json) {
    return SignerNotification(
      id: json['id'] as String? ?? 'notif-${DateTime.now().millisecondsSinceEpoch}',
      signerName: json['signerName'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      message: json['message'] as String? ?? '',
    );
  }
}

class PdfSignerDocument {
  final String id;
  final String title;
  final String fileName;
  final Uint8List? pdfBytes;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<PlacedSignature> signatures;
  final List<SignerNotification> notifications;
  final String shareToken;

  PdfSignerDocument({
    required this.id,
    required this.title,
    required this.fileName,
    this.pdfBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PlacedSignature>? signatures,
    List<SignerNotification>? notifications,
    String? shareToken,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        signatures = signatures ?? [],
        notifications = notifications ?? [],
        shareToken = shareToken ?? 'tok-${DateTime.now().millisecondsSinceEpoch}';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'fileName': fileName,
      if (pdfBytes != null) 'pdfBase64': base64Encode(pdfBytes!),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'signatures': signatures.map((s) => s.toJson()).toList(),
      'notifications': notifications.map((n) => n.toJson()).toList(),
      'shareToken': shareToken,
    };
  }

  factory PdfSignerDocument.fromJson(Map<String, dynamic> json) {
    Uint8List? bytes;
    if (json['pdfBase64'] != null && (json['pdfBase64'] as String).isNotEmpty) {
      try {
        bytes = base64Decode(json['pdfBase64'] as String);
      } catch (_) {}
    }
    return PdfSignerDocument(
      id: json['id'] as String? ?? 'doc-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Documento sin título',
      fileName: json['fileName'] as String? ?? 'documento.pdf',
      pdfBytes: bytes,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      signatures: ((json['signatures'] as List<dynamic>?) ?? [])
          .map((s) => PlacedSignature.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      notifications: ((json['notifications'] as List<dynamic>?) ?? [])
          .map((n) => SignerNotification.fromJson(Map<String, dynamic>.from(n as Map)))
          .toList(),
      shareToken: json['shareToken'] as String?,
    );
  }

  PdfSignerDocument copyWith({
    String? id,
    String? title,
    String? fileName,
    Uint8List? pdfBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PlacedSignature>? signatures,
    List<SignerNotification>? notifications,
    String? shareToken,
  }) {
    return PdfSignerDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      pdfBytes: pdfBytes ?? this.pdfBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      signatures: signatures ?? this.signatures,
      notifications: notifications ?? this.notifications,
      shareToken: shareToken ?? this.shareToken,
    );
  }
}
