// liquid_glass_sheet.dart
//
// A draggable bottom sheet with the same glass pipeline as the other
// liquid_kit components.
//
// Architecture:
//   • Presented via showLiquidGlassSheet() which pushes a full-screen
//     transparent route so the sheet composites over whatever is behind it.
//   • Spring detents — snaps to half / full height (or custom stops) using
//     the same spring constants from liquid_glass_physics.dart.
//   • Drag handle — a frosted pill at the top edge. Dragging anywhere on the
//     sheet header also moves it.
//   • Rubber-band overshoot — dragging past the top detent stretches with
//     diminishing returns; releasing snaps back.
//   • Glass surface — BackdropFilter blur + tint + top specular line + rim,
//     consistent with toolbar and nav bar.
//   • Scrim — taps on the scrim dismiss the sheet (spring-out downward).
//   • No _SelectedPill, no iridescent border — this is a surface, not a button.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show Theme, Brightness, Colors, MaterialPageRoute, MaterialType, Material;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'liquid_glass_physics.dart';
import 'liquid_glass_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a [LiquidGlassSheet] as a modal route.
///
/// [detents] — fractional heights the sheet snaps to (0.0–1.0, relative to
/// screen height minus top safe area). Defaults to [0.5, 1.0].
///
/// Returns a Future that completes when the sheet is dismissed.
Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required Widget child,
  List<double> detents = const [0.5, 1.0],
  double initialDetent = 0.5,
  bool showDragHandle = true,
  bool isDismissible = true,
  double? blurSigma,
  bool? isDark,
}) {
  assert(detents.isNotEmpty);
  assert(detents.every((d) => d > 0.0 && d <= 1.0));
  assert(detents.contains(initialDetent),
  'initialDetent must be one of the detents values');

  return Navigator.of(context).push<T>(
    _LiquidSheetRoute<T>(
      child: child,
      detents: List<double>.from(detents)..sort(),
      initialDetent: initialDetent,
      showDragHandle: showDragHandle,
      isDismissible: isDismissible,
      blurSigma: blurSigma,
      isDark: isDark,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Route
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidSheetRoute<T> extends PageRoute<T> {
  _LiquidSheetRoute({
    required this.child,
    required this.detents,
    required this.initialDetent,
    required this.showDragHandle,
    required this.isDismissible,
    this.blurSigma,
    this.isDark,
  }) : super(fullscreenDialog: false);

  final Widget child;
  final List<double> detents;
  final double initialDetent;
  final bool showDragHandle;
  final bool isDismissible;
  final double? blurSigma;
  final bool? isDark;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  bool get barrierDismissible => false; // we handle tap ourselves

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return _LiquidSheetScaffold(
      route: this,
      animation: animation,
      child: child,
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // The sheet animates itself; we just return child directly.
    return child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scaffold — scrim + sheet positioning
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidSheetScaffold extends StatefulWidget {
  const _LiquidSheetScaffold({
    required this.route,
    required this.animation,
    required this.child,
  });

  final _LiquidSheetRoute route;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_LiquidSheetScaffold> createState() => _LiquidSheetScaffoldState();
}

class _LiquidSheetScaffoldState extends State<_LiquidSheetScaffold>
    with SingleTickerProviderStateMixin {

  late AnimationController _sheetCtrl;
  late SpringSimulation _spring;

  // Current sheet position as fraction of available height (0 = off-screen bottom)
  double _frac = 0.0;
  double _dragStartFrac = 0.0;
  double _dragStartDy = 0.0;
  bool _dismissed = false;

  double get _availableHeight {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.top;
  }

  List<double> get _detents => widget.route.detents;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Animate in from 0 → initialDetent on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _springTo(widget.route.initialDetent);
    });
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ── Spring helpers ────────────────────────────────────────────────────────

  void _springTo(double targetFrac, {double velocity = 0.0}) {
    final sim = SpringSimulation(
      SpringDescription(
        mass: 1.0,
        stiffness: 420.0,
        damping: 28.0,
      ),
      _frac,
      targetFrac,
      velocity,
    );
    _sheetCtrl.animateWith(sim);
    _sheetCtrl.addListener(() {
      if (mounted) setState(() => _frac = _sheetCtrl.value);
    });
  }

  double _nearestDetent(double frac) {
    return _detents.reduce((a, b) =>
    (a - frac).abs() < (b - frac).abs() ? a : b);
  }

  // ── Drag ──────────────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails d) {
    _sheetCtrl.stop();
    _dragStartFrac = _frac;
    _dragStartDy = d.globalPosition.dy;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dy = d.globalPosition.dy - _dragStartDy;
    final delta = -dy / _availableHeight;
    double target = _dragStartFrac + delta;

    final maxDetent = _detents.last;
    if (target > maxDetent) {
      // Rubber-band above top detent
      final over = target - maxDetent;
      target = maxDetent + over * 0.25;
    }

    setState(() => _frac = target.clamp(0.0, maxDetent + 0.15));
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = -d.primaryVelocity! / _availableHeight;

    // Fast flick down → dismiss
    if (d.primaryVelocity! > 800 && widget.route.isDismissible) {
      _dismiss(velocity: velocity);
      return;
    }

    // Fast flick up → snap to next detent above current
    if (d.primaryVelocity! < -600) {
      final above = _detents.where((det) => det > _frac).toList();
      final target = above.isNotEmpty ? above.first : _detents.last;
      _springTo(target, velocity: velocity);
      return;
    }

    // Otherwise snap to nearest detent
    final nearest = _nearestDetent(_frac);
    if (nearest < _detents.first * 0.4 && widget.route.isDismissible) {
      _dismiss(velocity: velocity);
    } else {
      _springTo(nearest, velocity: velocity);
    }
  }

  void _dismiss({double velocity = 0.0}) {
    if (_dismissed) return;
    _dismissed = true;
    HapticFeedback.lightImpact();
    _springTo(0.0, velocity: velocity);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final availH = _availableHeight;
    final sheetH = (_frac * availH).clamp(0.0, availH + 32.0);
    final scrimOpacity = (_frac / (_detents.last)).clamp(0.0, 1.0) * 0.45;

    return Stack(
      children: [
        // ── Scrim ──────────────────────────────────────────────────────────
        if (widget.route.isDismissible)
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismiss,
              child: ColoredBox(
                color: Color.fromRGBO(0, 0, 0, scrimOpacity),
              ),
            ),
          ),

        // ── Sheet ──────────────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: sheetH + mq.padding.bottom,
          child: GestureDetector(
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: _LiquidSheetSurface(
              showDragHandle: widget.route.showDragHandle,
              blurSigma: widget.route.blurSigma,
              isDark: widget.route.isDark,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass surface widget
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidSheetSurface extends StatelessWidget {
  const _LiquidSheetSurface({
    required this.child,
    required this.showDragHandle,
    this.blurSigma,
    this.isDark,
  });

  final Widget child;
  final bool showDragHandle;
  final double? blurSigma;
  final bool? isDark;

  static const double _cornerRadius = 22.0;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    final theme = LiquidGlassTheme.of(context);
    final blur = blurSigma ?? theme?.resolvedBlurSigma ?? kBlurSigma;
    final mq = MediaQuery.of(context);

    final rrect = BorderRadius.only(
      topLeft: const Radius.circular(_cornerRadius),
      topRight: const Radius.circular(_cornerRadius),
    );

    return Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: rrect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Blur ──────────────────────────────────────────────────────────
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),

              // ── Tint ──────────────────────────────────────────────────────────
              Positioned.fill(
                child: ColoredBox(
                  color: dark
                      ? const Color.fromRGBO(28, 28, 32, 0.72)
                      : const Color.fromRGBO(242, 242, 247, 0.80),
                ),
              ),

              // ── Top specular line + rim ────────────────────────────────────────
              Positioned.fill(
                child: CustomPaint(
                  painter: _SheetSurfacePainter(
                    isDark: dark,
                    radius: _cornerRadius,
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────────────
              Positioned.fill(
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: dark ? const Color(0xFFFFFFFF) : const Color(0xFF19181D),
                    decoration: TextDecoration.none,
                  ),
                  child: Column(
                    children: [
                      if (showDragHandle) _DragHandle(isDark: dark),
                      Expanded(
                        child: MediaQuery(
                          data: mq.copyWith(
                            padding: mq.padding.copyWith(top: 0),
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )); // ClipRRect + Material
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drag handle
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surface painter — top specular arc + rim
// ─────────────────────────────────────────────────────────────────────────────

class _SheetSurfacePainter extends CustomPainter {
  const _SheetSurfacePainter({
    required this.isDark,
    required this.radius,
  });

  final bool isDark;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // Top specular line — fades in from both corners across the straight top
    final specAlpha = isDark ? 0.38 : 0.55;
    final specRect = Rect.fromLTWH(radius, 0, size.width - radius * 2, 1.2);
    canvas.drawRect(
      specRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0x00FFFFFF),
            Color.fromRGBO(255, 255, 255, specAlpha),
            Color.fromRGBO(255, 255, 255, specAlpha),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.15, 0.85, 1.0],
        ).createShader(specRect),
    );

    // Corner specular arcs
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Color.fromRGBO(255, 255, 255, specAlpha * 0.7);

    // Top-left arc
    canvas.drawArc(
      Rect.fromLTWH(0, 0, radius * 2, radius * 2),
      math.pi,
      math.pi / 2,
      false,
      arcPaint,
    );
    // Top-right arc
    canvas.drawArc(
      Rect.fromLTWH(size.width - radius * 2, 0, radius * 2, radius * 2),
      math.pi * 1.5,
      math.pi / 2,
      false,
      arcPaint,
    );

    // Rim — top edge only (full perimeter would look like a card border)
    final rimAlpha = isDark ? 0.16 : 0.24;
    final rimPath = Path()
      ..moveTo(0, radius)
      ..arcToPoint(
        Offset(radius, 0),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: Radius.circular(radius),
      );

    canvas.drawPath(
      rimPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Color.fromRGBO(255, 255, 255, rimAlpha),
    );
  }

  @override
  bool shouldRepaint(_SheetSurfacePainter old) =>
      old.isDark != isDark || old.radius != radius;
}