import 'package:flutter_test/flutter_test.dart';
import 'package:psr3_app/main.dart';

void main() {
  testWidgets('PSR3 app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const Psr3App());

    expect(find.text('PSR3 Control Center'), findsOneWidget);
    expect(find.text('Mock Mode'), findsOneWidget);
  });
}
