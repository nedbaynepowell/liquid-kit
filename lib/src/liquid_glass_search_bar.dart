// liquid_glass_search_bar.dart
//
// A liquid glass search bar that matches the button aesthetic exactly:
//   • Same blur sigma, same low tint, same top specular arc
//   • Focus state: pill expands height slightly, specular brightens
//   • Typing state: clear button fades in on the right
//   • Cancel: slides in from the right on focus, dismisses keyboard on tap
//   • No independent glass layers — uses BackdropFilter on its own layer

import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show Theme, Brightness, Colors, TextField, TextEditingController, FocusNode, InputDecoration, TextStyle, TextInputAction, InputBorder, OutlineInputBorder, UnderlineInputBorder, Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'liquid_glass_physics.dart';
import 'liquid_glass_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

/// A liquid glass search bar. Matches [LiquidGlassButton] aesthetics.
///
/// ```dart
/// LiquidGlassSearchBar(
///   onChanged: (q) => print(q),
///   onSubmitted: (q) => search(q),
/// )
/// ```
class LiquidGlassSearchBar extends StatefulWidget {
  const LiquidGlassSearchBar({
    super.key,
    this.onChanged,
    this.onSubmitted,
    this.onFocusChanged,
    this.placeholder = 'Search',
    this.height = 44.0,
    this.blurSigma,
    this.isDark,
    this.controller,
    this.focusNode,
    this.autofocus = false,
  });

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<bool>?   onFocusChanged;
  final String  placeholder;
  final double  height;
  final double? blurSigma;
  final bool?   isDark;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<LiquidGlassSearchBar> createState() => _LiquidGlassSearchBarState();
}

class _LiquidGlassSearchBarState extends State<LiquidGlassSearchBar>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  // Focus animation — bar expands slightly, specular brightens.
  late AnimationController _focusCtrl;
  late Animation<double> _focusT;

  // Cancel button slide-in.
  late AnimationController _cancelCtrl;
  late Animation<double> _cancelT;

  // Clear button opacity.
  late AnimationController _clearCtrl;
  late Animation<double> _clearT;

  bool _hasFocus = false;
  bool _hasText  = false;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? TextEditingController();
    _focusNode  = widget.focusNode  ?? FocusNode();

    _focusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _focusT = CurvedAnimation(
      parent: _focusCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _cancelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _cancelT = CurvedAnimation(
      parent: _cancelCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _clearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _clearT = CurvedAnimation(parent: _clearCtrl, curve: Curves.easeOut);

    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode  == null) _focusNode.dispose();
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _focusCtrl.dispose();
    _cancelCtrl.dispose();
    _clearCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _focusNode.hasFocus;
    if (focused == _hasFocus) return;
    setState(() => _hasFocus = focused);
    if (focused) {
      _focusCtrl.forward();
      _cancelCtrl.forward();
    } else {
      _focusCtrl.reverse();
      _cancelCtrl.reverse();
    }
    widget.onFocusChanged?.call(focused);
  }

  void _onTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText == _hasText) return;
    setState(() => _hasText = hasText);
    if (hasText) {
      _clearCtrl.forward();
    } else {
      _clearCtrl.reverse();
    }
  }

  void _cancel() {
    _controller.clear();
    _focusNode.unfocus();
    widget.onChanged?.call('');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark ?? Theme.of(context).brightness == Brightness.dark;
    final theme  = LiquidGlassTheme.of(context);
    final blur   = widget.blurSigma ?? theme?.resolvedBlurSigma ?? kBlurSigma;

    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF19181D).withValues(alpha: 0.4);
    final textColor = isDark ? Colors.white : const Color(0xFF19181D);
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF19181D).withValues(alpha: 0.35);

    return AnimatedBuilder(
      animation: Listenable.merge([_focusT, _cancelT, _clearT]),
      builder: (context, _) {
        final f = _focusT.value;

        return Row(
          children: [
            // ── Glass pill ───────────────────────────────────────────────
            Expanded(
              child: SizedBox(
                height: widget.height + f * 4,
                child: Stack(
                  children: [
                    // Blur layer — own compositing layer
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            (widget.height + f * 4) / 2),
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

                    // Glass surface
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            (widget.height + f * 4) / 2),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Tint — same values as button
                            ColoredBox(
                              color: isDark
                                  ? Color.fromRGBO(255, 255, 255,
                                  0.08 + f * 0.04)
                                  : Color.fromRGBO(255, 255, 255,
                                  0.22 + f * 0.06),
                            ),

                            // Surface painter — specular arc + rim
                            CustomPaint(
                              painter: _SearchBarSurfacePainter(
                                isDark: isDark,
                                focusT: f,
                                height: widget.height + f * 4,
                              ),
                            ),

                            // Row: icon · field · clear
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    color: iconColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      onChanged: widget.onChanged,
                                      onSubmitted: widget.onSubmitted,
                                      textInputAction: TextInputAction.search,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.2,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: widget.placeholder,
                                        hintStyle: TextStyle(
                                          color: hintColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      cursorColor: const Color(0xFF007AFF),
                                      cursorWidth: 2,
                                      cursorRadius: const Radius.circular(1),
                                    ),
                                  ),

                                  // Clear button
                                  if (_clearT.value > 0.01)
                                    Opacity(
                                      opacity: _clearT.value,
                                      child: GestureDetector(
                                        onTap: () {
                                          _controller.clear();
                                          widget.onChanged?.call('');
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: Icon(
                                            Icons.cancel_rounded,
                                            color: iconColor,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── X dismiss button — slides in on focus ──────────────────
            ClipRect(
              child: SizedBox(
                width: _cancelT.value * (widget.height + 8),
                child: Opacity(
                  opacity: _cancelT.value,
                  child: GestureDetector(
                    onTap: _cancel,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: widget.height,
                        height: widget.height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchBarSurfacePainter
// Exactly the same language as _ButtonSurfacePainter:
//   • Top specular arc (brightens on focus)
//   • Thin rim stroke
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBarSurfacePainter extends CustomPainter {
  const _SearchBarSurfacePainter({
    required this.isDark,
    required this.focusT,
    required this.height,
  });

  final bool   isDark;
  final double focusT;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    final cx     = size.width  / 2;
    final cy     = size.height / 2;

    // ── Specular arc — top of the pill, same 110° as button ─────────────
    // For a pill shape we draw it as a straight line across the top edge
    // using a linear gradient, which reads more naturally than a sweep arc
    // on a wide rectangle.
    final specAlpha = (isDark ? 0.40 : 0.60) + focusT * 0.20;
    final specRect  = Rect.fromLTWH(radius, 0, size.width - radius * 2, 1.2);
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
          stops: const [0.0, 0.2, 0.8, 1.0],
        ).createShader(specRect),
    );

    // ── Rim stroke ───────────────────────────────────────────────────────
    final rimAlpha = (isDark ? 0.18 : 0.28) + focusT * 0.10;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color       = Color.fromRGBO(255, 255, 255, rimAlpha),
    );
  }

  @override
  bool shouldRepaint(_SearchBarSurfacePainter old) =>
      old.isDark  != isDark  ||
          old.focusT  != focusT  ||
          old.height  != height;
}