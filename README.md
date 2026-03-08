# liquid_kit

`liquid_kit` is a small Flutter package for Liquid Glass-inspired UI chrome.
Today it ships:

- `LiquidGlassNavigationBar`
- `LiquidGlassButton`
- `LiquidGlassTheme` and `LiquidGlassMode`
- exported animation and layout constants from `liquid_glass_physics.dart`

It does not currently include a toolbar, search bar, or general shape primitives.

## Installation

```yaml
dependencies:
  liquid_kit: ^0.1.0
```

```bash
flutter pub get
```

No shader registration or extra setup is required.

## Navigation bar

`LiquidGlassNavigationBar` is a 2-5 tab bottom bar with spring motion, drag-to-select behavior, lift effects, and accessibility semantics.

```dart
LiquidGlassNavigationBar(
  tabs: const [
    LiquidGlassTab(icon: Icons.home_rounded, label: 'Home'),
    LiquidGlassTab(icon: Icons.explore_rounded, label: 'Explore'),
    LiquidGlassTab(icon: Icons.favorite_rounded, label: 'Activity'),
    LiquidGlassTab(icon: Icons.person_rounded, label: 'Profile'),
  ],
  currentIndex: currentIndex,
  onTabChanged: (index) => setState(() => currentIndex = index),
)
```

Supported options:

- `accentColor` overrides the active tab color.
- `blurSigma` tunes the backdrop blur strength.
- `springStiffness` and `springDamping` tune pill motion.
- `collapseOnScroll` and `scrollController` enable collapse behavior.
- `mode` selects `always`, `adaptive`, or `manual` rendering.

## Buttons

`LiquidGlassButton` renders a circular floating glass button with press lift and an iridescent edge effect.

```dart
LiquidGlassButton(
  onPressed: () {},
  child: const Icon(Icons.add_rounded),
)
```

Useful options:

- `size` changes the button diameter.
- `blurSigma` overrides the blur amount.
- `tintOpacity` controls how frosted or transparent the glass fill appears.
- `isDark` overrides theme brightness detection.

## Theming

Wrap part or all of your app in `LiquidGlassTheme` to share defaults:

```dart
LiquidGlassTheme(
  accentColor: const Color(0xFF007AFF),
  blurSigma: 20,
  springStiffness: 300,
  springDamping: 20,
  child: MyApp(),
)
```

`performanceMode` lowers blur strength for weaker devices. `mode` sets the default rendering policy for descendant liquid widgets.

## Physics constants

The package exports `liquid_glass_physics.dart`, so you can tune against the same values used internally:

```dart
const double kTabSwitchStiffness = 300.0;
const double kTabSwitchDamping = 20.0;
const Duration kLiftActivationDuration = Duration(milliseconds: 250);
const double kOuterPillHeight = 70.0;
```

## Example

The included demo app lives in `example/` and shows the floating buttons plus the navigation bar over scrollable content.
