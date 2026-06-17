import 'package:flutter_test/flutter_test.dart';
import 'package:demugo_ai/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DemugoApp());
    await tester.pump();
    expect(find.text('Demugo AI'), findsWidgets);
  });
}
