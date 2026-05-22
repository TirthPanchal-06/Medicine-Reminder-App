import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medicine_reminder/main.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:medicine_reminder/providers/medication_provider.dart';
import 'package:medicine_reminder/providers/health_provider.dart';

void main() {
  testWidgets('App renders login screen initially', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => MedicationProvider()),
          ChangeNotifierProvider(create: (_) => HealthProvider()),
        ],
        child: const MedicineReminderApp(),
      ),
    );

    // Verify that login screen widgets are present
    expect(find.text('Sign In'), findsWidgets);
  });
}
