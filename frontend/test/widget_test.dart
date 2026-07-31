import 'package:flutter_test/flutter_test.dart';
import 'package:my_elysia_ai/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyElysiaAi());
    await tester.pump();
    expect(find.text('My Elysia AI'), findsWidgets);
  });
}
