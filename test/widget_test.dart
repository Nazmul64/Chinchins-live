import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinchins_live/main.dart';

class _TestHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChinchinsLiveApp());
    expect(find.text('Hot'), findsOneWidget);
  });
}
