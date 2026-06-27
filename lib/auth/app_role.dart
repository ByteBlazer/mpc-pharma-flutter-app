enum AppRole {
  webAccess('web-access', 'Web Access'),
  appScanner('app-scanner', 'Scanner'),
  appTripCreator('app-trip-creator', 'Trip Creator'),
  appAdmin('app-admin', 'Admin'),
  appTripDriver('app-trip-driver', 'Trip Driver');

  const AppRole(this.tokenValue, this.label);

  // If the backend changes a role spelling, update only this value.
  final String tokenValue;
  final String label;

  static AppRole? fromTokenValue(String value) {
    final normalizedValue = value.trim();
    for (final role in values) {
      if (role.tokenValue == normalizedValue) return role;
    }
    return null;
  }
}

extension AppRoleListParsing on Iterable<String> {
  List<AppRole> toAppRoles() {
    return map(
      AppRole.fromTokenValue,
    ).whereType<AppRole>().toSet().toList(growable: false);
  }
}

extension AppRoleChecks on Iterable<AppRole> {
  bool hasRole(AppRole role) => contains(role);
}
