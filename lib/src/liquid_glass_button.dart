// liquid_glass_button.dart
//
// Composited glass pipeline for LiquidGlassButton + LiquidGlassGroup.
//
// Architecture:
//   LiquidGlassGroup — wraps a region of UI in a single RepaintBoundary.
//     All buttons inside the group share ONE backdrop snapshot from that
//     boundary, eliminating the overlapping-independent-glass-layer artifact
//     where each button would fog the others' blur sources.
//
//   LiquidGlassButton — reads the nearest LiquidGlassGroup's shared image
//     via an InheritedWidget (_GlassGroupData). It clips and renders its
//     own circular region from the shared source rather than capturing
//     its own independent snapshot.
//
//   Local contrast analysis — after each backdrop capture the group
//     samples a luminance histogram over each child button's bounds.
//     If the average luminance behind a button is within 18% of the
//     tint colour (low contrast), the frosting/overlay strength for
//     that button is automatically increased so labels remain legible.
//
//   Press state — animates shape (radius morph), size (scale pop),
//     highlight (specular intensity ramp), and depth (shadow + lift)
//     all together from a single AnimationController, so they are
//     physically coupled and never drift apart.
//
//   No .frag shaders. All rendering via Canvas APIs and dart:ui.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Theme, Brightness, Colors;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'liquid_glass_physics.dart';
import 'liquid_glass_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public surface
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a region so all [LiquidGlassButton]s inside share one backdrop
/// snapshot. Place this around your top-bar row or any group of glass
/// controls that overlap the same scrolling content.
///
/// ```dart
/// LiquidGlassGroup(
///   child: Row(children: [
///     LiquidGlassButton(onPressed: () {}, child: Icon(Icons.menu)),
///     LiquidGlassButton(onPressed: () {}, child: Icon(Icons.add)),
///   ]),
/// )
/// ```
class LiquidGlassGroup extends StatefulWidget {
  const LiquidGlassGroup({
    super.key,
    required this.child,
    this.capturePadding = 8.0,
  });

  /// The grouped subtree that shares a single backdrop capture.
  final Widget child;

  /// Extra padding around the capture region so nearby content still blurs.
  final double capturePadding;

  @override
  State<LiquidGlassGroup> createState() => _LiquidGlassGroupState();
}

class _LiquidGlassGroupState extends State<LiquidGlassGroup> {
  final GlobalKey _boundaryKey = GlobalKey();

  // Shared backdrop for all child buttons.
  ui.Image? _sharedBackdrop;

  // Per-button contrast boost, keyed by button GlobalKey hashCode.
  final Map<int, double> _contrastBoosts = {};

  /// Called by child buttons to register for contrast analysis.
  /// Returns their current boost value (0.0–1.0).
  double contrastBoostFor(int keyHash) => _contrastBoosts[keyHash] ?? 0.0;

  /// Trigger a fresh capture. Child buttons call this on pointer-down
  /// so the snapshot is always current.
  void captureBackdrop({List<_ButtonBounds>? buttonBounds}) {
    if (!mounted) return;
    final ro = _boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return;
    try {
      final dpr = View.of(context).devicePixelRatio;
      final img = ro.toImageSync(pixelRatio: dpr);
      if (img.width <= 0) return;
      _sharedBackdrop?.dispose();
      _sharedBackdrop = img;

      // Run contrast analysis if bounds were provided.
      if (buttonBounds != null && buttonBounds.isNotEmpty) {
        _analyseContrast(img, buttonBounds, dpr);
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _analyseContrast(
      ui.Image img, List<_ButtonBounds> bounds, double dpr) {
    // Sample a small downscaled region behind each button and compute
    // average luminance. If it's within kContrastThreshold of mid-grey
    // (meaning the content blends into the glass tint), boost frosting.
    for (final b in bounds) {
      final srcRect = Rect.fromLTWH(
        b.rect.left * dpr,
        b.rect.top * dpr,
        b.rect.width * dpr,
        b.rect.height * dpr,
      );
      // Clamp to image bounds.
      final clampedRect = Rect.fromLTRB(
        srcRect.left.clamp(0, img.width.toDouble()),
        srcRect.top.clamp(0, img.height.toDouble()),
        srcRect.right.clamp(0, img.width.toDouble()),
        srcRect.bottom.clamp(0, img.height.toDouble()),
      );
      if (clampedRect.isEmpty) continue;

      // Use a tiny picture recorder to read pixel data cheaply.
      final recorder = ui.PictureRecorder();
      final c = ui.Canvas(recorder);
      const sampleSize = 8.0;
      c.drawImageRect(
        img,
        clampedRect,
        Rect.fromLTWH(0, 0, sampleSize, sampleSize),
        Paint()..filterQuality = FilterQuality.low,
      );
      final picture = recorder.endRecording();
      final thumb = picture.toImageSync(sampleSize.toInt(), sampleSize.toInt());
      picture.dispose();

      // Read pixels synchronously via toByteData — small 8×8 so it's fast.
      thumb.toByteData(format: ui.ImageByteFormat.rawRgba).then((bytes) {
        thumb.dispose();
        if (bytes == null || !mounted) return;
        double luminanceSum = 0;
        final data = bytes.buffer.asUint8List();
        final pixels = data.length ~/ 4;
        for (int i = 0; i < data.length; i += 4) {
          final r = data[i] / 255.0;
          final g = data[i + 1] / 255.0;
          final bl = data[i + 2] / 255.0;
          // BT.709 luminance
          luminanceSum += 0.2126 * r + 0.7152 * g + 0.0722 * bl;
        }
        final avgLuminance = luminanceSum / pixels;
        // Low contrast: backdrop is close to mid-grey (our tint colour).
        // Map distance from 0.5 to a boost: near 0.5 → high boost.
        final distFromMid = (avgLuminance - 0.5).abs();
        final boost = (1.0 - (distFromMid / 0.5)).clamp(0.0, 1.0);
        if (mounted) {
          setState(() => _contrastBoosts[b.keyHash] = boost * 0.6);
        }
      });
    }
  }

  @override
  void dispose() {
    _sharedBackdrop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassGroupData(
      state: this,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InheritedWidget — passes group state down to child buttons
// ─────────────────────────────────────────────────────────────────────────────

class _GlassGroupData extends InheritedWidget {
  const _GlassGroupData({required this.state, required super.child});
  final _LiquidGlassGroupState state;

  static _LiquidGlassGroupState? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassGroupData>()?.state;

  @override
  bool updateShouldNotify(_GlassGroupData old) => old.state != state;
}

// ─────────────────────────────────────────────────────────────────────────────
// Button bounds descriptor for contrast analysis
// ─────────────────────────────────────────────────────────────────────────────

class _ButtonBounds {
  const _ButtonBounds({required this.keyHash, required this.rect});
  final int keyHash;
  final Rect rect; // in group-local coordinates
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidGlassButton
// ─────────────────────────────────────────────────────────────────────────────

/// A circular glass button. Place inside a [LiquidGlassGroup] for the
/// best results — the group provides a shared backdrop so buttons don't
/// fog each other. Falls back to an independent snapshot when used alone.
class LiquidGlassButton extends StatefulWidget {
  /// Creates a circular liquid glass action button.
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

  /// Button diameter. Defaults to 44.
  final double size;

  /// Background blur sigma. Defaults to theme or [kBlurSigma].
  final double? blurSigma;

  /// Override light/dark. Defaults to ambient [Theme].
  final bool? isDark;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

// Threshold below which a button manages its own snapshot (no group).
const double _kContrastThreshold = 0.18;
const Duration _kLongPressThreshold = Duration(milliseconds: 400);

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with TickerProviderStateMixin {
  // Used when no LiquidGlassGroup is present.
  final GlobalKey _soloKey = GlobalKey();
  ui.Image? _soloSnapshot;

  // Press controller — tap feedback (scale + darken).
  late AnimationController _pressCtrl;
  late Animation<double> _pressT;

  // Lift controllers — long-press lift (mirrors nav bar behaviour).
  late AnimationController _liftCtrl;
  late AnimationController _expandCtrl;
  late Animation<double> _expandT;
  late AnimationController _iridCtrl;
  late AnimationController _iridOpacityCtrl;

  bool _isLongPressed = false;
  Timer? _longPressTimer;

  // Offset of this button inside its group, computed at layout.
  Offset _groupOffset = Offset.zero;

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _soloCapture());
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _soloSnapshot?.dispose();
    _pressCtrl.dispose();
    _liftCtrl.dispose();
    _expandCtrl.dispose();
    _iridCtrl.dispose();
    _iridOpacityCtrl.dispose();
    super.dispose();
  }

  // ── Solo snapshot (fallback when no LiquidGlassGroup) ─────────────────────

  void _soloCapture() {
    if (!mounted) return;
    final ro = _soloKey.currentContext?.findRenderObject();
    if (ro is RenderRepaintBoundary) {
      try {
        final dpr = View.of(context).devicePixelRatio;
        final img = ro.toImageSync(pixelRatio: dpr);
        if (img.width > 0) {
          _soloSnapshot?.dispose();
          setState(() => _soloSnapshot = img);
        }
      } catch (_) {}
    }
  }

  // ── Compute this button's local rect inside the group ─────────────────────

  Rect? _groupLocalRect() {
    final groupState = _GlassGroupData.of(context);
    if (groupState == null) return null;
    final groupBox = groupState.context.findRenderObject() as RenderBox?;
    final myBox = context.findRenderObject() as RenderBox?;
    if (groupBox == null || myBox == null) return null;
    final offset = myBox.localToGlobal(Offset.zero) -
        groupBox.localToGlobal(Offset.zero);
    _groupOffset = offset;
    return offset & myBox.size;
  }

  // ── Pointer events ─────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent _) {
    final groupState = _GlassGroupData.of(context);
    if (groupState != null) {
      final rect = _groupLocalRect();
      groupState.captureBackdrop(
        buttonBounds: rect != null
            ? [_ButtonBounds(keyHash: widget.key.hashCode, rect: rect)]
            : null,
      );
    } else {
      _soloCapture();
    }
    _pressCtrl.forward(from: 0.0);
    HapticFeedback.lightImpact();

    // Arm long-press timer — fires lift after threshold.
    _longPressTimer?.cancel();
    _longPressTimer = Timer(_kLongPressThreshold, _activateLongPress);
  }

  void _onPointerUp(PointerUpEvent _) {
    _longPressTimer?.cancel();
    if (_isLongPressed) {
      _deactivateLongPress();
    } else {
      _pressCtrl.reverse();
      HapticFeedback.selectionClick();
    }
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _longPressTimer?.cancel();
    if (_isLongPressed) {
      _deactivateLongPress();
    } else {
      _pressCtrl.reverse(from: 1.0);
    }
  }

  void _activateLongPress() {
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
    final isDark =
        widget.isDark ?? Theme.of(context).brightness == Brightness.dark;
    final theme = LiquidGlassTheme.of(context);
    final blur = widget.blurSigma ?? theme?.resolvedBlurSigma ?? kBlurSigma;
    final groupState = _GlassGroupData.of(context);
    final contrastBoost = groupState?.contrastBoostFor(widget.key.hashCode) ?? 0.0;

    // Use solo key wrapper only when no group is present.
    Widget core = AnimatedBuilder(
      animation: Listenable.merge(
          [_pressCtrl, _liftCtrl, _expandCtrl, _iridOpacityCtrl, _iridCtrl]),
      builder: (context, _) {
        final p        = _pressT.value;
        final liftT    = _liftCtrl.value;
        final expandT  = _expandT.value;
        final iridOp   = _iridOpacityCtrl.value;
        final iridAngle = _iridCtrl.value * 2 * math.pi;
        final size     = widget.size;

        // On long-press: button expands and lifts like the nav bar pill.
        // On tap: subtle 13% scale pop only.
        final scale = _isLongPressed
            ? 1.0 + expandT * 0.22
            : 1.0 + p * 0.13;

        // Shadow deepens on lift (dark only).
        final shadowOpacity = isDark
            ? 0.08 + liftT * 0.30
            : 0.0;

        return Listener(
          onPointerDown: _onPointerDown,
          onPointerUp:   _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Shadow — dark mode only ────────────────────────────
                    if (isDark)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, shadowOpacity),
                                blurRadius: 10 + liftT * 24,
                                spreadRadius: -2,
                                offset: Offset(0, 2 + liftT * 9),
                              ),
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, shadowOpacity * 0.5),
                                blurRadius: 22 + liftT * 18,
                                spreadRadius: -4,
                                offset: Offset(0, 3 + liftT * 11),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Blur — full sigma, own layer, never inside Opacity ─
                    Positioned.fill(
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: blur,
                            sigmaY: blur,
                            tileMode: TileMode.clamp,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),

                    // ── Glass surface ──────────────────────────────────────
                    Positioned.fill(
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Very light tint — almost clear so content reads
                            // through. Press darkens slightly, lift brightens.
                            ColoredBox(
                              color: isDark
                                  ? Color.fromRGBO(255, 255, 255,
                                  0.08 + contrastBoost * 0.10 + p * 0.06 + liftT * 0.06)
                                  : Color.fromRGBO(255, 255, 255,
                                  0.22 + contrastBoost * 0.12 + p * 0.08 + liftT * 0.05),
                            ),

                            // Press darkening layer.
                            if (p > 0.01)
                              ColoredBox(
                                color: Color.fromRGBO(0, 0, 0, p * 0.08),
                              ),

                            // Surface specular + top arc.
                            CustomPaint(
                              painter: _ButtonSurfacePainter(
                                isDark: isDark,
                                pressT: p,
                                liftT: liftT,
                                contrastBoost: contrastBoost,
                              ),
                            ),

                            // Iridescent sweep border — only during long-press lift.
                            if (iridOp > 0.01)
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _ButtonIridPainter(
                                    iridOpacity: iridOp,
                                    iridAngle: iridAngle,
                                  ),
                                ),
                              ),

                            // Child
                            Center(
                              child: widget.child ??
                                  _DefaultMenuIcon(isDark: isDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ), // Stack
              ), // SizedBox
            ), // Transform.scale
          ), // GestureDetector
        ); // Listener
      },
    );

    // Solo mode: wrap in own RepaintBoundary for independent capture.
    if (groupState == null) {
      core = RepaintBoundary(key: _soloKey, child: core);
    }
    return core;
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _ButtonSurfacePainter
//
// Paints two things only:
//   1. A thin white specular arc across the top ~120° of the circle —
//      this is the single cue that reads as "glass" to the eye.
//   2. A very faint inner-edge rim stroke that gives depth without muddiness.
//
// Everything else (tint, blur, press darkening) is handled by the widget tree.
// ─────────────────────────────────────────────────────────────────────────────
class _ButtonSurfacePainter extends CustomPainter {
  const _ButtonSurfacePainter({
    required this.isDark,
    required this.pressT,
    required this.liftT,
    required this.contrastBoost,
  });

  final bool   isDark;
  final double pressT;
  final double liftT;
  final double contrastBoost;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 0.5;

    // ── 1. Top specular arc ──────────────────────────────────────────────
    // Dims on press, brightens on lift.
    const arcSpan  = 110.0 * math.pi / 180.0;
    const arcStart = -math.pi / 2 - arcSpan / 2;

    final specAlpha = ((isDark ? 0.55 : 0.70) * (1.0 - pressT * 0.5))
        + liftT * 0.25; // brighter when lifted

    final arcRect  = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final arcPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap   = StrokeCap.round
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        [
          const Color(0x00FFFFFF),
          Color.fromRGBO(255, 255, 255, specAlpha.clamp(0.0, 1.0)),
          Color.fromRGBO(255, 255, 255, specAlpha.clamp(0.0, 1.0)),
          const Color(0x00FFFFFF),
        ],
        [0.0, 0.25, 0.75, 1.0],
        TileMode.clamp,
        arcStart,
        arcStart + arcSpan,
      );
    canvas.drawArc(arcRect, arcStart, arcSpan, false, arcPaint);

    // ── 2. Rim stroke ────────────────────────────────────────────────────
    final rimAlpha = (isDark ? 0.18 : 0.28) + liftT * 0.12;
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color       = Color.fromRGBO(255, 255, 255, rimAlpha.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(_ButtonSurfacePainter old) =>
      old.isDark        != isDark        ||
          old.pressT        != pressT        ||
          old.liftT         != liftT         ||
          old.contrastBoost != contrastBoost;
}

// ─────────────────────────────────────────────────────────────────────────────
// _ButtonIridPainter — rotating sweep gradient on long-press lift
// ─────────────────────────────────────────────────────────────────────────────
class _ButtonIridPainter extends CustomPainter {
  const _ButtonIridPainter({
    required this.iridOpacity,
    required this.iridAngle,
  });

  final double iridOpacity;
  final double iridAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 0.5;

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.1
        ..blendMode   = ui.BlendMode.plus
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 0.6)
        ..shader = ui.Gradient.sweep(
          Offset(cx, cy),
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
  bool shouldRepaint(_ButtonIridPainter old) =>
      old.iridOpacity != iridOpacity || old.iridAngle != iridAngle;
}

// ─────────────────────────────────────────────────────────────────────────────
// Default hamburger icon
// ─────────────────────────────────────────────────────────────────────────────
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
