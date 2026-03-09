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

  static const _tabs = [
    LiquidGlassTab(icon: Icons.home_rounded,     label: 'Home'),
    LiquidGlassTab(icon: Icons.explore_rounded,  label: 'Explore'),
    LiquidGlassTab(icon: Icons.favorite_rounded, label: 'Activity'),
    LiquidGlassTab(icon: Icons.person_rounded,   label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final contentColor = isDark ? Colors.white : const Color(0xFF19181D);

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Scrollable content — gives the glass something to blur over
          _ScrollContent(isDark: isDark),

          // Top-left: light/dark toggle
          Positioned(
            top: topPad + 12,
            left: 16,
            child: LiquidGlassButton(
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
          ),

          // Top-centre: tab title
          Positioned(
            top: topPad + 12,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
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
            ),
          ),

          // Top-right: placeholder action
          Positioned(
            top: topPad + 12,
            right: 16,
            child: LiquidGlassButton(
              size: 44,
              onPressed: () {},
              child: Icon(Icons.add_rounded, color: contentColor, size: 22),
            ),
          ),

          // Navigation bar
          Positioned(
            bottom: 20,
            left: 12,
            right: 12,
            child: LiquidGlassNavigationBar(
              tabs: _tabs,
              currentIndex: _currentIndex,
              onTabChanged: (i) => setState(() => _currentIndex = i),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scroll content — plain rows so the glass has colour and text to blur over
// ─────────────────────────────────────────────────────────────────────────────

class _ScrollContent extends StatelessWidget {
  const _ScrollContent({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final textColor = isDark ? Colors.white : const Color(0xFF19181D);
    final subtleColor = textColor.withValues(alpha: 0.4);

    return ListView.builder(
      padding: EdgeInsets.only(top: topPad + 72, bottom: 140),
      itemCount: _items.length,
      itemBuilder: (_, i) => _Row(
        item: _items[i],
        textColor: textColor,
        subtleColor: subtleColor,
        isDark: isDark,
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
                Text(
                  item.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: subtleColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content data
// ─────────────────────────────────────────────────────────────────────────────

class _Item {
  const _Item(this.icon, this.color, this.title, this.subtitle);
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

const _items = [
  _Item(Icons.blur_on_rounded,           Color(0xFF007AFF), 'Backdrop blur',       'Frosted glass that shows what lies beneath'),
  _Item(Icons.auto_awesome_rounded,      Color(0xFFFF9500), 'Spring physics',      'Squash-and-stretch motion between tabs'),
  _Item(Icons.touch_app_rounded,         Color(0xFFFF2D55), 'Long-press lift',     'Hold a tab to feel the glass lift off'),
  _Item(Icons.palette_rounded,           Color(0xFFAF52DE), 'Iridescent border',   'Soap-bubble sweep gradient on press'),
  _Item(Icons.light_mode_rounded,        Color(0xFFFF9500), 'Specular caustics',   'Light refracts at the gel rim edge'),
  _Item(Icons.color_lens_rounded,        Color(0xFF34C759), 'Per-tab accents',     'Each tab carries its own colour'),
  _Item(Icons.devices_rounded,           Color(0xFF007AFF), 'Cross-platform',      'iOS, Android, macOS and Web'),
  _Item(Icons.accessibility_new_rounded, Color(0xFF34C759), 'Accessibility',       'Semantic labels and reduced motion'),
  _Item(Icons.code_rounded,              Color(0xFFAF52DE), 'Open constants',      'Tune every spring and blur value'),
  _Item(Icons.layers_rounded,            Color(0xFFFF2D55), 'Layered compositing', 'Blur, tint, gel rim and irid in order'),
  _Item(Icons.speed_rounded,             Color(0xFFFF9500), 'Fast spring',         'Stiffness 420, damping 28 by default'),
  _Item(Icons.dark_mode_rounded,         Color(0xFF007AFF), 'Light and dark',      'Tap the top-left button to switch'),
  _Item(Icons.blur_circular_rounded,     Color(0xFFFF2D55), 'Gel edge distortion', 'Content warps at the button rim'),
  _Item(Icons.water_drop_rounded,        Color(0xFF34C759), 'Liquid feel',         'Glass that moves like a drop of water'),
  _Item(Icons.motion_photos_on_rounded,  Color(0xFFAF52DE), 'Impact ripple',       'Shockwave radiates on tab land'),
];