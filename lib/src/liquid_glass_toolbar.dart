// liquid_glass_toolbar.dart
//
// A compact pill-shaped toolbar containing labelled icon actions.
// Same glass pipeline as LiquidGlassButton:
//   • shared blur, tint, top specular arc, rim stroke
//   • press: scale pop + darken
//   • long-press: lift + iridescent sweep (same as button & nav bar)
//   • selected item gets an inner frosted pill highlight

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show Theme, Brightness, Colors, Icons, IconData;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'liquid_glass_physics.dart';
import 'liquid_glass_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Item model
// ─────────────────────────────────────────────────────────────────────────────

class LiquidGlassToolbarItem {
  const LiquidGlassToolbarItem({
    required this.icon,
    this.label,
    this.semanticLabel,
  });

  final IconData icon;
  final String?  label;
  final String?  semanticLabel;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class LiquidGlassToolbar extends StatefulWidget {
  const LiquidGlassToolbar({
    super.key,
    required this.items,
    this.onItemTapped,
    this.height = 44.0,
    this.itemWidth,
    this.blurSigma,
    this.isDark,
  }) : assert(items.length >= 1 && items.length <= 6,
  'LiquidGlassToolbar supports 1–6 items');

  final List<LiquidGlassToolbarItem> items;
  final ValueChanged<int>?            onItemTapped;
  final double                        height;
  /// Width of each item slot. Defaults to [height] * 1.8.
  final double?                       itemWidth;
  final double?                       blurSigma;
  final bool?                         isDark;

  @override
  State<LiquidGlassToolbar> createState() => _LiquidGlassToolbarState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidGlassToolbarState extends State<LiquidGlassToolbar>
    with TickerProviderStateMixin {

  // Outer pill press / lift
  late AnimationController _pressCtrl;
  late Animation<double>   _pressT;
  late AnimationController _liftCtrl;
  late AnimationController _expandCtrl;
  late Animation<double>   _expandT;
  late AnimationController _iridCtrl;
  late AnimationController _iridOpacityCtrl;

  bool   _isLongPressed = false;
  Timer? _longPressTimer;
  int?   _pressedIndex;

  @override
  void initState() {
    super.initState();

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      reverseDuration: const Duration(milliseconds: 400),
    );
    _pressT = CurvedAnimation(
      parent: _pressCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.elasticOut,
    );

    _liftCtrl = AnimationController(
      vsync: this,
      duration: kLiftActivationDuration,
      reverseDuration: const Duration(milliseconds: 300),
    );
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _expandT = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _iridCtrl = AnimationController(
      vsync: this,
      duration: kIridescentRotationDuration,
    );
    _iridOpacityCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _pressCtrl.dispose();
    _liftCtrl.dispose();
    _expandCtrl.dispose();
    _iridCtrl.dispose();
    _iridOpacityCtrl.dispose();
    super.dispose();
  }

  // ── Pointer / press ────────────────────────────────────────────────────────

  void _onItemPointerDown(int index) {
    setState(() => _pressedIndex = index);
    _pressCtrl.forward(from: 0.0);
    HapticFeedback.lightImpact();
    _longPressTimer?.cancel();
    _longPressTimer = Timer(
      const Duration(milliseconds: 400),
          () => _activateLongPress(index),
    );
  }

  void _onItemPointerUp(int index) {
    _longPressTimer?.cancel();
    if (_isLongPressed) {
      _deactivateLongPress();
    } else {
      _pressCtrl.reverse();
      HapticFeedback.selectionClick();
      widget.onItemTapped?.call(index);
    }
    setState(() => _pressedIndex = null);
  }

  void _onItemPointerCancel() {
    _longPressTimer?.cancel();
    if (_isLongPressed) {
      _deactivateLongPress();
    } else {
      _pressCtrl.reverse(from: 1.0);
    }
    setState(() => _pressedIndex = null);
  }

  void _activateLongPress(int index) {
    if (!mounted) return;
    _expandCtrl.forward(from: 0.0);
    _liftCtrl.forward(from: 0.0);
    _iridCtrl.repeat();
    _iridOpacityCtrl.forward(from: 0.0);
    HapticFeedback.mediumImpact();
    setState(() => _isLongPressed = true);
  }

  void _deactivateLongPress() {
    if (!_isLongPressed) return;
    setState(() => _isLongPressed = false);
    _pressCtrl.reverse(from: 1.0);
    _liftCtrl.reverse();
    _expandCtrl.reverse();
    _iridOpacityCtrl.reverse().then((_) {
      if (mounted) { _iridCtrl.stop(); _iridCtrl.reset(); }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark ?? Theme.of(context).brightness == Brightness.dark;
    final theme   = LiquidGlassTheme.of(context);
    final blur    = widget.blurSigma ?? theme?.resolvedBlurSigma ?? kBlurSigma;
    final count   = widget.items.length;
    final hasLabels = widget.items.any((i) => i.label != null);
    final pillH   = hasLabels ? widget.height * 1.55 : widget.height;
    final radius  = pillH / 2;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_pressCtrl, _liftCtrl, _expandCtrl, _iridOpacityCtrl, _iridCtrl]),
      builder: (context, _) {
        final p        = _pressT.value;
        final liftT    = _liftCtrl.value;
        final expandT  = _expandT.value;
        final iridOp    = _iridOpacityCtrl.value;
        final iridAngle = _iridCtrl.value * 2 * math.pi;

        final scale = _isLongPressed
            ? 1.0 + expandT * 0.08
            : 1.0 + p * 0.04; // subtle — toolbar is wide, big scale looks wrong

        final shadowOpacity = isDark ? 0.08 + liftT * 0.30 : 0.0;

        // Glass surface is the non-positioned child that sizes the Stack.
        // Blur and shadow are Positioned.fill on top of it.
        final slotW = widget.itemWidth ?? widget.height * 1.8;
        final totalWidth = slotW * count;

        return Transform.scale(
          scale: scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Blur (behind glass surface) ──────────────────────
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

              // ── Glass surface (sizes the outer stack) ────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: totalWidth,
                  height: pillH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Tint
                      ColoredBox(
                        color: isDark
                            ? Color.fromRGBO(255, 255, 255,
                            0.08 + p * 0.04 + liftT * 0.06)
                            : Color.fromRGBO(255, 255, 255,
                            0.22 + p * 0.04 + liftT * 0.05),
                      ),

                      // Press darken
                      if (p > 0.01)
                        ColoredBox(color: Color.fromRGBO(0, 0, 0, p * 0.06)),

                      // Surface specular + rim
                      CustomPaint(
                        painter: _ToolbarSurfacePainter(
                          isDark: isDark,
                          pressT: p,
                          liftT: liftT,
                          radius: radius,
                        ),
                      ),

                      // Iridescent border on lift
                      if (iridOp > 0.01)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _ToolbarIridPainter(
                              iridOpacity: iridOp,
                              iridAngle: iridAngle,
                              radius: radius,
                            ),
                          ),
                        ),

                      // ── Items row ───────────────────────────────────
                      LayoutBuilder(builder: (context, constraints) {
                        return Stack(
                          children: [
                            // Item tap targets + icons
                            Row(
                              children: List.generate(count, (i) {
                                final item      = widget.items[i];
                                final iconAlpha = isDark ? 0.75 : 0.60;
                                final iconColor = isDark
                                    ? Colors.white.withValues(alpha: iconAlpha)
                                    : const Color(0xFF19181D).withValues(alpha: iconAlpha);

                                return Expanded(
                                  child: Listener(
                                    onPointerDown: (_) => _onItemPointerDown(i),
                                    onPointerUp:   (_) => _onItemPointerUp(i),
                                    onPointerCancel: (_) => _onItemPointerCancel(),
                                    child: SizedBox(
                                      height: pillH,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(item.icon, color: iconColor, size: 20),
                                          if (item.label != null) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              item.label!,
                                              style: TextStyle(
                                                color: iconColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: -0.1,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ), // ClipRRect glass surface

              // ── Shadow (dark only) ────────────────────────────────────
              if (isDark)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, shadowOpacity),
                            blurRadius: 10 + liftT * 24,
                            spreadRadius: -2,
                            offset: Offset(0, 2 + liftT * 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

class _ToolbarSurfacePainter extends CustomPainter {
  const _ToolbarSurfacePainter({
    required this.isDark,
    required this.pressT,
    required this.liftT,
    required this.radius,
  });

  final bool   isDark;
  final double pressT;
  final double liftT;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // Top specular line across the straight portion
    final specAlpha = (isDark ? 0.40 : 0.60)
        + liftT * 0.20
        - pressT * 0.15;
    final specRect = Rect.fromLTWH(radius, 0, size.width - radius * 2, 1.2);
    canvas.drawRect(
      specRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0x00FFFFFF),
            Color.fromRGBO(255, 255, 255, specAlpha.clamp(0.0, 1.0)),
            Color.fromRGBO(255, 255, 255, specAlpha.clamp(0.0, 1.0)),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ).createShader(specRect),
    );

    // Rim
    final rimAlpha = (isDark ? 0.18 : 0.28) + liftT * 0.10;
    final cy = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cy)),
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color       = Color.fromRGBO(255, 255, 255, rimAlpha),
    );
  }

  @override
  bool shouldRepaint(_ToolbarSurfacePainter old) =>
      old.isDark  != isDark  ||
          old.pressT  != pressT  ||
          old.liftT   != liftT   ||
          old.radius  != radius;
}

class _ToolbarIridPainter extends CustomPainter {
  const _ToolbarIridPainter({
    required this.iridOpacity,
    required this.iridAngle,
    required this.radius,
  });

  final double iridOpacity;
  final double iridAngle;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cy)),
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..blendMode   = ui.BlendMode.plus
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 0.6)
        ..shader = ui.Gradient.sweep(
          Offset(size.width / 2, cy),
          [
            Color.fromRGBO(255, 110, 199, (iridOpacity * 0.80).clamp(0, 1)),
            Color.fromRGBO(123, 110, 255, (iridOpacity * 0.65).clamp(0, 1)),
            Color.fromRGBO(110, 223, 255, (iridOpacity * 0.60).clamp(0, 1)),
            Color.fromRGBO(110, 255, 154, (iridOpacity * 0.50).clamp(0, 1)),
            Color.fromRGBO(255, 232, 110, (iridOpacity * 0.45).clamp(0, 1)),
            Color.fromRGBO(255, 110, 199, (iridOpacity * 0.80).clamp(0, 1)),
          ],
          [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          TileMode.clamp,
          iridAngle,
          iridAngle + math.pi * 2,
        ),
    );
  }

  @override
  bool shouldRepaint(_ToolbarIridPainter old) =>
      old.iridOpacity != iridOpacity || old.iridAngle != iridAngle;
}