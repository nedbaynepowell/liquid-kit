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

/// Legacy annotation constant used for the experimental adaptive mode.
// ignore: deprecated_member_use
const String experimental = 'experimental';

/// Inherited theme for liquid_kit — wrap your app root with this
/// to configure all glass widgets at once.
class LiquidGlassTheme extends InheritedWidget {
  /// Creates a theme that configures the default liquid glass look and motion.
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

  /// Chooses when liquid glass widgets render their glass treatment.
  final LiquidGlassMode mode;

  /// Accent color used by widgets that expose an active state.
  final Color? accentColor;

  /// Override default glass opacity (0.0–1.0). Default tuned per mode.
  final double? glassOpacity;

  /// Override blur sigma. Default 20. Lower = more transparent/performant.
  final double? blurSigma;

  /// Overrides the spring stiffness used by animated glass components.
  final double? springStiffness;

  /// Overrides the spring damping used by animated glass components.
  final double? springDamping;

  /// Reduces blur intensity for lower-end devices.
  final bool performanceMode;

  /// Returns the nearest [LiquidGlassTheme] in the widget tree, if any.
  static LiquidGlassTheme? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LiquidGlassTheme>();
  }

  /// Resolves the blur sigma after applying performance-mode defaults.
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

  /// Outer fill color for glass surfaces in light mode.
  static const Color outerPillLight = Color(0xB8FFFFFF); // ~72% white

  /// Inner fill color for glass surfaces in light mode.
  static const Color innerPillLight = Color(0xD9FFFFFF); // ~85% white

  /// Border color for glass surfaces in light mode.
  static const Color borderLight = Color(0x0F000000); // ~6% black

  /// Shadow color for glass surfaces in light mode.
  static const Color shadowLight = Color(0x0F000000);

  /// Default inactive content color in light mode.
  static const Color inactiveContentLight = Color(0x8C000000); // 55% black

  /// Outer fill color for glass surfaces in dark mode.
  static const Color outerPillDark = Color(0xD02C2C2E); // charcoal 82%

  /// Inner fill color for glass surfaces in dark mode.
  static const Color innerPillDark = Color(0xE6484848); // lighter charcoal 90%

  /// Border color for glass surfaces in dark mode.
  static const Color borderDark = Color(0x1AFFFFFF); // 10% white

  /// Shadow color for glass surfaces in dark mode.
  static const Color shadowDark = Color(0x66000000); // 40% black

  /// Default inactive content color in dark mode.
  static const Color inactiveContentDark = Color(0x8CFFFFFF); // 55% white

  /// Returns the outer fill color for the current brightness.
  static Color outerPill(bool isDark) =>
      isDark ? outerPillDark : outerPillLight;

  /// Returns the inner fill color for the current brightness.
  static Color innerPill(bool isDark) =>
      isDark ? innerPillDark : innerPillLight;

  /// Returns the border color for the current brightness.
  static Color border(bool isDark) => isDark ? borderDark : borderLight;

  /// Returns the default inactive content color for the current brightness.
  static Color inactiveContent(bool isDark) =>
      isDark ? inactiveContentDark : inactiveContentLight;

  /// Returns the active content color, defaulting to the platform blue tint.
  static Color activeContent(BuildContext context, Color? accent) {
    return accent ?? const Color(0xFF007AFF); // iOS blue default
  }
}
