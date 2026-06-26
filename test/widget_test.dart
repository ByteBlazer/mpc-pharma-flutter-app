import 'package:flutter_test/flutter_test.dart';

import 'package:mpc_pharma/main.dart';

void main() {
  testWidgets('renders hello world shell', (tester) async {
    await tester.pumpWidget(const MpcPharmaApp());

    expect(find.text('Hello World from MPC Pharma'), findsOneWidget);
    expect(find.text('Android, iOS, Web'), findsOneWidget);
  });
}
