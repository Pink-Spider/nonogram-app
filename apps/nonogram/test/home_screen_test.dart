import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonogram/app/app.dart';

import 'test_overrides.dart';

void main() {
  testWidgets('home screen renders difficulty choices', (tester) async {
    final overrides = await testOverrides();
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const NonogramApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Expert'), findsOneWidget);
    expect(find.text('Daily challenge'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.byType(FilledButton), findsWidgets);
  });
}
