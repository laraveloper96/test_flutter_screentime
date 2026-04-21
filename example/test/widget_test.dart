import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_control_parental_example/main.dart';

void main() {
  testWidgets('renders example controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('flutter_control_parental example'), findsOneWidget);
    expect(find.text('Request authorization'), findsOneWidget);
    expect(find.text('Start blocking'), findsOneWidget);
  });
}
