import 'dart:typed_data';

import 'tyndall_detector_exception.dart';

Future<String> predict(Uint8List bytes) => throw const DetectorException(
  'The embedded TynsAI detector is currently available in the Flutter Web build.',
);