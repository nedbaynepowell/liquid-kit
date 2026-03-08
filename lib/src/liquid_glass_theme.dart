// liquid_glass_theme.dart
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

/// Controls how liquid_kit renders across platforms.
enum LiquidGlassMode {
  /// Full Liquid Glass on all platforms (default).
  always,

  /// Liquid Glass on Apple platforms (iOS/macOS) and Web.
  /// Falls back to Material 3 styling on Android, Windows, and Linux.
  ///
  /// {@template liquid_kit.adaptive_experimental}
  /// **Experimental.** The Material 3 fallback path renders a standard
  /// [NavigationBar] with the same tab structure. The fallback appearance
  /// is intentionally unstyled in this release — future versions will add
  /// Material You theming. Do not rely on the fallback appearance being
  /// stable until this annotation is removed.
  /// {@endtemplate}
  @experimental
  adaptive,

  /// Developer controls rendering per-widget via the [mode] parameter.
  manual,
}

/// Returns true if Liquid Glass should render in [LiquidGlassMode.adaptive]
/// for the current platform.
bool liquidGlassAdaptiveShouldUseGlass() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return false;
    case TargetPlatform.fuchsia:
      return false;
  }
}

// ignore: deprecated_member_use — used only to annotate adaptive above.
const String experimental = 'experimental';

/// Inherited theme for liquid_kit — wrap your app root with this
/// to configure all glass widgets at once.
class LiquidGlassTheme extends InheritedWidget {
  const LiquidGlassTheme({
    super.key,
    required super.child,
    this.mode = LiquidGlassMode.always,
    this.accentColor,
    this.glassOpacity,
    this.blurSigma,
    this.springStiffness,
    this.springDamping,
    this.performanceMode = false,
  });

  final LiquidGlassMode mode;
  final Color? accentColor;

  /// Override default glass opacity (0.0–1.0). Default tuned per mode.
  final double? glassOpacity;

  /// Override blur sigma. Default 20. Lower = more transparent/performant.
  final double? blurSigma;

  final double? springStiffness;
  final double? springDamping;

  /// Reduces blur to 10 for lower-end devices
  final bool performanceMode;

  static LiquidGlassTheme? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LiquidGlassTheme>();
  }

  double get resolvedBlurSigma {
    if (performanceMode) return 10.0;
    return blurSigma ?? 20.0;
  }

  @override
  bool updateShouldNotify(LiquidGlassTheme oldWidget) {
    return mode != oldWidget.mode ||
        accentColor != oldWidget.accentColor ||
        glassOpacity != oldWidget.glassOpacity ||
        blurSigma != oldWidget.blurSigma ||
        springStiffness != oldWidget.springStiffness ||
        springDamping != oldWidget.springDamping ||
        performanceMode != oldWidget.performanceMode;
  }
}

/// Glass material colours for light and dark mode
class LiquidGlassMaterial {
  const LiquidGlassMaterial._();

  // Light mode
  static const Color outerPillLight = Color(0xB8FFFFFF); // ~72% white
  static const Color innerPillLight = Color(0xD9FFFFFF); // ~85% white
  static const Color borderLight = Color(0x0F000000); // ~6% black
  static const Color shadowLight = Color(0x0F000000);
  static const Color inactiveContentLight = Color(0x8C000000); // 55% black

  // Dark mode
  static const Color outerPillDark = Color(0xD02C2C2E); // charcoal 82%
  static const Color innerPillDark = Color(0xE6484848); // lighter charcoal 90%
  static const Color borderDark = Color(0x1AFFFFFF); // 10% white
  static const Color shadowDark = Color(0x66000000); // 40% black
  static const Color inactiveContentDark = Color(0x8CFFFFFF); // 55% white

  static Color outerPill(bool isDark) =>
      isDark ? outerPillDark : outerPillLight;

  static Color innerPill(bool isDark) =>
      isDark ? innerPillDark : innerPillLight;

  static Color border(bool isDark) => isDark ? borderDark : borderLight;

  static Color inactiveContent(bool isDark) =>
      isDark ? inactiveContentDark : inactiveContentLight;

  static Color activeContent(BuildContext context, Color? accent) {
    return accent ?? const Color(0xFF007AFF); // iOS blue default
  }
}
