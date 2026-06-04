class WebPortalDropdownOption {
  const WebPortalDropdownOption({
    required this.id,
    required this.label,
    this.bold = false,
  });

  final String id;
  final String label;
  final bool bold;

  static List<WebPortalDropdownOption> fromStrings(Iterable<String> items) {
    return [for (final s in items) WebPortalDropdownOption(id: s, label: s)];
  }
}
