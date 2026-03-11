import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:carbtune/main.dart';
import 'package:carbtune/providers/app_state.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const CarbTuneApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
