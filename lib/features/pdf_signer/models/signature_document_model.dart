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
  double normalizedX; // 0.0 to 1.0 (relative to page)
  double normalizedY; // 0.0 to 1.0
  double scale;
  int pageNumber;
  final String verificationHash;

  PlacedSignature({
    required this.id,
    required this.signerName,
    required this.signerSurname,
    this.nationalId,
    required this.signedAt,
    required this.strokes,
    this.normalizedX = 0.55,
    this.normalizedY = 0.78,
    this.scale = 1.0,
    this.pageNumber = 1,
    String? verificationHash,
  }) : verificationHash = verificationHash ?? _generateHash(signerName, signerSurname, signedAt);

  String get fullName => '$signerName $signerSurname'.trim();

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
      'normalizedX': normalizedX,
      'normalizedY': normalizedY,
      'scale': scale,
      'pageNumber': pageNumber,
      'verificationHash': verificationHash,
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
      normalizedX: (json['normalizedX'] as num?)?.toDouble() ?? 0.55,
      normalizedY: (json['normalizedY'] as num?)?.toDouble() ?? 0.78,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      verificationHash: json['verificationHash'] as String?,
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
