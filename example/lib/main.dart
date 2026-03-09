// example/lib/main.dart
import 'package:flutter/material.dart';
import 'package:liquid_kit/liquid_kit.dart';

void main() => runApp(const LiquidKitExampleApp());

class LiquidKitExampleApp extends StatefulWidget {
  const LiquidKitExampleApp({super.key});

  @override
  State<LiquidKitExampleApp> createState() => _LiquidKitExampleAppState();
}

class _LiquidKitExampleAppState extends State<LiquidKitExampleApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'liquid_kit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      home: ExampleHome(
        onToggleTheme: () => setState(() {
          _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
        isDarkMode: _themeMode == ThemeMode.dark ||
            (_themeMode == ThemeMode.system &&
                WidgetsBinding
                    .instance.platformDispatcher.platformBrightness ==
                    Brightness.dark),
      ),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  int _currentIndex = 0;
  final ScrollController _scrollCtrl = ScrollController();
  double _searchHide = 0.0;
  bool _searchFocused = false;
  static const double _kSearchScrollThreshold = 40.0;

  static const _tabs = [
    LiquidGlassTab(icon: Icons.home_rounded,     label: 'Home'),
    LiquidGlassTab(icon: Icons.explore_rounded,  label: 'Explore'),
    LiquidGlassTab(icon: Icons.favorite_rounded, label: 'Activity'),
    LiquidGlassTab(icon: Icons.person_rounded,   label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset.clamp(0.0, _kSearchScrollThreshold);
    final hide   = offset / _kSearchScrollThreshold;
    if ((hide - _searchHide).abs() > 0.005) {
      setState(() => _searchHide = hide);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final contentColor = isDark ? Colors.white : const Color(0xFF19181D);

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF2F2F7),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          _ScrollContent(isDark: isDark, scrollController: _scrollCtrl),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 140,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark
                          ? const Color(0xFF0A0A0F)
                          : const Color(0xFFF2F2F7))
                          .withValues(alpha: 0.92),
                      (isDark
                          ? const Color(0xFF0A0A0F)
                          : const Color(0xFFF2F2F7))
                          .withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Top-bar — slides up & fades when search is focused ──────────
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: AnimatedSlide(
              offset: _searchFocused ? const Offset(0, -1.5) : Offset.zero,
              duration: const Duration(milliseconds: 300),
              curve: _searchFocused ? Curves.easeIn : Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _searchFocused ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: _searchFocused,
                  child: LiquidGlassGroup(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LiquidGlassButton(
                          size: 44,
                          onPressed: widget.onToggleTheme,
                          child: Icon(
                            widget.isDarkMode
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: contentColor,
                            size: 20,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _tabs[_currentIndex].label,
                            key: ValueKey(_currentIndex),
                            style: TextStyle(
                              color: contentColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              height: 44 / 17,
                            ),
                          ),
                        ),
                        LiquidGlassToolbar(
                          onItemTapped: (i) {
                            showLiquidGlassSheet(
                              context: context,
                              detents: const [0.4, 0.92],
                              initialDetent: 0.4,
                              child: _SheetContent(isDark: isDark),
                            );
                          },
                          itemWidth: 40,
                          items: const [
                            LiquidGlassToolbarItem(icon: Icons.tune_rounded),
                            LiquidGlassToolbarItem(icon: Icons.bookmark_rounded),
                            LiquidGlassToolbarItem(icon: Icons.more_horiz_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Search bar — hides on scroll, slides to top on focus ────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: _searchFocused ? Curves.easeInOut : Curves.easeOutCubic,
            top: _searchFocused
                ? topPad + 12
                : topPad + 68 - _searchHide * 56,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              opacity: _searchFocused
                  ? 1.0
                  : (1.0 - _searchHide).clamp(0.0, 1.0),
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_searchFocused && _searchHide > 0.5,
                child: LiquidGlassSearchBar(
                  placeholder: 'Search',
                  onChanged: (_) {},
                  onSubmitted: (_) {},
                  onFocusChanged: (focused) =>
                      setState(() => _searchFocused = focused),
                ),
              ),
            ),
          ),

          // ── Navigation bar — slides down & fades when search focused ────
          Positioned(
            bottom: 20,
            left: 12,
            right: 12,
            child: AnimatedSlide(
              offset: _searchFocused ? const Offset(0, 1.5) : Offset.zero,
              duration: const Duration(milliseconds: 300),
              curve: _searchFocused ? Curves.easeIn : Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _searchFocused ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: _searchFocused,
                  child: LiquidGlassNavigationBar(
                    tabs: _tabs,
                    currentIndex: _currentIndex,
                    onTabChanged: (i) => setState(() => _currentIndex = i),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet demo content
// ─────────────────────────────────────────────────────────────────────────────

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF19181D);
    final subtleColor = textColor.withValues(alpha: 0.4);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 4),
          child: Text('Options',
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              )),
        ),
        ...List.generate(8, (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF007AFF), size: 18),
              ),
              const SizedBox(width: 14),
              Text('Option \${i + 1}',
                  style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('Value', style: TextStyle(color: subtleColor, fontSize: 15)),
            ],
          ),
        )),
      ],
    );
  }
}

class _ScrollContent extends StatelessWidget {
  const _ScrollContent({required this.isDark, required this.scrollController});
  final bool isDark;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final textColor  = isDark ? Colors.white : const Color(0xFF19181D);
    final subtleColor = textColor.withValues(alpha: 0.4);

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: topPad + 130),
        ),
        SliverToBoxAdapter(
          child: _ColourBand(isDark: isDark),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (_, i) => _Row(
              item: _items[i % _items.length],
              textColor: textColor,
              subtleColor: subtleColor,
              isDark: isDark,
            ),
            childCount: _items.length * 3,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }
}

class _ColourBand extends StatelessWidget {
  const _ColourBand({required this.isDark});
  final bool isDark;

  static const _bands = [
    Color(0xFF007AFF),
    Color(0xFF34C759),
    Color(0xFFFF2D55),
    Color(0xFFAF52DE),
    Color(0xFFFF9500),
    Color(0xFF5AC8FA),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Column(
        children: _bands.map((c) => Expanded(
          child: Container(
            color: c.withValues(alpha: isDark ? 0.55 : 0.35),
          ),
        )).toList(),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.textColor,
    required this.subtleColor,
    required this.isDark,
  });

  final _Item item;
  final Color textColor;
  final Color subtleColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2)),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    style: TextStyle(
                        color: subtleColor, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  const _Item(this.icon, this.color, this.title, this.subtitle);
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

const _items = [
  _Item(Icons.blur_on_rounded,           Color(0xFF007AFF), 'Shared backdrop',     'One snapshot per LiquidGlassGroup'),
  _Item(Icons.auto_awesome_rounded,      Color(0xFFFF9500), 'Spring physics',      'Squash-and-stretch motion between tabs'),
  _Item(Icons.touch_app_rounded,         Color(0xFFFF2D55), 'Long-press lift',     'Hold a tab to feel the glass lift off'),
  _Item(Icons.palette_rounded,           Color(0xFFAF52DE), 'Contrast analysis',   'Frosting boosts when backdrop is grey'),
  _Item(Icons.light_mode_rounded,        Color(0xFFFF9500), 'Specular caustics',   'Highlight ramps with press depth'),
  _Item(Icons.color_lens_rounded,        Color(0xFF34C759), 'Shape morph',         'Radius animates with scale on press'),
  _Item(Icons.devices_rounded,           Color(0xFF007AFF), 'Cross-platform',      'iOS, Android, macOS and Web'),
  _Item(Icons.accessibility_new_rounded, Color(0xFF34C759), 'Accessibility',       'Semantic labels and reduced motion'),
  _Item(Icons.code_rounded,              Color(0xFFAF52DE), 'No shader files',     'Pure Canvas and dart:ui only'),
  _Item(Icons.layers_rounded,            Color(0xFFFF2D55), 'No layer artifacts',  'Buttons share one glass source'),
  _Item(Icons.speed_rounded,             Color(0xFFFF9500), 'Single controller',   'Shape, scale, highlight, depth coupled'),
  _Item(Icons.dark_mode_rounded,         Color(0xFF007AFF), 'Light and dark',      'Tap the top-left button to switch'),
  _Item(Icons.blur_circular_rounded,     Color(0xFFFF2D55), 'Gel edge distortion', 'Content warps at the button rim'),
  _Item(Icons.water_drop_rounded,        Color(0xFF34C759), 'Liquid feel',         'Glass that moves like a drop of water'),
  _Item(Icons.motion_photos_on_rounded,  Color(0xFFAF52DE), 'Top-edge veil',       'Gradient protects floating controls'),
];