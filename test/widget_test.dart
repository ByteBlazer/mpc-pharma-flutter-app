import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mpc_pharma/main.dart';

void main() {
  testWidgets('renders login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MpcPharmaApp());
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });
}
