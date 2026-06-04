import 'package:flutter_test/flutter_test.dart';
import 'package:mpc_pharma/config/app_constants.dart';
import 'package:mpc_pharma/core/utils/jwt_utils.dart';

void main() {
  test('UserType maps API role strings', () {
    expect(UserType.fromApiValue('app-admin'), UserType.appAdmin);
    expect(UserType.fromApiValue('app-trip-driver'), UserType.appTripDriver);
    expect(UserType.fromApiValue('unknown'), isNull);
  });

  test('JwtUtils rejects empty token', () {
    expect(JwtUtils.isValidToken(null), isFalse);
    expect(JwtUtils.isValidToken(''), isFalse);
  });
}
