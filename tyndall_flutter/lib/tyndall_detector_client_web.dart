import 'dart:js_interop';
import 'dart:typed_data';

import 'tyndall_detector_exception.dart';

@JS('lumenMindTynsAi')
external _TynsaiWasmApi get _wasmApi;

@JS()
@staticInterop
class _TynsaiWasmApi {}

extension on _TynsaiWasmApi {
  external JSPromise<JSString> predict(JSUint8Array imageBytes);
}

Future<String> predict(Uint8List bytes) async {
  try {
    return (await _wasmApi.predict(bytes.toJS).toDart).toDart;
  } catch (error) {
    throw DetectorException('The embedded TynsAI detector failed: $error');
  }
}