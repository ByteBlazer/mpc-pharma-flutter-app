import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'web_portal_styles.dart';

/// MUI-aligned typography (Inter) for the web portal screens.
abstract final class WebPortalTheme {
  static const _outlineGrey = Color(0xFFBDBDBD);

  static ThemeData light() {
    final base = AppTheme.light();
    final inter = GoogleFonts.interTextTheme(base.textTheme);
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: _outlineGrey),
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: inter,
      primaryTextTheme: inter,
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: outlineBorder,
        focusedErrorBorder: outlineBorder,
        labelStyle: const TextStyle(
          fontSize: 14,
          color: WebPortalStyles.textSecondary,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.28,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          side: const BorderSide(color: _outlineGrey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
    );
  }

  /// MUI `Dialog` form fields — medium outlined, aligned with DOM dropdowns.
  static ThemeData dialogForm() {
    const outlineGrey = Color(0xFFBDBDBD);
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: outlineGrey),
    );
    final base = light();
    final fieldHeight = WebPortalStyles.dialogFormFieldHeight;
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: false,
        contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        constraints: BoxConstraints(
          minHeight: fieldHeight,
          maxHeight: fieldHeight,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: WebPortalStyles.dialogFormFloatingLabelStyle,
        floatingLabelStyle: WebPortalStyles.dialogFormFloatingLabelStyle,
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
