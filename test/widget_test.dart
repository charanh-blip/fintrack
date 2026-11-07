import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fintrack/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Fintrack application starts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FintrackApp());
    await tester.pumpAndSettle();
    expect(find.text('fintrack'), findsWidgets);
  });
}
