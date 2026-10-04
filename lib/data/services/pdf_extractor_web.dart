// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:typed_data';

/// Web implementation using Mozilla's pdf.js loaded in the browser
Future<String> extractTextWithPdfJsWeb(Uint8List bytes) async {
  try {
    if (!js.context.hasProperty('extractPdfTextFromBase64')) {
      return '';
    }

    final b64 = base64Encode(bytes);
    final completer = Completer<String>();

    final promise = js.context.callMethod('extractPdfTextFromBase64', [b64]);
    if (promise == null) return '';

    promise.callMethod('then', [
      (dynamic result) {
        if (!completer.isCompleted) {
          completer.complete(result?.toString() ?? '');
        }
      },
      (dynamic error) {
        if (!completer.isCompleted) {
          completer.complete('');
        }
      },
    ]);

    return await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => '',
    );
  } catch (e) {
    return '';
  }
}
