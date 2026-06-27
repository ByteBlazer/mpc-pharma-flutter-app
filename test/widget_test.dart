import 'package:flutter_test/flutter_test.dart';

import 'package:mpc_pharma/main.dart';

void main() {
  testWidgets('renders greeting from API', (tester) async {
    await tester.pumpWidget(
      MpcPharmaApp(fetchGreeting: () async => 'Hello from API'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello from API'), findsOneWidget);
  });
}
