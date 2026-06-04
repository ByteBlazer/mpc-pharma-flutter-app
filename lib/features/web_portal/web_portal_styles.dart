import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// MUI-aligned colors and widgets for the web portal (React pharma-tracker-ui).
abstract final class WebPortalStyles {
  static const borderColor = Color(0xFFE0E0E0);
  static const warning = Color(0xFFED6C02);
  /// MUI default `palette.error.main`.
  static const errorMain = Color(0xFFD32F2F);
  static const textSecondary = Color(0xFF757575);
  static const chipDefaultBg = Color(0xFFE0E0E0);
  static const chipDefaultFg = Color(0xFF616161);

  /// Selected trip card background (MUI `primary.light` + alpha suffix `20`).
  static Color get selectedTripCardBg =>
      AppColors.primary.withValues(alpha: 0.12);

  static TextStyle pageTitle(BuildContext context) => TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        color: AppColors.primary,
        height: 1.2,
      );

  static TextStyle sectionTitle(BuildContext context) => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      );

  static ButtonStyle outlinedPrimaryButton() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  /// Trip card expanded section — MUI `Button` outlined error small fullWidth.
  /// Delivery report filter panel title (MUI `h3` ~1.1rem).
  static const filterSectionTitle = TextStyle(
    fontSize: 17.6,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    height: 1.2,
  );

  /// MUI `h5` page title inside report drill-down.
  static const reportPageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
    height: 1.2,
  );

  /// MUI `Button` size="small" in filter grid (matches outlined field ~40px).
  static const filterButtonHeight = 40.0;

  /// Outlined filter control height (label + 40px box) — keeps grid rows aligned.
  static const filterFieldHeight = 56.0;

  /// Minimum input area inside the outline (matches DOM 40px trigger).
  static const filterInputConstraints = BoxConstraints(minHeight: 40);

  /// Every filter grid control occupies the same slot.
  static Widget filterFieldSlot({required Widget child}) => SizedBox(
        height: filterFieldHeight,
        width: double.infinity,
        child: child,
      );

  static ButtonStyle filterGridFilledButton() => FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, filterButtonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.28,
        ),
      );

  static ButtonStyle filterGridOutlinedButton() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        iconColor: AppColors.primary,
        minimumSize: const Size(0, filterButtonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: const BorderSide(color: borderColor),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );

  static const _filterOutlineBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
    borderSide: BorderSide(color: borderColor),
  );

  static InputDecoration muiOutlinedField({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: filterInputConstraints,
        border: _filterOutlineBorder,
        enabledBorder: _filterOutlineBorder,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  static ButtonStyle deliveryReportClearButton() => OutlinedButton.styleFrom(
        foregroundColor: errorMain,
        iconColor: errorMain,
        side: const BorderSide(color: borderColor),
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );

  static ButtonStyle forceEndTripOutlinedButton() => OutlinedButton.styleFrom(
        foregroundColor: errorMain,
        iconColor: errorMain,
        side: const BorderSide(color: errorMain),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        minimumSize: const Size(double.infinity, 30),
        iconSize: 20,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.28,
        ),
      );
}

/// White panel with light elevation (MUI `Paper`).
class WebPortalPaper extends StatelessWidget {
  const WebPortalPaper({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// Underlined primary link (MUI `Typography` body2 + primary).
class WebPortalLinkText extends StatelessWidget {
  const WebPortalLinkText({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// MUI `Chip` with icon — primary / warning / default by trip status.
class WebPortalTripStatusChip extends StatelessWidget {
  const WebPortalTripStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  (Color bg, Color fg, IconData icon) _styleFor(String status) {
    switch (status) {
      case 'STARTED':
        return (AppColors.primary, Colors.white, Icons.check_circle);
      case 'SCHEDULED':
        return (WebPortalStyles.warning, Colors.white, Icons.schedule);
      case 'ENDED':
        return (
          WebPortalStyles.chipDefaultBg,
          WebPortalStyles.chipDefaultFg,
          Icons.cancel,
        );
      default:
        return (
          WebPortalStyles.chipDefaultBg,
          WebPortalStyles.chipDefaultFg,
          Icons.warning_amber,
        );
    }
  }
}
