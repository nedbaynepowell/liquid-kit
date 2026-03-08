// liquid_glass_button.dart
//
// A circular glass button with lift physics and iridescent border on press.
//
// Quick start:
//   LiquidGlassButton(onPressed: () {})
//   LiquidGlassButton(
//     onPressed: () {},
//     child: Icon(Icons.add, color: Colors.white, size: 20),
//   )
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Theme, Brightness, Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'liquid_glass_physics.dart';
import 'liquid_glass_theme.dart';

class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    this.child,
    this.size = 44.0,
    this.blurSigma,
    this.isDark,
  });

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  /// Content inside the button. Defaults to a menu (hamburger) icon.
  final Widget? child;

  /// Button diameter. Defaults to `44.0`.
  final double size;

  /// Background blur strength. Defaults to the theme value or `20.0`.
  final double? blurSigma;

  /// Override light/dark mode. Defaults to the ambient [Theme].
  final bool? isDark;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with TickerProviderStateMixin {
  late AnimationController _liftCtrl;
  late AnimationController _iridCtrl;
  late AnimationController _iridOpacityCtrl;
  late AnimationController _expandCtrl;
  late Animation<double> _expandT;

  @override
  void initState() {
    super.initState();

    _liftCtrl = AnimationController(
      vsync: this,
      duration: kLiftActivationDuration,
      reverseDuration: const Duration(milliseconds: 300),
    );

    _iridCtrl = AnimationController(
      vsync: this,
      duration: kIridescentRotationDuration,
    );

    _iridOpacityCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _expandT = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _liftCtrl.dispose();
    _iridCtrl.dispose();
    _iridOpacityCtrl.dispose();
    _expandCtrl.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    _expandCtrl.forward();
    _liftCtrl.forward();
    _iridCtrl.repeat();
    _iridOpacityCtrl.forward();
    HapticFeedback.lightImpact();
  }

  void _onPointerUp(PointerUpEvent _) {
    _expandCtrl.reverse();
    _liftCtrl.reverse();
    _iridOpacityCtrl.reverse().then((_) {
      _iridCtrl
        ..stop()
        ..reset();
    });
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _expandCtrl.reverse();
    _liftCtrl.reverse();
    _iridOpacityCtrl.reverse().then((_) {
      _iridCtrl
        ..stop()
        ..reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.isDark ?? Theme.of(context).brightness == Brightness.dark;
    final theme = LiquidGlassTheme.of(context);
    final blur = widget.blurSigma ?? theme?.resolvedBlurSigma ?? kBlurSigma;
    final radius = widget.size / 2;
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_liftCtrl, _iridCtrl, _iridOpacityCtrl, _expandT]),
      builder: (context, _) {
        final liftT = _liftCtrl.value;
        final expandT = _expandT.value;
        final iridOp = _iridOpacityCtrl.value;
        final iridAngle = _iridCtrl.value * 2 * math.pi;

        final size = widget.size + expandT * 4.0;
        final shadowOpacity =
            (isDark ? 0.28 : 0.12) + liftT * 0.14;

        return Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(
                          0, 0, 0, shadowOpacity),
                      blurRadius: 12 + liftT * 20,
                      spreadRadius: -2,
                      offset: Offset(0, 2 + liftT * 8),
                    ),
                    BoxShadow(
                      color: Color.fromRGBO(
                          0, 0, 0, shadowOpacity * 0.5),
                      blurRadius: 24 + liftT * 20,
                      spreadRadius: -4,
                      offset: Offset(0, 4 + liftT * 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Backdrop blur ─────────────────────────────────
                      BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: blur * 0.2,
                          sigmaY: blur * 0.2,
                          tileMode: TileMode.clamp,
                        ),
                        child: const SizedBox.expand(),
                      ),

                      // ── Tint ──────────────────────────────────────────
                      ColoredBox(
                        color: isDark
                            ? const Color(0x661C1C1C)
                            : const Color(0x66FBFBFF),
                      ),
                      // ── Rim / specular / iridescent layers ────────────
                      CustomPaint(
                        painter: _ButtonGlassPainter(
                          isDark: isDark,
                          radius: radius,
                          iridOpacity: iridOp,
                          iridAngle: iridAngle,
                        ),
                      ),

                      // ── Specular border ───────────────────────────────
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x38FFFFFF)
                                  : const Color(0x55FFFFFF),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),

                      // ── Child ─────────────────────────────────────────
                      Center(
                        child: widget.child ??
                            _DefaultMenuIcon(isDark: isDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Default hamburger/menu icon when no child is provided
class _DefaultMenuIcon extends StatelessWidget {
  const _DefaultMenuIcon({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : const Color(0xFF19181D);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Line(color: color),
        const SizedBox(height: 4),
        _Line(color: color, width: 12),
        const SizedBox(height: 4),
        _Line(color: color),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.color, this.width = 16});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 1.5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _ButtonGlassPainter extends CustomPainter {
  const _ButtonGlassPainter({
    required this.isDark,
    required this.radius,
    required this.iridOpacity,
    required this.iridAngle,
  });

  final bool isDark;
  final double radius;
  final double iridOpacity;
  final double iridAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Refraction shimmer
    canvas.drawRRect(rrect, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.7),
        radius: 1.2,
        colors: isDark
            ? [const Color(0x14FFFFFF), const Color(0x00FFFFFF), const Color(0x08000000)]
            : [const Color(0x22FFFFFF), const Color(0x00FFFFFF), const Color(0x06000000)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect));

    // Top specular — much more subtle than the pill
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.38),
        Radius.circular(radius),
      ),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(255, 255, 255, isDark ? 0.06 : 0.14),
          const Color(0x00FFFFFF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.38)),
    );

    // Edge glow
    final edgeAlpha = isDark ? 0.28 : 0.38;
    canvas.drawRRect(rrect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(255, 255, 255, edgeAlpha),
          Color.fromRGBO(255, 255, 255, edgeAlpha * 0.5),
          Color.fromRGBO(255, 255, 255, edgeAlpha * 0.2),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect));

    // Iridescent border on press
    if (iridOpacity > 0.01) {
      canvas.drawRRect(rrect, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..shader = SweepGradient(
          startAngle: iridAngle,
          endAngle: iridAngle + math.pi * 2,
          colors: [
            Color.fromRGBO(255, 255, 255, iridOpacity * 0.72),
            Color.fromRGBO(210, 226, 255, iridOpacity * 0.48),
            Color.fromRGBO(176, 210, 255, iridOpacity * 0.42),
            Color.fromRGBO(198, 214, 255, iridOpacity * 0.36),
            Color.fromRGBO(234, 222, 255, iridOpacity * 0.28),
            Color.fromRGBO(255, 244, 228, iridOpacity * 0.24),
            Color.fromRGBO(255, 255, 255, iridOpacity * 0.72),
          ],
          stops: const [0.0, 0.17, 0.33, 0.50, 0.67, 0.83, 1.0],
        ).createShader(rect));
    }
  }

  @override
  bool shouldRepaint(_ButtonGlassPainter old) =>
      isDark != old.isDark ||
          iridOpacity != old.iridOpacity ||
          iridAngle != old.iridAngle;
}
