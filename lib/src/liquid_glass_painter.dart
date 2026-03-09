// liquid_glass_painter.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

/// Paints the ambient specular highlight on the outer bar surface.
class SpecularHighlightPainter extends CustomPainter {
  const SpecularHighlightPainter({
    this.fingerOffset,
    this.intensity = 0.15,
    this.isPressed = false,
    this.isDark = false,
    this.tilt = Offset.zero,
  });

  final Offset? fingerOffset;
  final double intensity;
  final bool isPressed;
  final bool isDark;
  final Offset tilt; // reserved for future use — not used visually

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    if (fingerOffset != null) {
      final fingerPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (fingerOffset!.dx / size.width) * 2 - 1,
            (fingerOffset!.dy / size.height) * 2 - 1,
          ),
          radius: 0.5,
          colors: [
            Color.fromRGBO(255, 255, 255, isDark ? 0.06 : 0.10),
            const Color(0x00FFFFFF),
          ],
        ).createShader(rect);
      canvas.drawRRect(rrect, fingerPaint);
    }
  }

  @override
  bool shouldRepaint(SpecularHighlightPainter old) =>
      fingerOffset != old.fingerOffset ||
      intensity != old.intensity ||
      isDark != old.isDark;
}

/// Paints the complete glass pill visual — refraction shimmer, edge SDF glow,
/// specular caustic, and top/bottom gradients.
///
/// This approximates steps 3–4 of Apple's visual pipeline:
///   Step 3: refraction — RadialGradient offset from top-left simulates
///           a curved lens bending light from behind the glass.
///   Step 4: edge SDF glow — bright rim painted as a stroke on the
///           RRect path, simulating caustic light at the glass edge.
class GlassPillPainter extends CustomPainter {
  const GlassPillPainter({
    required this.isDark,
    required this.radius,
    required this.liftT,
    required this.iridOpacity,
    required this.iridAngle,
  });

  final bool isDark;
  final double radius;
  final double liftT;
  final double iridOpacity;
  final double iridAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // ── Layer 1: Refraction shimmer ───────────────────────────────────────
    final refractionPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.7),
        radius: 1.2,
        colors: isDark
            ? [
                const Color(0x28FFFFFF),
                const Color(0x00FFFFFF),
                const Color(0x14000000),
              ]
            : [
                const Color(0x38FFFFFF),
                const Color(0x00FFFFFF),
                const Color(0x0A000000),
              ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, refractionPaint);

    // ── Layer 2: Top specular caustic ─────────────────────────────────────
    final specularAlpha = (0.18 + liftT * 0.22).clamp(0.0, 1.0);
    final specularPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(255, 255, 255, specularAlpha),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.38));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.38),
        Radius.circular(radius),
      ),
      specularPaint,
    );

    // ── Layer 3: Bottom contact shadow ────────────────────────────────────
    final contactOpacity = (0.28 * (1.0 - liftT)).clamp(0.0, 0.28);
    if (contactOpacity > 0.01) {
      final contactPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color.fromRGBO(0, 0, 0, contactOpacity),
            const Color(0x00000000),
          ],
        ).createShader(Rect.fromLTWH(
            0, size.height * 0.72, size.width, size.height * 0.28));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
          Radius.circular(radius),
        ),
        contactPaint,
      );
    }

    // ── Layer 4: Edge SDF glow (caustic rim) ──────────────────────────────
    final edgeAlpha = (isDark ? 0.45 : 0.55) + liftT * 0.25;
    final edgePaint = Paint()
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
      ).createShader(rect);
    canvas.drawRRect(rrect, edgePaint);

    // ── Layer 5: Inner pressure glow (selected state) ─────────────────────
    if (iridOpacity < 0.1) {
      final pressurePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            const Color(0x00FFFFFF),
            Color.fromRGBO(255, 255, 255, isDark ? 0.08 : 0.12),
          ],
        ).createShader(rect);
      canvas.drawRRect(rrect, pressurePaint);
    }

    // ── Layer 6: Iridescent border (long-press only) ──────────────────────
    if (iridOpacity > 0.01) {
      final iridPaint = Paint()
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
        ).createShader(rect);
      canvas.drawRRect(rrect, iridPaint);
    }
  }

  @override
  bool shouldRepaint(GlassPillPainter old) =>
      isDark != old.isDark ||
      liftT != old.liftT ||
      iridOpacity != old.iridOpacity ||
      iridAngle != old.iridAngle;
}

class WakeTrailPainter extends CustomPainter {
  const WakeTrailPainter({
    required this.progress,
    required this.direction,
    required this.leftRadius,
    required this.rightRadius,
    required this.isDark,
  });

  final double progress;
  final double direction;
  final double leftRadius;
  final double rightRadius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || direction == 0.0) return;

    final maxRadius = size.height / 2;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(leftRadius.clamp(0.0, maxRadius)),
      bottomLeft: Radius.circular(leftRadius.clamp(0.0, maxRadius)),
      topRight: Radius.circular(rightRadius.clamp(0.0, maxRadius)),
      bottomRight: Radius.circular(rightRadius.clamp(0.0, maxRadius)),
    );
    final alpha = progress * (isDark ? 0.10 : 0.07);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: direction > 0 ? Alignment.centerLeft : Alignment.centerRight,
        end: direction > 0 ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          Color.fromRGBO(255, 255, 255, alpha * 0.65),
          Color.fromRGBO(255, 255, 255, alpha * 0.22),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(WakeTrailPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      direction != oldDelegate.direction ||
      leftRadius != oldDelegate.leftRadius ||
      rightRadius != oldDelegate.rightRadius ||
      isDark != oldDelegate.isDark;
}

/// A subtle outward ripple used on tab-switch impact.
class ImpactRipplePainter extends CustomPainter {
  const ImpactRipplePainter({
    required this.progress,
    required this.radius,
    required this.isDark,
  });

  final double progress;
  final double radius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rrect);

    final rippleRadius = ui.lerpDouble(
        size.shortestSide * 0.16, size.longestSide * 0.58, progress)!;
    final alpha = (1.0 - progress) * (isDark ? 0.08 : 0.06);
    final center = Offset(size.width / 2, size.height / 2);

    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(255, 255, 255, alpha * 0.25),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: rippleRadius));
    canvas.drawCircle(center, rippleRadius, fill);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    canvas.drawCircle(center, rippleRadius * 0.92, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ImpactRipplePainter old) =>
      progress != old.progress || isDark != old.isDark || radius != old.radius;
}
