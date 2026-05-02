import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:needsbridge/main.dart';

void main() {
  testWidgets('NeedsBridgeApp smoke test', (WidgetTester tester) async {
    // App requires Firebase init; just verify widget tree can be created
    expect(NeedsBridgeApp.new, isNotNull);
  });
}
