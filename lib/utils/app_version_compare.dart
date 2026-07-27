/// Parses a version name such as `1.2.0` into `[major, minor, patch]`.
List<int> parseAppVersionParts(String version) {
  final normalized = version.trim().split('+').first.trim();
  final segments = normalized.split('.');
  return [
    int.tryParse(segments.elementAtOrNull(0) ?? '0') ?? 0,
    int.tryParse(segments.elementAtOrNull(1) ?? '0') ?? 0,
    int.tryParse(segments.elementAtOrNull(2) ?? '0') ?? 0,
  ];
}

/// Returns true when [current] is strictly lower than [minimum] (semver name).
bool isAppVersionLowerThan(String current, String minimum) {
  final currentParts = parseAppVersionParts(current);
  final minimumParts = parseAppVersionParts(minimum);
  for (var index = 0; index < 3; index++) {
    if (currentParts[index] < minimumParts[index]) return true;
    if (currentParts[index] > minimumParts[index]) return false;
  }
  return false;
}
