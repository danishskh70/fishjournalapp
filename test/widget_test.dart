import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fish_journal/screens/auth_home.dart';

void main() {
  testWidgets('Fish Journal login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(onDone: _onDone),
      ),
    );

    expect(find.text('Fish Journal'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}

void _onDone() {}
