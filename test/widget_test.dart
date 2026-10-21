import 'package:flutter_test/flutter_test.dart';
import 'package:psr3_app/main.dart';

void main() {
  testWidgets('PSR3 start screen shows both connection methods',
      (WidgetTester tester) async {
    await tester.pumpWidget(const Psr3App());

    expect(find.text('Connect your console'), findsOneWidget);
    expect(find.text('ESP32'), findsOneWidget);
    expect(find.text('Remote Play'), findsOneWidget);
    expect(find.text('Connect to ESP32'), findsOneWidget);
    expect(find.text('Use Remote Play'), findsOneWidget);
  });
}
