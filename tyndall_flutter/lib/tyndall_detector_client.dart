import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class DetectorApiException implements Exception {
  const DetectorApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

String parseDetectorOutput(String body, {int statusCode = 200}) {
  final payload = jsonDecode(body);
  if (payload is! Map<String, dynamic>) {
    throw const DetectorApiException(
      'The detector returned an invalid response.',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    throw DetectorApiException(
      payload['error'] as String? ?? 'The detector request failed.',
    );
  }
  final output = payload['output'];
  if (output is! String || output.isEmpty) {
    throw const DetectorApiException(
      'The detector returned no prediction output.',
    );
  }
  return output;
}

class TyndallDetectorClient {
  static const _endpoint = String.fromEnvironment(
    'TYNSAI_API_URL',
    defaultValue: 'http://127.0.0.1:8765/predict',
  );

  static Future<String> predict(Uint8List bytes, String filename) async {
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/octet-stream',
              'X-Filename': filename,
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 75));
      return parseDetectorOutput(
        response.body,
        statusCode: response.statusCode,
      );
    } on http.ClientException {
      throw DetectorApiException(detectorApiConnectionMessage(_endpoint));
    } on TimeoutException {
      throw DetectorApiException(
        'The TynsAI API timed out. Check that the detector service is running and reachable.',
      );
    }
  }
}

String detectorApiConnectionMessage(String endpoint) =>
    'Could not reach the TynsAI API at $endpoint. For a published HTTPS app, '
    'set TYNSAI_API_URL to the public HTTPS /predict endpoint. A 127.0.0.1 '
    'address points to each visitor’s own device. Allow the published site '
    'origin in the API CORS settings.';
