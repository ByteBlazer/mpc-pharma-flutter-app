import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// MUI-aligned colors and widgets for the web portal (React ui).
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

  /// MUI `TableHead` — bold column labels in React UI.
  static const usersTableHeaderStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xDE000000), // rgba(0,0,0,0.87)
  );

  /// MUI augmented `palette.primary.dark` / `primary.light`.
  static const usersPrimaryDark = Color(0xFF3A7A7E);
  static const usersPrimaryLight = Color(0xFF7AB3B6);

  /// MUI contained `Button` — uppercase label, hover darkens + slight elevation.
  static const usersAddUserLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.75,
    color: Colors.white,
  );

  /// MUI `DialogActions` text button — uppercase primary label.
  static const dialogActionTextLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.75,
    color: AppColors.primary,
  );

  /// MUI `DialogActions` contained button — uppercase white label.
  static const dialogActionContainedLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.75,
    color: Colors.white,
  );

  /// MUI `ToggleButton` `size="small"` label.
  static TextStyle usersRolesToggleLabelStyle({required bool selected}) =>
      TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        letterSpacing: 0.75,
      );

  /// MUI row `Edit` button label (`size="small"` contained).
  static const usersRowEditLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.75,
    color: Colors.white,
  );

  /// MUI `TableBody` cell text.
  static const usersTableCellStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xDE000000),
  );

  static const usersTableHeaderBg = Color(0xFFF5F5F5);
  static const usersTableHoverBg = Color(0xFFF5F5F5);

  /// Settings section title — MUI `Typography` `variant="h5"`.
  static const settingsSectionTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
    height: 1.2,
  );

  /// Settings section subtitle — MUI `body1` `text.secondary`.
  static const settingsSectionSubtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  /// Settings card title — MUI `Typography` `variant="h6"`.
  static const settingsCardTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
    height: 1.3,
  );

  /// Settings card body — MUI `body2` `text.secondary`.
  static const settingsBodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.43,
  );

  /// Small caption in settings dialogs.
  static const settingsCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  /// MUI `DialogContent` `gap: 2` between stacked fields.
  static const dialogFormFieldGap = 16.0;

  /// MUI inner `Box` `pt: 1` below dialog title.
  static const dialogFormContentTop = 8.0;

  /// Outlined dialog control height — shared by TextField and DOM dropdowns.
  static const dialogFormFieldHeight = 52.0;

  /// Notch label on dialog text fields — DOM dropdowns use 12px; Inter needs 13px
  /// to read the same size after Flutter scales labels in the shorter field slot.
  static const dialogFormFloatingLabelStyle = TextStyle(
    fontSize: 13,
    color: textSecondary,
    height: 1.2,
  );

  /// Fixed slot for dialog form fields (TextField siblings and DOM dropdowns).
  static Widget dialogFormFieldSlot({required Widget child}) => SizedBox(
        height: dialogFormFieldHeight,
        width: double.infinity,
        child: child,
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
  static Widget filterFieldSlot({required Widget child}) =>
      SizedBox(height: filterFieldHeight, width: double.infinity, child: child);

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
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  );

  static const _filterOutlineBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
    borderSide: BorderSide(color: borderColor),
  );

  static const _errorOutlineBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
    borderSide: BorderSide(color: errorMain),
  );

  static InputDecoration muiOutlinedField({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool error = false,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: filterInputConstraints,
        border: error ? _errorOutlineBorder : _filterOutlineBorder,
        enabledBorder: error ? _errorOutlineBorder : _filterOutlineBorder,
        focusedBorder: error
            ? _errorOutlineBorder
            : const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
        errorBorder: _errorOutlineBorder,
        focusedErrorBorder: _errorOutlineBorder,
      );

  static ButtonStyle deliveryReportClearButton() => OutlinedButton.styleFrom(
    foregroundColor: errorMain,
    iconColor: errorMain,
    side: const BorderSide(color: borderColor),
    visualDensity: VisualDensity.compact,
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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

/// MUI `Card`-style shadows — Material [elevation] is too faint on Flutter web.
abstract final class WebPortalCardShadows {
  static const standard = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  /// Settings cards on a white page — visible depth without a heavy outline.
  static const elevated = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];
}

/// White panel with light elevation (MUI `Paper` / `Card`).
class WebPortalPaper extends StatelessWidget {
  const WebPortalPaper({
    super.key,
    required this.child,
    this.padding,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Settings-style cards: explicit box shadow (renders reliably on web).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: elevated
            ? Border.all(color: WebPortalStyles.borderColor)
            : null,
        boxShadow: elevated
            ? WebPortalCardShadows.elevated
            : WebPortalCardShadows.standard,
      ),
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
