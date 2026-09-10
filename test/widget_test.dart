import 'package:flutter_test/flutter_test.dart';

import 'package:rentcollection/main.dart';

void main() {
  testWidgets('App launches to the chat list', (WidgetTester tester) async {
    await tester.pumpWidget(const RentCollectionApp());
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsWidgets);
  });
}
