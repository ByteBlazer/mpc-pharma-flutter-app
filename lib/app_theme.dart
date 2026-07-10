import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Change this one color to rebrand the app.
  static const brandColor = Color.fromARGB(255, 94, 134, 170);
  static final _snackBarBackgroundColor = HSLColor.fromColor(
    brandColor,
  ).withSaturation(0.35).withLightness(0.92).toColor();

  /// Icon glyphs on pale primary-tinted surfaces — deeper and more saturated
  /// than [brandColor] for readable contrast.
  static Color primaryGlyph(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withLightness((hsl.lightness - 0.14).clamp(0.26, 0.42))
        .withSaturation((hsl.saturation + 0.08).clamp(0.0, 1.0))
        .toColor();
  }

  /// Brand-colored text and links on light surfaces — darker and more saturated
  /// than [brandColor] for readable contrast on gradient pages.
  static Color primaryAccentText(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withLightness((hsl.lightness - 0.22).clamp(0.34, 0.48))
        .withSaturation((hsl.saturation + 0.16).clamp(0.0, 1.0))
        .toColor();
  }

  /// Pale card fill on gradient pages — brand hue blended into white, opaque
  /// enough to read above the page tint without pure-white glare.
  static Color gradientPageSurfaceFill(Color primary) {
    return Color.alphaBlend(primary.withValues(alpha: 0.16), Colors.white);
  }

  /// Card border on gradient pages — same hue as [primary], slightly subdued.
  static Color gradientPageSurfaceBorder(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withLightness((hsl.lightness - 0.10).clamp(0.52, 0.70))
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
        .toColor();
  }

  /// Shadow tint for gradient page surfaces.
  static Color gradientPageSurfaceShadow(Color primary) {
    return primary.withValues(alpha: 0.07);
  }

  /// Elevated surface for cards on gradient page backgrounds.
  static BoxDecoration gradientPageSurface(
    Color primary, {
    double borderRadius = 18,
  }) {
    return BoxDecoration(
      color: gradientPageSurfaceFill(primary),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: gradientPageSurfaceBorder(primary)),
      boxShadow: [
        BoxShadow(
          color: gradientPageSurfaceShadow(primary),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static ThemeData get theme {
    final accentTextColor = primaryAccentText(brandColor);

    const colorScheme = ColorScheme.light(
      primary: brandColor,
      onPrimary: Colors.white,
      secondary: brandColor,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      error: brandColor,
      onError: Colors.white,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: gradientPageSurfaceFill(brandColor),
        elevation: 0,
        shadowColor: gradientPageSurfaceShadow(brandColor),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: gradientPageSurfaceBorder(brandColor)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentTextColor,
          side: BorderSide(color: accentTextColor),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentTextColor),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _snackBarBackgroundColor,
        contentTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: accentTextColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return TextStyle(
              color: accentTextColor,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: Colors.black54);
        }),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandColor),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
