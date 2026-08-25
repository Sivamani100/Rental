import 'package:flutter_test/flutter_test.dart';

import 'package:rental/main.dart';

void main() {
  testWidgets('Rental App Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RentalApp());
  });
}
