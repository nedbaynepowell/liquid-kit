// example/lib/main.dart
import 'package:flutter/material.dart';
import 'package:liquid_kit/liquid_kit.dart';

void main() => runApp(const LiquidKitExampleApp());

class LiquidKitExampleApp extends StatelessWidget {
  const LiquidKitExampleApp({super.key});

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
      themeMode: ThemeMode.system,
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  int _currentIndex = 0;

  static const _tabs = [
    LiquidGlassTab(icon: Icons.home_rounded, label: 'Home'),
    LiquidGlassTab(icon: Icons.explore_rounded, label: 'Explore'),
    LiquidGlassTab(icon: Icons.favorite_rounded, label: 'Activity'),
    LiquidGlassTab(icon: Icons.person_rounded, label: 'Profile'),
  ];

  static const _pageLabels = ['Home', 'Explore', 'Activity', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final iconColor = isDark ? Colors.white : const Color(0xFF19181D);
    final titleColor = isDark ? Colors.white : const Color(0xFF19181D);

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // ── Scrollable content behind the glass ──────────────────────
          _PageContent(isDark: isDark),

          // ── Top-left button — menu (no tint) ─────────────────────────
          Positioned(
            top: topPad + 12,
            left: 16,
            child: LiquidGlassButton(
              size: 44,
              tintOpacity: 0.0,
              onPressed: () {},
            ),
          ),

          // ── Top-centre title — changes with tab ───────────────────────
          Positioned(
            top: topPad + 12,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Text(
                  _pageLabels[_currentIndex],
                  key: ValueKey(_currentIndex),
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    height: 44 / 17,
                  ),
                ),
              ),
            ),
          ),

          // ── Top-right button — add (no tint) ─────────────────────────
          Positioned(
            top: topPad + 12,
            right: 16,
            child: LiquidGlassButton(
              size: 44,
              tintOpacity: 0.0,
              onPressed: () {},
              child: Icon(Icons.add_rounded, color: iconColor, size: 22),
            ),
          ),

          // ── Navigation bar ────────────────────────────────────────────
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
// Scrollable content — articles about liquid glass that scroll behind the
// floating buttons so the blur and refraction are clearly visible
// ─────────────────────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  const _PageContent({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final textColor = isDark ? Colors.white : const Color(0xFF19181D);
    final subtleColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF19181D).withValues(alpha: 0.45);
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return ListView(
      padding: EdgeInsets.only(
        top: topPadding + 80,
        bottom: 120,
        left: 20,
        right: 20,
      ),
      children: [
        Text(
          'Liquid Glass',
          style: TextStyle(
            color: textColor,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Apple iOS 26 design language for Flutter',
          style: TextStyle(
            color: subtleColor,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 28),
        ..._articles.map(
              (a) => _ArticleCard(
            title: a.title,
            body: a.body,
            icon: a.icon,
            isDark: isDark,
            textColor: textColor,
            subtleColor: subtleColor,
            cardColor: cardColor,
            borderColor: borderColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Article data
// ─────────────────────────────────────────────────────────────────────────────

class _Article {
  const _Article({
    required this.title,
    required this.body,
    required this.icon,
  });
  final String title;
  final String body;
  final IconData icon;
}

const _articles = [
  _Article(
    icon: Icons.blur_on_rounded,
    title: 'Backdrop blur',
    body: 'Liquid Glass uses a multi-layer backdrop blur to refract the '
        'content behind it. The result is a frosted, translucent surface '
        'that feels physically grounded — you always know what is beneath it.',
  ),
  _Article(
    icon: Icons.auto_awesome_rounded,
    title: 'Spring physics',
    body: 'Every movement is driven by a spring simulation. The selected '
        'pill travels between tabs with squash-and-stretch, the same way '
        'a drop of water deforms as it slides across glass.',
  ),
  _Article(
    icon: Icons.touch_app_rounded,
    title: 'Long-press lift',
    body: 'Hold any button and the glass lifts off the surface. Shadows '
        'deepen, the iridescent border activates, and the element feels '
        'like it is physically between your finger and the screen.',
  ),
  _Article(
    icon: Icons.palette_rounded,
    title: 'Iridescent border',
    body: 'When lifted, a sweep gradient rotates around the glass edge — '
        'simulating the soap-bubble interference pattern you see on real '
        'curved glass when light hits it at an angle.',
  ),
  _Article(
    icon: Icons.light_mode_rounded,
    title: 'Specular caustics',
    body: 'Each glass element has a top-edge specular highlight and a '
        'bottom contact shadow. These shift as the element lifts, creating '
        'a convincing sense of depth and material weight.',
  ),
  _Article(
    icon: Icons.devices_rounded,
    title: 'Cross-platform',
    body: 'liquid_kit runs on iOS, Android, macOS and Web. Use '
        'LiquidGlassMode.adaptive to opt into platform-aware rendering '
        'instead of forcing the same glass treatment everywhere.',
  ),
  _Article(
    icon: Icons.code_rounded,
    title: 'Open constants',
    body: 'All spring and animation constants are exposed in '
        'liquid_glass_physics.dart. Tune stiffness, damping, blur sigma '
        'and pill dimensions globally without forking the package.',
  ),
  _Article(
    icon: Icons.accessibility_new_rounded,
    title: 'Accessibility',
    body: 'The navigation bar exposes semantic labels and selected state, '
        'motion-heavy transitions respect disable-animations, and glass '
        'surfaces adjust their contrast for more legible rendering.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Article card
// ─────────────────────────────────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.isDark,
    required this.textColor,
    required this.subtleColor,
    required this.cardColor,
    required this.borderColor,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool isDark;
  final Color textColor;
  final Color subtleColor;
  final Color cardColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: subtleColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: subtleColor,
                    fontSize: 13,
                    height: 1.5,
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
