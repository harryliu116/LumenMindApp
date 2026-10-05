// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_mind/light_chaser.dart';
import 'package:lumen_mind/tyndall_app.dart';
import 'package:lumen_mind/tyndall_detector_client.dart';

void main() {
  testWidgets('shows LumenMind sessions and the TynsAI workflow', (
    tester,
  ) async {
    await tester.pumpWidget(const LumenMindApp());
    expect(find.text('LUMENMIND'), findsOneWidget);
    expect(find.text('TynsAI'), findsNWidgets(2));
    expect(find.text('LightChaser'), findsOneWidget);
    expect(
      find.text(
        'Detecting mass concentration from water and air through Tyndall Effect.',
      ),
      findsOneWidget,
    );
    expect(find.text('Upload a Tyndall or light-beam image'), findsOneWidget);
    expect(find.text('EXISTING C++ DETECTOR'), findsNothing);
    expect(find.text('EXISTING MODEL'), findsNothing);
    expect(
      find.textContaining('Detector estimates may not be accurate.'),
      findsOneWidget,
    );
    expect(find.text('Detector output'), findsOneWidget);

    await tester.tap(find.text('LightChaser'));
    await tester.pumpAndSettle();
    expect(
      find.text('Weather signals point to places worth exploring.'),
      findsOneWidget,
    );
    expect(find.text('LightChaser'), findsNWidgets(2));
    expect(find.text('Chase the light.'), findsNothing);
  });

  test('preserves the detector output text exactly', () {
    const output =
        '\nPrediction Result\n'
        'Predicted Mass Percentage: 0.58535%\n'
        'Image-only prediction (no sensor data)\n';
    expect(parseDetectorOutput(jsonEncode({'output': output})), output);
  });

  test('surfaces detector service errors', () {
    expect(
      () => parseDetectorOutput(
        '{"error":"Detector unavailable."}',
        statusCode: 500,
      ),
      throwsA(isA<DetectorApiException>()),
    );
  });

  test('explains how to configure a published detector endpoint', () {
    final message = detectorApiConnectionMessage(
      'http://127.0.0.1:8765/predict',
    );
    expect(message, contains('public HTTPS /predict endpoint'));
    expect(message, contains("each visitor’s own device"));
    expect(message, contains('CORS'));
  });

  test('ranks humid near-saturation conditions above dry clear conditions', () {
    final humid = weatherOpportunityScore(
      humidity: 92,
      temperature: 12,
      dewPoint: 10,
      visibility: 1500,
    );
    final dry = weatherOpportunityScore(
      humidity: 35,
      temperature: 24,
      dewPoint: 8,
      visibility: 12000,
    );
    expect(humid, greaterThan(dry));
    expect(humid, inInclusiveRange(0, 100));
    expect(dry, inInclusiveRange(0, 100));
  });
}
