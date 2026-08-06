import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/sticker_service.dart';
import 'state/chat_theme.dart';
import 'state/room_controller.dart';
import 'state/theme_controller.dart';
import 'state/theme_style.dart';
import 'widgets/tap_click_sound.dart';
import 'widgets/theme_fx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  // Initialize sticker service and auto-import WhatsApp stickers
  await StickerService.instance.init();
  StickerService.instance.maybeAutoImportWhatsApp();
  // Notifications are non-essential: never let a plugin failure block startup.
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('notification init failed: $e');
  }
  runApp(const OnionChatApp());
  // Android 13+ runtime permission prompt (non-blocking).
  try {
    await NotificationService.instance.ensurePermission();
  } catch (e) {
    debugPrint('notification permission prompt failed: $e');
  }
}

class OnionChatApp extends StatefulWidget {
  const OnionChatApp({super.key});

  @override
  State<OnionChatApp> createState() => _OnionChatAppState();
}

class _OnionChatAppState extends State<OnionChatApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Track foreground so notifications still fire while the app is minimized.
    RoomController.appInForeground =
        state == AppLifecycleState.resumed;
  }

  ThemeData _theme(Color seed, Brightness brightness) {
    final s = ThemeController.instance.settings;
    final dark = brightness == Brightness.dark;

    var scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    if (s.mainText != null) {
      scheme = scheme.copyWith(onSurface: Color(s.mainText!));
    }
    if (s.secondaryText != null) {
      scheme = scheme.copyWith(onSurfaceVariant: Color(s.secondaryText!));
    }

    final headerColor = s.headerColor != null ? Color(s.headerColor!) : null;
    final headerText = s.headerText != null ? Color(s.headerText!) : null;
    final backgroundColor = s.background != null ? Color(s.background!) : null;
    final myBubble = s.bubbleMine != null ? Color(s.bubbleMine!) : null;
    final theirBubble = s.bubbleTheirs != null ? Color(s.bubbleTheirs!) : null;

    final defaultBg = dark ? const Color(0xFF0D0B1E) : scheme.surface;
    final defaultHeader = dark ? const Color(0xFF17122B) : scheme.surface;

    final mainFont = s.mainFont.trim();
    final fontSizeFactor =
        s.mainFontSize > 0 ? s.mainFontSize / 14.0 : 1.0;
    final style = ThemeStyle.fromId(s.themeStyle);
    final cardShape = style.cardShape.toShapeBorder();

    var theme = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: mainFont.isEmpty ? null : mainFont,
      scaffoldBackgroundColor: backgroundColor ?? defaultBg,
      appBarTheme: AppBarTheme(
        backgroundColor: headerColor ?? defaultHeader,
        foregroundColor: headerText ??
            (headerColor != null ? onColor(headerColor) : null),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Shape the whole app from the active theme template.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: style.outlinedFabShape,
      ),
      cardTheme: CardThemeData(
        shape: cardShape,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: style.outlinedButtonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: style.outlinedButtonShape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: style.outlinedButtonShape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: style.inputShape.roundedOrTight,
          borderSide: BorderSide.none,
        ),
      ),
      extensions: [
        ChatTheme(
          style: style,
          myBubble: myBubble ?? const Color(0xFF8B5CF6),
          myBubbleText: myBubble != null ? onColor(myBubble) : Colors.white,
          theirBubble: theirBubble ?? const Color(0xFF2A1F4D),
          theirBubbleText:
              theirBubble != null ? onColor(theirBubble) : const Color(0xFFE8DDF4),
          theirName: scheme.tertiary,
        ),
      ],
    );
    if (fontSizeFactor != 1.0) {
      // The raw ThemeData text theme carries only colors — font geometry comes
      // from the localized englishLike theme, so merge it in first (otherwise
      // apply() trips over null font sizes) before scaling.
      final concrete = theme.textTheme.merge(Typography.englishLike2021);
      theme = theme.copyWith(
        textTheme: concrete.apply(fontSizeFactor: fontSizeFactor),
      );
    }
    return theme;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final tc = ThemeController.instance;
        final seed = tc.accentColor;
        return MaterialApp(
          title: 'OnionChat',
          debugShowCheckedModeBanner: false,
          theme: _theme(seed, Brightness.light),
          darkTheme: _theme(seed, Brightness.dark),
          themeMode: tc.themeMode,
          home: const SplashScreen(),
          // Click sound only on interactive taps (buttons/tiles) — never on
          // scrolling or background taps.
          builder: (context, child) => ThemeFX(
            style: ThemeStyle.fromId(
              ThemeController.instance.settings.themeStyle,
            ),
            child: TapClickSound(child: child!),
          ),
          routes: {
            '/home': (_) => const HomeScreen(),
          },
        );
      },
    );
  }
}
