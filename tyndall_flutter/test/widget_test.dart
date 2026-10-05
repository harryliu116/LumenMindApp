// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:lumen_mind/light_chaser.dart';
import 'package:lumen_mind/tyndall_app.dart';

void main() {
  testWidgets('shows LumenMind sessions and the TynsAI workflow', (tester) async {
    await tester.pumpWidget(const LumenMindApp());
    expect(find.text('LUMENMIND'), findsOneWidget);
    expect(find.text('TynsAI'), findsNWidgets(2));
    expect(find.text('Light Chaser'), findsOneWidget);
    expect(find.text('Add a Tyndall or light-beam image'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Air'), findsOneWidget);
    expect(find.text('NOT CALIBRATED'), findsOneWidget);
  });

  test('computes image features from an encoded image', () {
    final image = img.Image(width: 4, height: 4);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final value = (x + y).isEven ? 0 : 255;
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    final result = OpticalAnalysis.fromBytes(img.encodePng(image));
    expect(result.width, 4);
    expect(result.height, 4);
    expect(result.scatterIndex, greaterThan(0));
    expect(result.scatterIndex, lessThanOrEqualTo(100));
  });

  test('maps the blank and standard to their known concentrations', () {
    expect(
      estimateConcentration(
        currentIndex: 15,
        blankIndex: 5,
        standardIndex: 25,
        standardConcentration: 40,
      ),
      20,
    );
    expect(
      estimateConcentration(
        currentIndex: 10,
        blankIndex: 5,
        standardIndex: 5,
        standardConcentration: 40,
      ),
      isNull,
    );
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
