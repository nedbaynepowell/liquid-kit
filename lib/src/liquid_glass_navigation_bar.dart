// liquid_glass_navigation_bar.dart
// v5 + gel edge using bright row snapshot (correct blue/accent colours).
// FIX: All "pop" animations (expand, lift, irid) now fire simultaneously
//      at the long-press threshold moment — no more split timing.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart'
    show Brightness, Colors, NavigationBar, NavigationDestination, Theme;

import 'liquid_glass_physics.dart';
import 'liquid_glass_theme.dart';
import 'liquid_glass_painter.dart';

/// Describes a destination shown by [LiquidGlassNavigationBar].
class LiquidGlassTab {
  /// Creates a single navigation destination.
  const LiquidGlassTab({
    required this.icon,
    required this.label,
    this.accentColor,
    this.semanticLabel,
  });

  /// Icon shown for this destination.
  final IconData icon;

  /// Visible label for this destination.
  final String label;

  /// Per-tab override for the selected tab color.
  ///
  /// When null, the bar-level accent color is used instead.
  final Color? accentColor;

  /// Accessibility label announced for this destination.
  ///
  /// Defaults to [label].
  final String? semanticLabel;
}

/// A controlled liquid glass bottom navigation bar with 2 to 5 tabs.
///
/// The parent owns the selected state through [currentIndex] and updates it in
/// response to [onTabChanged]. When [mode] resolves to
/// [LiquidGlassMode.adaptive] on a non-glass platform, this widget falls back
/// to Flutter's [NavigationBar].
class LiquidGlassNavigationBar extends StatefulWidget {
  /// Creates a liquid glass navigation bar.
  const LiquidGlassNavigationBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
    this.scrollController,
    this.collapseOnScroll = false,
    this.accentColor,
    this.blurSigma,
    this.springStiffness,
    this.springDamping,
    this.mode,
  }) : assert(tabs.length >= 2 && tabs.length <= 5,
            'LiquidGlassNavigationBar supports 2–5 tabs');

  /// Ordered destinations shown by the bar.
  ///
  /// Must contain between 2 and 5 tabs.
  final List<LiquidGlassTab> tabs;

  /// Zero-based index of the currently selected tab.
  final int currentIndex;

  /// Called when the user selects a tab.
  final ValueChanged<int> onTabChanged;

  /// Reserved for future scroll-linked collapse behavior.
  ///
  /// This parameter is currently unused.
  final ScrollController? scrollController;

  /// Reserved for future scroll-linked collapse behavior.
  ///
  /// This parameter is currently unused.
  final bool collapseOnScroll;

  /// Default selected-tab color for tabs without their own
  /// [LiquidGlassTab.accentColor].
  ///
  /// If null, the value falls back to [LiquidGlassTheme.accentColor] and then
  /// the package default accent color.
  final Color? accentColor;

  /// Overrides the backdrop blur amount for the glass effect.
  ///
  /// If null, the value falls back to [LiquidGlassTheme.resolvedBlurSigma] and
  /// then [kBlurSigma].
  final double? blurSigma;

  /// Overrides the spring stiffness used when the pill moves between tabs.
  ///
  /// If null, the widget uses its built-in defaults.
  final double? springStiffness;

  /// Overrides the spring damping used when the pill moves between tabs.
  ///
  /// If null, the widget uses its built-in defaults.
  final double? springDamping;

  /// Overrides how this widget chooses between glass and fallback rendering.
  ///
  /// If null, the value falls back to [LiquidGlassTheme.mode] and then
  /// [LiquidGlassMode.always].
  final LiquidGlassMode? mode;

  @override
  State<LiquidGlassNavigationBar> createState() =>
      _LiquidGlassNavigationBarState();
}

class _LiquidGlassNavigationBarState extends State<LiquidGlassNavigationBar>
    with TickerProviderStateMixin {
  final List<GlobalKey> _tabKeys = [];
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _tabRowKey = GlobalKey();
  final GlobalKey _tabRowFullKey = GlobalKey();

  // Key for the bright row inside the pill — this is what we snapshot
  // so the gel painter always warps the correct blue/accent colours.
  final GlobalKey _brightRowKey = GlobalKey();
  ui.Image? _tabRowSnapshot;

  double _pillX = 0.0;
  double _pillWidth = 0.0;
  double _pillTargetX = 0.0;
  bool _pillSettled = true;
  double _barWidth = 0.0;
  double _stretchProgress = 0.0;
  List<double> _tabCentres = [];
  double? _previewPillX;

  late AnimationController _pillCtrl;
  late AnimationController _stretchCtrl;
  late Animation<double> _stretchAnim;
  bool _isLongPressed = false;
  bool _isDragging = false;
  double _dragCurrentX = 0.0;
  double _dragVelocity = 0.0;
  DateTime? _lastPointerTime;
  bool _longPressArmed = false;
  Offset _pointerDownPos = Offset.zero;
  Offset? _fingerOffset;
  bool _isPressed = false;
  late AnimationController _liftCtrl;
  late Animation<double> _outerDim;
  late AnimationController _iridCtrl;
  late AnimationController _iridOpacityCtrl;
  late AnimationController _collapseCtrl;
  late Animation<double> _collapseAnim;
  int? _pendingSnapIndex;
  int _displayIndex = 0;
  List<double> _tabOffsets = [];
  late AnimationController _expandCtrl;
  late Animation<double> _expandT;
  late Animation<double> _expandRadius;
  late AnimationController _tabSpringCtrl;
  late AnimationController _restCtrl;
  late AnimationController _impactCtrl;
  late Animation<double> _impactRipple;

  // ─── Snapshot ─────────────────────────────────────────────────────
  void _captureTabRowSnapshot() {
    final ro = _brightRowKey.currentContext?.findRenderObject();
    if (ro is RenderRepaintBoundary) {
      try {
        final img =
            ro.toImageSync(pixelRatio: View.of(context).devicePixelRatio);
        if (img.width > 0) {
          _tabRowSnapshot?.dispose();
          _tabRowSnapshot = img;
        }
      } catch (_) {}
    }
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.tabs.length; i++) {
      _tabKeys.add(GlobalKey());
    }
    _displayIndex = widget.currentIndex;
    _tabOffsets = List.filled(widget.tabs.length, 0.0);

    _pillCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onPillUpdate);

    _stretchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _stretchAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _stretchCtrl, curve: Curves.easeInOut));
    _stretchCtrl.addListener(() {
      if (mounted) setState(() => _stretchProgress = _stretchAnim.value);
    });

    _liftCtrl = AnimationController(
      vsync: this,
      duration: kLiftActivationDuration,
      reverseDuration: const Duration(milliseconds: 300),
    );
    _outerDim = Tween<double>(begin: 1.0, end: kOuterBarDimOnLift)
        .animate(CurvedAnimation(parent: _liftCtrl, curve: Curves.easeOut));

    _tabSpringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _restCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _impactCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _impactRipple = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _impactCtrl, curve: Curves.easeOutCubic));

    _iridCtrl =
        AnimationController(vsync: this, duration: kIridescentRotationDuration);
    _iridOpacityCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _expandCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _expandT = CurvedAnimation(
        parent: _expandCtrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
    _expandRadius = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _expandCtrl,
        curve: const Interval(0.1, 0.9, curve: Curves.easeInOut)));
    _collapseCtrl =
        AnimationController(vsync: this, duration: kCollapseDuration);
    _collapseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _collapseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureAndSnap(animate: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _captureTabRowSnapshot();
      });
    });
  }

  void _measureAndSnap({required bool animate, int? targetIndex}) {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureAndSnap(animate: animate, targetIndex: targetIndex));
      return;
    }
    final centres = <double>[];
    final widths = <double>[];
    final cellWidth = stackBox.size.width / widget.tabs.length;
    for (int i = 0; i < widget.tabs.length; i++) {
      centres.add(cellWidth * (i + 0.5));
    }
    for (final key in _tabKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _measureAndSnap(animate: animate, targetIndex: targetIndex));
        return;
      }
      widths.add(box.size.width);
    }
    if (widths.length != widget.tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureAndSnap(animate: animate, targetIndex: targetIndex));
      return;
    }
    setState(() {
      _tabCentres = centres;
      _barWidth = stackBox.size.width;
    });
    final idx = targetIndex ?? widget.currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _snapPillToTab(idx, animate: animate);
    });
  }

  double? _resolvedPillWidth() {
    if (_pillWidth > 0) return _pillWidth;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize || widget.tabs.isEmpty)
      return null;
    return (stackBox.size.width / widget.tabs.length) * 1.06;
  }

  Rect? _tabCellRect(int index) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || widget.tabs.isEmpty || index >= widget.tabs.length)
      return null;
    final cellWidth = stackBox.size.width / widget.tabs.length;
    return Rect.fromLTWH(cellWidth * index, 0, cellWidth, stackBox.size.height);
  }

  double _currentTravelDirection() {
    if (_isDragging && _dragVelocity.abs() > 0.001) return _dragVelocity.sign;
    if (_previewPillX != null) {
      final d = _pillCtrl.value - _pillX;
      if (d.abs() > 0.001) return d.sign;
    }
    final td = _pillTargetX - _pillX;
    if (td.abs() > 0.001) return td.sign;
    if (_pillCtrl.velocity.abs() > 0.001) return _pillCtrl.velocity.sign;
    return 0.0;
  }

  double _currentMotionT() {
    final movingBoost = _pillCtrl.isAnimating ? 0.25 : 0.0;
    final draggingBoost = _isDragging ? 0.15 : 0.0;
    return (_stretchProgress * 1.1 + movingBoost + draggingBoost)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _edgeRadiusForSide({required bool left}) {
    final motionT = _currentMotionT();
    final direction = _currentTravelDirection();
    final base = kInnerPillHeight / 2;
    final leading = base * (1.0 - motionT * 0.03);
    final trailing = base * (1.0 - motionT * 0.52);
    if (direction > 0) return left ? trailing : leading;
    if (direction < 0) return left ? leading : trailing;
    return base;
  }

  void _snapPillToTab(int index, {bool animate = true}) {
    if (!mounted) return;
    if (_tabCentres.isEmpty || index >= _tabCentres.length) {
      _measureAndSnap(animate: animate, targetIndex: index);
      return;
    }
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final totalBarWidth = stackBox?.size.width ?? 0.0;
    if (totalBarWidth <= 0) {
      _measureAndSnap(animate: animate, targetIndex: index);
      return;
    }
    final newWidth =
        _resolvedPillWidth() ?? (totalBarWidth / widget.tabs.length) * 1.16;
    final newX = (_tabCentres[index] - newWidth / 2)
        .clamp(0.0, totalBarWidth - newWidth)
        .toDouble();

    if (!animate || MediaQuery.of(context).disableAnimations) {
      setState(() {
        _pillWidth = newWidth;
        _pillTargetX = newX;
        _pillX = newX;
        _stretchProgress = 0.0;
        _pillSettled = true;
      });
      return;
    }

    // If the pill is already at the target (e.g. hold-and-release on current
    // tab), skip the stretch/spring entirely so _pillSettled stays true.
    final alreadyThere = (_pillX - newX).abs() < 1.0;
    setState(() {
      _pillWidth = newWidth;
      _pillTargetX = newX;
      _pillSettled = alreadyThere;
    });
    if (alreadyThere) return;

    _stretchCtrl.forward(from: 0.0);
    _pillCtrl.animateWith(SpringSimulation(
      SpringDescription(
          mass: kTabSwitchMass,
          stiffness: widget.springStiffness ?? 420.0,
          damping: widget.springDamping ?? 28.0),
      _pillX,
      newX,
      0,
    ));
  }

  void _onPillUpdate() {
    final distToTarget = (_pillCtrl.value - _pillTargetX).abs();
    setState(() {
      _pillX = _pillCtrl.value;
      _pillSettled = distToTarget < 2.0 && !_stretchCtrl.isAnimating;
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointerDownPos = e.localPosition;
    _isPressed = true;
    setState(() => _fingerOffset = e.localPosition);

    if (_isOnActivePill(e.localPosition)) {
      // ── ACTIVE PILL: arm long-press only; do NOT start any pop animations yet.
      // Everything fires together at the long-press threshold in _activateLongPress.
      _longPressArmed = true;
      Future.delayed(kLongPressThreshold, () {
        if (_longPressArmed && mounted) _activateLongPress(e.localPosition);
      });
    } else {
      // ── INACTIVE TAB: immediate tap-preview behaviour (no hold needed).
      // All three pop animations fire together here so the pill preview,
      // the iridescent shimmer, and the outer dim all begin at the same instant.
      _expandCtrl.forward();
      _liftCtrl.forward();
      _iridCtrl.repeat();
      _iridOpacityCtrl.forward();

      for (int i = 0; i < _tabCentres.length; i++) {
        if (i == widget.currentIndex) continue;
        final cellRect = _tabCellRect(i);
        if (cellRect == null) continue;
        if (cellRect.contains(e.localPosition)) {
          final pw = _resolvedPillWidth();
          if (pw == null) break;
          final targetX = _tabCentres[i] - pw / 2;
          setState(() => _previewPillX = targetX);
          _pillCtrl.animateWith(SpringSimulation(
            SpringDescription(
                mass: kTabSwitchMass,
                stiffness: widget.springStiffness ?? kTabSwitchStiffness,
                damping: widget.springDamping ?? kTabSwitchDamping),
            _pillX,
            targetX,
            0,
          ));
          break;
        }
      }
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_isDragging &&
        (e.localPosition - _pointerDownPos).distance >
            kLongPressCancelDistance) {
      _longPressArmed = false;
    }
    setState(() => _fingerOffset = e.localPosition);

    if (!_isDragging && _previewPillX != null) {
      final pw = _resolvedPillWidth();
      final stackBox =
          _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (pw != null && stackBox != null) {
        final targetX = (e.localPosition.dx - pw / 2)
            .clamp(0.0, stackBox.size.width - pw)
            .toDouble();
        _pillCtrl.stop();
        _pillCtrl.value = targetX;
        setState(() {
          _previewPillX = targetX;
          _pillX = targetX;
        });
      }
      return;
    }
    if (!_isDragging) return;

    final now = DateTime.now();
    if (_lastPointerTime != null) {
      final dt = now.difference(_lastPointerTime!).inMilliseconds;
      if (dt > 0) _dragVelocity = e.delta.dx / dt;
    }
    _lastPointerTime = now;

    setState(() {
      _dragCurrentX += e.delta.dx;
      final leftBound =
          _tabCentres.isNotEmpty ? _tabCentres.first - _pillWidth / 2 : 0.0;
      final rightBound =
          _tabCentres.isNotEmpty ? _tabCentres.last - _pillWidth / 2 : 9999.0;
      if (_dragCurrentX < leftBound) {
        _pillX = leftBound - _rubberBand(leftBound - _dragCurrentX, 80);
      } else if (_dragCurrentX > rightBound) {
        _pillX = rightBound + _rubberBand(_dragCurrentX - rightBound, 80);
      } else {
        _pillX = _dragCurrentX;
      }
      _stretchProgress = (_dragVelocity.abs() * kStretchVelocityFactor)
          .clamp(0.0, kMaxVelocityStretch);

      final pillCentre = _pillX + _pillWidth / 2;
      for (int i = 0; i < _tabCentres.length; i++) {
        if (i == widget.currentIndex) {
          _tabOffsets[i] = 0.0;
          continue;
        }
        final dist = pillCentre - _tabCentres[i];
        final influence = _pillWidth * 0.9;
        if (dist.abs() < influence) {
          final t = 1.0 - (dist.abs() / influence);
          _tabOffsets[i] = 14.0 * t * t * (dist < 0 ? 1.0 : -1.0);
        } else {
          _tabOffsets[i] = 0.0;
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureTabRowSnapshot();
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    _longPressArmed = false;
    _isPressed = false;
    final hadPreview = _previewPillX != null;
    final wasDragging = _isDragging;
    setState(() => _fingerOffset = null);

    if (wasDragging) {
      // Covers both: actual drag AND hold-and-release with no movement.
      // _activateLongPress always sets _isDragging = true alongside _isLongPressed,
      // so _endDrag → _deactivateLongPress handles both cases correctly.
      _endDrag(velocity: _dragVelocity);
    } else if (hadPreview) {
      // Tap-preview on inactive tab released — commit the tab change.
      setState(() => _previewPillX = null);
      for (int i = 0; i < _tabCentres.length; i++) {
        final cellRect = _tabCellRect(i);
        if (cellRect == null) continue;
        if (cellRect.contains(e.localPosition)) {
          setState(() => _displayIndex = i);
          _pendingSnapIndex = i;
          widget.onTabChanged(i);
          break;
        }
      }
      setState(() => _previewPillX = null);
      _liftCtrl.reverse();
      _iridOpacityCtrl.reverse().then((_) {
        if (mounted) {
          _iridCtrl.stop();
          _iridCtrl.reset();
        }
      });
      _expandCtrl.reverse();
    } else {
      // Normal press/release with no special state — reverse expand and any
      // partial lift that may have started from an inactive-tab flow.
      _expandCtrl.reverse();
      _liftCtrl.reverse();
      _iridOpacityCtrl.reverse().then((_) {
        if (mounted) {
          _iridCtrl.stop();
          _iridCtrl.reset();
        }
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _longPressArmed = false;
    _isPressed = false;
    _expandCtrl.reverse();
    _isDragging = false;
    _tabOffsets = List.filled(widget.tabs.length, 0.0);
    setState(() {
      _fingerOffset = null;
      _stretchProgress = 0.0;
    });
    _deactivateLongPress();
    _previewPillX = null;
    _liftCtrl.reverse();
    _iridOpacityCtrl.reverse().then((_) {
      _iridCtrl
        ..stop()
        ..reset();
    });
  }

  bool _isOnActivePill(Offset p) =>
      _tabCentres.isNotEmpty &&
      _displayIndex == widget.currentIndex &&
      p.dx >= kInnerPillMargin + _pillX &&
      p.dx <= kInnerPillMargin + _pillX + _pillWidth;

  double _rubberBand(double o, double r) =>
      (1.0 - (1.0 / ((o * 0.55 / r) + 1.0))) * r;

  /// All three pop animations fire together here — expand, lift, and irid —
  /// so the pill scale, the outer dim, the iridescent overlay, and the tab
  /// content colour all start at exactly the same frame.
  void _activateLongPress(Offset pos) {
    if (!mounted) return;
    _captureTabRowSnapshot();

    // Reset controllers so they all begin from 0 at the same instant.
    _expandCtrl.forward(from: 0.0);
    _liftCtrl.forward(from: 0.0);
    _iridCtrl.repeat();
    _iridOpacityCtrl.forward(from: 0.0);

    setState(() {
      _isDragging = true;
      _isLongPressed = true;
      _dragCurrentX = _pillX;
    });
  }

  void _deactivateLongPress() {
    if (!_isLongPressed) return;
    setState(() {
      _isLongPressed = false;
      _isDragging = false;
      _stretchProgress = 0.0;
      _pillSettled = true;
      _tabOffsets = List.filled(widget.tabs.length, 0.0);
    });
    _liftCtrl.reverse();
    _expandCtrl.reverse();
    _iridOpacityCtrl.reverse().then((_) {
      if (mounted) {
        _iridCtrl.stop();
        _iridCtrl.reset();
      }
    });
  }

  void _endDrag({required double velocity}) {
    _deactivateLongPress();
    int nearest = widget.currentIndex;
    double minD = double.infinity;
    final centre = _pillX + _pillWidth / 2;
    for (int i = 0; i < _tabCentres.length; i++) {
      final d = (centre - _tabCentres[i]).abs();
      if (d < minD) {
        minD = d;
        nearest = i;
      }
    }
    if (velocity.abs() > 0.5) {
      nearest = velocity > 0
          ? math.min(nearest + 1, widget.tabs.length - 1)
          : math.max(nearest - 1, 0);
    }
    setState(() => _stretchProgress = 0.0);
    if (nearest != widget.currentIndex) {
      _pendingSnapIndex = nearest;
      setState(() => _displayIndex = nearest);
      widget.onTabChanged(nearest);
    } else {
      _snapPillToTab(widget.currentIndex);
    }
  }

  void _onTabTap(int index) {
    if (index == _displayIndex) return;
    _isPressed = false;
    _longPressArmed = false;
    _liftCtrl.reverse();
    _iridOpacityCtrl.reverse().then((_) {
      _iridCtrl
        ..stop()
        ..reset();
    });
    _pendingSnapIndex = index;
    setState(() {
      _displayIndex = index;
      _previewPillX = null;
      _stretchProgress = 0.0;
      _fingerOffset = null;
    });
    widget.onTabChanged(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _captureTabRowSnapshot();
      });
    });
  }

  @override
  void didUpdateWidget(LiquidGlassNavigationBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      final target = _pendingSnapIndex ?? widget.currentIndex;
      _pendingSnapIndex = null;
      setState(() => _displayIndex = target);
      _tabSpringCtrl.forward(from: 0.0);
      _impactCtrl.forward(from: 0.0);
      _liftCtrl
          .animateTo(0.4,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut)
          .then((_) {
        if (mounted) {
          _liftCtrl.animateTo(0.0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _snapPillToTab(target);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _captureTabRowSnapshot();
        });
      });
    }
    if (widget.tabs.length != old.tabs.length) {
      _tabKeys.clear();
      for (int i = 0; i < widget.tabs.length; i++) _tabKeys.add(GlobalKey());
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _measureAndSnap(animate: false));
    }
  }

  @override
  void dispose() {
    _pillCtrl.dispose();
    _stretchCtrl.dispose();
    _liftCtrl.dispose();
    _iridCtrl.dispose();
    _tabRowSnapshot?.dispose();
    _iridOpacityCtrl.dispose();
    _expandCtrl.dispose();
    _collapseCtrl.dispose();
    _tabSpringCtrl.dispose();
    _restCtrl.dispose();
    _impactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = LiquidGlassTheme.of(context);
    final resolvedMode = widget.mode ?? theme?.mode ?? LiquidGlassMode.always;
    final accent = widget.accentColor ??
        theme?.accentColor ??
        LiquidGlassMaterial.activeContent(context, null);

    if (resolvedMode == LiquidGlassMode.adaptive &&
        !liquidGlassAdaptiveShouldUseGlass()) {
      return _buildAdaptiveFallback(context, accent);
    }

    final blur = widget.blurSigma ?? theme?.resolvedBlurSigma ?? kBlurSigma;
    final highContrast = MediaQuery.of(context).highContrast;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _liftCtrl,
        _iridOpacityCtrl,
        _iridCtrl,
        _collapseCtrl,
        _expandCtrl,
        _restCtrl,
        _impactCtrl,
        _stretchCtrl,
      ]),
      builder: (context, _) {
        return SizedBox(
          height: kOuterPillHeight,
          child: OverflowBox(
            maxHeight: kOuterPillHeight * 3.8,
            alignment: Alignment.center,
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: _buildMainPill(context,
                  isDark: isDark,
                  accent: accent,
                  blur: blur,
                  highContrast: highContrast,
                  collapseT: _collapseAnim.value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdaptiveFallback(BuildContext context, Color accent) {
    return NavigationBar(
      selectedIndex: widget.currentIndex,
      onDestinationSelected: widget.onTabChanged,
      indicatorColor: accent.withValues(alpha: 0.18),
      destinations: [
        for (final tab in widget.tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.icon, color: tab.accentColor ?? accent),
            label: tab.label,
          ),
      ],
    );
  }

  Widget _buildMainPill(
    BuildContext context, {
    required bool isDark,
    required Color accent,
    required double blur,
    required double collapseT,
    required bool highContrast,
  }) {
    final expandAmount = _expandT.value;
    final baseHeight = kOuterPillHeight * (1.0 - collapseT * 0.15);
    final morphRadius = kOuterPillRadius + _expandRadius.value * 4.0;
    final morphWidth = expandAmount * 6.0;
    final morphHeight = baseHeight + expandAmount * 4.0;
    final scaleY = baseHeight > 0 ? morphHeight / baseHeight : 1.0;
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final scaleX = screenWidth > 0 ? 1.0 + (morphWidth / screenWidth) : 1.0;

    final effectivePillX = _previewPillX != null ? _pillCtrl.value : _pillX;
    final pillLeft = kInnerPillMargin + effectivePillX;
    final travelDirection = _currentTravelDirection();
    final motionT = _currentMotionT();
    final leftRadius = _edgeRadiusForSide(left: true);
    final rightRadius = _edgeRadiusForSide(left: false);
    final liftOffsetY = 0.0;

    return Transform.scale(
      scaleX: scaleX,
      scaleY: scaleY,
      alignment: Alignment.center,
      child: SizedBox(
        height: baseHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // BackdropFilter must live OUTSIDE the Opacity widget.
            // Flutter composites an Opacity subtree into an offscreen layer,
            // which means a BackdropFilter inside it only blurs that offscreen
            // layer rather than the real backdrop — killing the blur effect.
            // By separating them, blur stays at full strength even when the
            // decorative layer dims during a long-press.
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(morphRadius),
                child: BackdropFilter(
                  filter: ui.ImageFilter.compose(
                    outer: ui.ImageFilter.blur(
                      sigmaX: blur * 0.18,
                      sigmaY: blur * 0.18,
                      tileMode: TileMode.clamp,
                    ),
                    inner: ui.ImageFilter.matrix(
                      (Matrix4.identity()
                            ..setEntry(0, 0, 1.0 + _expandT.value * 0.004)
                            ..setEntry(1, 1, 1.0 + _expandT.value * 0.003))
                          .storage,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            // Tint, shadow, gel rim and border dim together on lift —
            // but the blur layer above is unaffected.
            Positioned.fill(
              child: Opacity(
                opacity: _outerDim.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(morphRadius),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? const Color(0x22000000)
                            : const Color(0x0C000000),
                        blurRadius: 6 + expandAmount * 4,
                        spreadRadius: -2,
                        offset: const Offset(0, 1),
                      ),
                      BoxShadow(
                        color: isDark
                            ? const Color(0x12000000)
                            : const Color(0x06000000),
                        blurRadius: 14 + expandAmount * 4,
                        spreadRadius: -6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(morphRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: isDark
                              ? const Color(0xCC1C1C1C)
                              : const Color(0xCCFBFBFF),
                        ),
                        CustomPaint(
                          painter: _GelBackdropPainter(
                            isDark: isDark,
                            radius: morphRadius,
                            expandT: _expandT.value,
                            liftT: _liftCtrl.value,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(morphRadius),
                            border: Border.all(
                                color: const Color(0x38FFFFFF), width: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: SpecularHighlightPainter(
                  fingerOffset: _fingerOffset,
                  intensity: 0.18,
                  isPressed: _isPressed,
                  isDark: isDark,
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(kInnerPillMargin),
                child: RepaintBoundary(
                  key: _tabRowKey,
                  child: _pillWidth > 0
                      ? LayoutBuilder(builder: (context, constraints) {
                          final barW = constraints.maxWidth;
                          final pillFrac = _pillWidth / barW;
                          final pillOffFrac =
                              (pillLeft - kInnerPillMargin) / barW;
                          const feather = 0.015;
                          final l = (pillOffFrac - feather).clamp(0.0, 1.0);
                          final lIn = (pillOffFrac + feather).clamp(0.0, 1.0);
                          final rIn = (pillOffFrac + pillFrac - feather)
                              .clamp(0.0, 1.0);
                          final r = (pillOffFrac + pillFrac + feather)
                              .clamp(0.0, 1.0);
                          return ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => LinearGradient(
                              colors: const [
                                Colors.white,
                                Colors.transparent,
                                Colors.transparent,
                                Colors.white,
                              ],
                              stops: [l, lIn, rIn, r],
                            ).createShader(bounds),
                            child: RepaintBoundary(
                              key: _tabRowFullKey,
                              child: _buildTabRowDim(context,
                                  isDark: isDark,
                                  accent: accent,
                                  collapseT: collapseT),
                            ),
                          );
                        })
                      : _buildTabRowDim(context,
                          isDark: isDark, accent: accent, collapseT: collapseT),
                ),
              ),
            ),
            if (_pillWidth > 0 && motionT > 0.01 && travelDirection != 0.0)
              Positioned(
                left: travelDirection > 0
                    ? pillLeft - (_pillWidth * 0.38)
                    : pillLeft,
                top: kInnerPillMargin + 2 + liftOffsetY,
                width: _pillWidth * 1.38,
                height: kInnerPillHeight,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: WakeTrailPainter(
                      progress: motionT,
                      direction: travelDirection,
                      leftRadius: leftRadius,
                      rightRadius: rightRadius,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            if (_pillWidth > 0)
              Positioned(
                left: pillLeft,
                top: (kOuterPillHeight / 2) -
                    (kInnerPillHeight / 2) -
                    (0.0 * _liftCtrl.value / 2),
                width: _pillWidth + (20.0 * _liftCtrl.value),
                height: kInnerPillHeight,
                child: OverflowBox(
                  maxWidth: _pillWidth * 1.6 + (20.0 * _liftCtrl.value),
                  maxHeight: kOuterPillHeight * 3.4,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _pillWidth,
                    height: kInnerPillHeight + (20.0 * _liftCtrl.value),
                    child: Builder(builder: (context) {
                      return Container(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scaleByDouble(1.0, 1.0, 1.0, 1.0),
                          child: _buildGlassPillWithClippedRow(
                            context,
                            isDark: isDark,
                            accent: accent,
                            collapseT: collapseT,
                            leftRadius: leftRadius,
                            rightRadius: rightRadius,
                            pillLeft: pillLeft,
                            liftT: _liftCtrl.value,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabRowDim(
    BuildContext context, {
    required bool isDark,
    required Color accent,
    required double collapseT,
  }) {
    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: List.generate(widget.tabs.length, (i) {
            final isFirst = i == 0;
            final isLast = i == widget.tabs.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: isFirst ? kInnerPillMargin * 0.5 : 0,
                  right: isLast ? kInnerPillMargin * 0.5 : 0,
                ),
                child: Center(
                  child: _buildTabItem(context,
                      index: i,
                      isDark: isDark,
                      accent: accent,
                      collapseT: collapseT,
                      useMeasurementKey: true),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTabRowBright(
    BuildContext context, {
    required bool isDark,
    required Color accent,
    required double collapseT,
    required double pillLeft,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: List.generate(widget.tabs.length, (i) {
        final isFirst = i == 0;
        final isLast = i == widget.tabs.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: isFirst ? kInnerPillMargin * 0.5 : 0,
              right: isLast ? kInnerPillMargin * 0.5 : 0,
            ),
            child: Center(
              child: _buildTabItem(context,
                  index: i,
                  isDark: isDark,
                  accent: accent,
                  collapseT: collapseT,
                  useMeasurementKey: false),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGlassPillWithClippedRow(
    BuildContext context, {
    required bool isDark,
    required Color accent,
    required double collapseT,
    required double leftRadius,
    required double rightRadius,
    required double pillLeft,
    required double liftT,
  }) {
    final iridOp = _iridOpacityCtrl.value;
    final iridAngle = _iridCtrl.value * 2 * math.pi;

    final isGlass = liftT > 0.01 ||
        _isDragging ||
        _previewPillX != null ||
        !_pillSettled ||
        _stretchCtrl.isAnimating;

    return LayoutBuilder(builder: (context, constraints) {
      final pillWidth = constraints.maxWidth;
      final barWidth = _barWidth > 0 ? _barWidth : pillWidth;
      final rowOffsetX = -(pillLeft - kInnerPillMargin);

      final expandedRadius =
          (leftRadius * 1.8) + (kOuterPillHeight * 0.6) * _liftCtrl.value;
      final pillBorderRadius =
          BorderRadius.all(Radius.circular(expandedRadius));

      final brightRow = IgnorePointer(
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: barWidth,
            minWidth: barWidth,
            child: Transform.translate(
              offset: Offset(rowOffsetX, 0),
              child: SizedBox(
                width: barWidth,
                height: double.infinity,
                child: RepaintBoundary(
                  key: _brightRowKey,
                  child: _buildTabRowBright(context,
                      isDark: isDark,
                      accent: accent,
                      collapseT: collapseT,
                      pillLeft: pillLeft),
                ),
              ),
            ),
          ),
        ),
      );

      if (!isGlass) {
        return ClipRRect(
          borderRadius: pillBorderRadius,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(
              color: isDark ? const Color(0x22FFFFFF) : const Color(0x1E000000),
            ),
            brightRow,
          ]),
        );
      }

      return ClipRRect(
        borderRadius: pillBorderRadius,
        child: Stack(fit: StackFit.expand, children: [
          brightRow,
          if (_tabRowSnapshot != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GelEdgePainter(
                    image: _tabRowSnapshot!,
                    pillLeft: pillLeft - kInnerPillMargin,
                    pillWidth: pillWidth,
                    barWidth: barWidth,
                    leftRadius: leftRadius,
                    rightRadius: rightRadius,
                  ),
                ),
              ),
            ),
          if (iridOp > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GlassPillPainter(
                    isDark: isDark,
                    liftT: 0.0,
                    iridOpacity: iridOp,
                    iridAngle: iridAngle,
                    radius: math.min(leftRadius, rightRadius),
                  ),
                ),
              ),
            ),
          if (_impactCtrl.value > 0.001)
            Positioned.fill(
              child: CustomPaint(
                painter: ImpactRipplePainter(
                  progress: _impactRipple.value,
                  radius: math.min(leftRadius, rightRadius),
                  isDark: isDark,
                ),
              ),
            ),
        ]),
      );
    });
  }

  Widget _buildTabItem(
    BuildContext context, {
    required int index,
    required bool isDark,
    required Color accent,
    required double collapseT,
    bool useMeasurementKey = true,
  }) {
    final tab = widget.tabs[index];
    final isActive = index == _displayIndex;
    final isOverlayActive = isActive && !useMeasurementKey;
    final isBaseActive = isActive && useMeasurementKey;
    final tabAccent = tab.accentColor ?? accent;

    const appleBlueLight = Color(0xFF007AFF);
    const appleBlueDark = Color(0xFF0A84FF);
    final inactiveGrey =
        isDark ? const Color(0xFFF4F3F5) : const Color(0xFF19181D);

    final selectedColor =
        Color.lerp(tabAccent, isDark ? appleBlueDark : appleBlueLight, 0.8)!;

    final effectivePillX =
        _previewPillX ?? (_isDragging ? _pillX : _pillCtrl.value);
    final pillCentre = effectivePillX + (_resolvedPillWidth() ?? 0) / 2;
    final isInteractivePreview = _previewPillX != null || _isDragging;
    final isUnderPill = isInteractivePreview &&
        !isActive &&
        _previewPillX != null &&
        (_tabCentres.length > index) &&
        (_tabCentres[index] - effectivePillX).abs() < (_pillWidth / 2) &&
        index != _displayIndex;

    int? hoveredPreviewIndex;
    if (_tabCentres.isNotEmpty && (_previewPillX != null || _isDragging)) {
      final hoverThreshold = (_resolvedPillWidth() ?? 0) * 0.6;
      var bestDistance = double.infinity;
      for (int i = 0; i < _tabCentres.length; i++) {
        if (i == _displayIndex) continue;
        final distance = (pillCentre - _tabCentres[i]).abs();
        if (distance < hoverThreshold && distance < bestDistance) {
          bestDistance = distance;
          hoveredPreviewIndex = i;
        }
      }
    }

    final showHoverAccent = index == hoveredPreviewIndex;
    final suppressActiveAccent = hoveredPreviewIndex != null;

    double accentBlendT = 0.0;
    if (!isActive && isInteractivePreview && index < _tabCentres.length) {
      final halfPill = (_resolvedPillWidth() ?? 0) / 2;
      final centerDistance = (pillCentre - _tabCentres[index]).abs();
      final edgeBand = (_resolvedPillWidth() ?? 0) * 0.50;
      final edgeContactRaw = ((halfPill + edgeBand - centerDistance) / edgeBand)
          .clamp(0.0, 1.0)
          .toDouble();
      final edgeAccent =
          math.pow(Curves.easeOut.transform(edgeContactRaw), 1.8).toDouble() *
              0.42;
      final bodyOverlapRaw =
          ((halfPill * 0.58 - centerDistance) / (halfPill * 0.24))
              .clamp(0.0, 1.0)
              .toDouble();
      final bodyAccent =
          math.pow(Curves.easeInOut.transform(bodyOverlapRaw), 0.78).toDouble();
      accentBlendT = math.max(edgeAccent, bodyAccent);
      if (showHoverAccent) accentBlendT = 1.0;
    }

    final inactiveBaseColor =
        isUnderPill ? inactiveGrey.withValues(alpha: 0.25) : inactiveGrey;
    final previewAccentColor =
        Color.lerp(inactiveBaseColor, selectedColor, accentBlendT)!;

    final overlayReady = !_isDragging &&
        _previewPillX == null &&
        _tabCentres.length > _displayIndex &&
        (pillCentre - _tabCentres[_displayIndex]).abs() < 2.0;

    final activeBaseColor = selectedColor.withValues(
        alpha: isBaseActive && overlayReady ? 0.18 : 1.0);

    final iconColor = isOverlayActive
        ? selectedColor
        : isActive && !suppressActiveAccent
            ? activeBaseColor
            : previewAccentColor;
    final labelColor = isOverlayActive
        ? selectedColor
        : isActive && !suppressActiveAccent
            ? activeBaseColor
            : previewAccentColor;

    return Semantics(
      label: tab.semanticLabel ?? tab.label,
      selected: isActive,
      button: true,
      child: GestureDetector(
        onTap: () => _onTabTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: kTabHorizontalPadding, vertical: 6),
          child: Column(
            key: useMeasurementKey ? _tabKeys[index] : null,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 200),
                tween: ColorTween(end: iconColor),
                builder: (context, c, _) => Icon(tab.icon, color: c, size: 28),
              ),
              const SizedBox(height: 1),
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 200),
                tween: ColorTween(end: labelColor),
                builder: (context, c, _) => Text(
                  tab.label,
                  style: TextStyle(
                      color: c,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GelBackdropPainter
// ─────────────────────────────────────────────────────────────────────────────
class _GelBackdropPainter extends CustomPainter {
  const _GelBackdropPainter({
    required this.isDark,
    required this.radius,
    required this.expandT,
    required this.liftT,
  });

  final bool isDark;
  final double radius;
  final double expandT;
  final double liftT;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final bottomRect =
        Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4);
    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x00000000),
          isDark
              ? Color.fromRGBO(0, 0, 0, 0.13 + liftT * 0.07)
              : Color.fromRGBO(0, 0, 0, 0.06 + liftT * 0.04),
        ],
      ).createShader(bottomRect);
    canvas.drawRRect(rr, bottomPaint);

    for (final isLeft in [true, false]) {
      final edgeRect = Rect.fromLTWH(
        isLeft ? 0 : size.width - radius * 0.9,
        0,
        radius * 0.9,
        size.height,
      );
      final edgePaint = Paint()
        ..shader = LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            isDark
                ? Color.fromRGBO(0, 0, 0, 0.10 + expandT * 0.06)
                : Color.fromRGBO(0, 0, 0, 0.05 + expandT * 0.03),
            const Color(0x00000000),
          ],
        ).createShader(edgeRect);
      canvas.drawRRect(rr, edgePaint);
    }

    if (liftT > 0.01) {
      final shimmerPaint = Paint()
        ..color = Colors.white.withValues(alpha: liftT * 0.04)
        ..blendMode = BlendMode.plus;
      canvas.drawRRect(rr, shimmerPaint);
    }
  }

  @override
  bool shouldRepaint(_GelBackdropPainter old) =>
      old.isDark != isDark ||
      old.radius != radius ||
      old.expandT != expandT ||
      old.liftT != liftT;
}

// ─────────────────────────────────────────────────────────────────────────────
// _GelEdgePainter
// ─────────────────────────────────────────────────────────────────────────────
class _GelEdgePainter extends CustomPainter {
  const _GelEdgePainter({
    required this.image,
    required this.pillLeft,
    required this.pillWidth,
    required this.barWidth,
    required this.leftRadius,
    required this.rightRadius,
  });

  final ui.Image image;
  final double pillLeft;
  final double pillWidth;
  final double barWidth;
  final double leftRadius;
  final double rightRadius;

  static const double _rimZone = 30.0;
  static const double _maxPull = 20.0;
  static const int _slices = 30;

  static double _ease(double t) {
    t = t.clamp(0.0, 1.0);
    return t < 0.5 ? 4 * t * t * t : 1.0 - math.pow(-2 * t + 2, 3) / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scaleX = iw / barWidth;

    canvas.save();
    canvas.clipRRect(RRect.fromLTRBAndCorners(
      0,
      0,
      pillWidth,
      size.height,
      topLeft: Radius.circular(leftRadius),
      bottomLeft: Radius.circular(leftRadius),
      topRight: Radius.circular(rightRadius),
      bottomRight: Radius.circular(rightRadius),
    ));

    final sliceW = _rimZone / _slices;

    for (final isLeft in [true, false]) {
      for (int i = 0; i < _slices; i++) {
        final dstX = isLeft ? i * sliceW : pillWidth - _rimZone + i * sliceW;
        final t = isLeft
            ? i / (_slices - 1).toDouble()
            : 1.0 - i / (_slices - 1).toDouble();
        final pull = _maxPull * (1.0 - _ease(t));
        final srcBarX = pillLeft + dstX + (isLeft ? pull : -pull);
        final srcX = (srcBarX * scaleX).clamp(0.0, iw - sliceW * scaleX);
        final blurSigma = 3.0 * (1.0 - _ease((t * 2.0).clamp(0.0, 1.0)));
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(srcX, 0, sliceW * scaleX, ih),
          Rect.fromLTWH(dstX, 0, sliceW, size.height),
          Paint()
            ..filterQuality = FilterQuality.medium
            ..maskFilter = blurSigma > 0.2
                ? MaskFilter.blur(BlurStyle.normal, blurSigma)
                : null,
        );
      }
    }

    final rrectBorder = RRect.fromLTRBAndCorners(
      0,
      0,
      pillWidth,
      size.height,
      topLeft: Radius.circular(leftRadius),
      bottomLeft: Radius.circular(leftRadius),
      topRight: Radius.circular(rightRadius),
      bottomRight: Radius.circular(rightRadius),
    );

    final hPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0x88FF6EC7),
          Color(0x887B6EFF),
          Color(0x886EDFFF),
          Color(0x886EFF9A),
          Color(0x88FFE86E),
          Color(0x88FF6EC7),
        ],
      ).createShader(Rect.fromLTWH(0, 0, pillWidth, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);

    canvas.drawRRect(rrectBorder, hPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GelEdgePainter old) =>
      old.image != image ||
      old.pillLeft != pillLeft ||
      old.pillWidth != pillWidth ||
      old.barWidth != barWidth;
}

// end of file
