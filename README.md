# liquid_kit

`liquid_kit` is a small Flutter package for Liquid Glass-inspired UI chrome.
Today the public library exports:

- `LiquidGlassNavigationBar`
- `LiquidGlassButton`
- `LiquidGlassSearchBar`
- `LiquidGlassToolbar`
- `showLiquidGlassSheet(...)`
- `LiquidGlassTheme` and `LiquidGlassMode`
- `LiquidGlassGroup`
- exported animation and layout constants from `liquid_glass_physics.dart`

The controls are still opinionated building blocks rather than a general-purpose
glass container or shape system.

## Preview

![liquid_kit demo](https://raw.githubusercontent.com/nedbaynepowell/liquid-kit/main/assets/demo.gif)

## Installation

[![pub package](https://img.shields.io/pub/v/liquid_kit.svg)](https://pub.dev/packages/liquid_kit)
```bash
flutter pub add liquid_kit
```

No shader registration or extra setup is required.

## Package surface

The package is currently centered on a few polished controls and helpers:

- bottom navigation via `LiquidGlassNavigationBar`
- circular actions via `LiquidGlassButton`
- grouped shared-backdrop button chrome via `LiquidGlassGroup`
- top-bar search via `LiquidGlassSearchBar`
- compact action rows via `LiquidGlassToolbar`
- modal sheet presentation via `showLiquidGlassSheet(...)`
- shared defaults via `LiquidGlassTheme`

The demo app in `example/` uses the navigation bar, grouped buttons, toolbar,
search bar, and sheet together. If you are trying to understand what is
supported today, start there and treat `lib/liquid_kit.dart` as the source of
truth for the exported API.

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

The included demo app lives in `example/` and shows the current shipped pieces
working together over scrollable content.

```bash
cd example
flutter run
```

## Contributing

This repository is a single Flutter package plus the demo app in `example/`.
When you change package docs or examples, keep them aligned with
`lib/liquid_kit.dart`, `example/lib/main.dart`, and the current widget tests.

If you are contributing through Switchman, keep the workflow tight:

1. Acquire a lease for your assigned worktree.
2. Claim only the files you plan to edit before making changes.
3. Keep the patch scoped to those claimed files; if the scope expands, claim the
   additional files first.
4. Run the relevant Flutter checks for the area you touched, usually
   `flutter test`, and use the demo app in `example/` for visual validation.
5. Commit on your worktree branch, then mark the task done so Switchman can
   release the claims.
