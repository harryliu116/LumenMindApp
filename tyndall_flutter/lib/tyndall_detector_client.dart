import 'dart:typed_data';

export 'tyndall_detector_exception.dart';
import 'tyndall_detector_client_stub.dart'
  if (dart.library.js_interop) 'tyndall_detector_client_web.dart' as platform;

class TyndallDetectorClient {
  static Future<String> predict(Uint8List bytes, String filename) =>
      platform.predict(bytes);
}
