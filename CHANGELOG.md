## 0.1.8
- Add LiquidGlassToolbar — compact pill of icon actions with press/lift animations
- Add LiquidGlassSearchBar — scroll-hide, focus slide-to-top, animated X button
- Remove selected state from LiquidGlassToolbar (action-oriented, not navigation)
- Fix toolbar layout crash (infinite width constraint from StackFit.expand)
- Fix toolbar icons invisible (blur layer was rendering above glass surface)
- Fix top-bar and nav-bar layout crash (AnimatedSlide inside unsized Positioned)

## 0.1.7
- Simplify example app

## 0.1.6
- Fix navigation bar not returning to selected state after long-press release
- Fix backdrop blur disappearing during long-press lift
- Sync pop animations to fire simultaneously on long-press activation
- Increase tab switch spring speed (stiffness 420, damping 28)
- Improve LiquidGlassButton gel edge with circular lens refraction

## 0.1.5
- (previous changes)

## 0.1.4
- Polish package description and documentation
- Export liquid_glass_physics.dart from public API
- Fix README installation instructions

## 0.1.3
- Fix demo GIF URL for pub.dev
- Update README

## 0.1.2
- Fix adaptive mode fallback to Material NavigationBar on Android
- Add widget tests

## 0.1.1
- Initial release fixes

## 0.1.0
- Initial release
- LiquidGlassNavigationBar with spring physics
- LiquidGlassButton with lift animations