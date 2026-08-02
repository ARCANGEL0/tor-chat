/// Persistent user appearance + preferences. Stored as JSON in
/// shared_preferences and owned by [ThemeController].
class AppSettings {
  /// Tor-ish purple used as the default accent (buttons/primary).
  static const int defaultAccent = 0xFF7C3FED;

  /// Default logo/brand color (rgb(93, 59, 133)).
  static const int defaultLogoColor = 0xFF5D3B85;

  static const String modeSystem = 'system';
  static const String modeLight = 'light';
  static const String modeDark = 'dark';

  /// Primary/interactive color (buttons, toggles, highlights, FAB). Seeds the
  /// whole color scheme.
  int accentColor;

  /// One of [modeSystem], [modeLight], [modeDark].
  String themeMode;

  /// Global chat wallpaper. `null` = default accent color; `asset:<name>` =
  /// bundled wallpaper; otherwise an absolute path to a custom image.
  String? globalWallpaper;

  /// Global default profile picture. `null` = bundled default; `asset:<name>`
  /// = bundled pfp; otherwise a custom image path. Per-room personas can
  /// override this.
  String? avatar;

  /// Global default bio, used as the placeholder for new rooms (each room can
  /// have its own bio).
  String? bio;

  /// Per-element color overrides. `null` = use the theme's default.
  int? headerColor; // top bars
  int? background; // main pages
  int? chatBackground; // chat screen when no wallpaper
  int? bubbleMine; // my chat bubbles
  int? bubbleTheirs; // other people's chat bubbles
  int? splashBackground; // booting screen
  int? logoColor; // logo / brand color
  int? mainText; // primary text color
  int? secondaryText; // secondary/muted text color

  /// Chat screen's top bar color (separate from the app-wide header).
  int? chatHeader;

  /// Member list (right panel) colors.
  int? membersText;
  int? membersHeader;
  int? membersBackground;
  int? membersIcon;

  /// Member list background image. `null` = use [membersBackground]; other
  /// values follow the same format as [globalWallpaper].
  String? membersWallpaper;

  /// Text color used on the top app bars of the main pages (home, settings,
  /// theme, …). `null` = theme default.
  int? headerText;

  /// Text color used on the chat screen's top bar.
  int? chatHeaderText;

  /// Main page (home) background image. `null` = use [background]; other
  /// values follow the same format as [globalWallpaper].
  String? mainWallpaper;

  /// Chat input footer ("message area") colors.
  int? inputBar; // footer background
  int? inputTextarea; // the text field fill
  int? inputButton; // the send button
  int? inputAttach; // the attach (image) button

  /// App-wide font family ('sans-serif', 'serif', 'monospace', … or '' for the
  /// platform default). Applied to every screen via the theme.
  String mainFont;

  /// Base text size for the main pages (home, settings, …). Scales the whole
  /// text theme.
  double mainFontSize;

  /// Chat message font family ('' = the main font). Applied to bubbles and the
  /// input field.
  String chatFont;

  /// Chat message text size.
  double chatFontSize;

  /// Optional override for the chat message text color (bubbles).
  int? chatTextColor;

  /// Tor daemon ports.
  int socksPort;
  int controlPort;

  /// Notifications & sound preferences.
  bool notificationsEnabled;
  bool notifSound;
  bool notifVibrate;
  bool soundClick;
  bool soundSend;
  bool soundReceive;

  /// Tor bridges (censorship circumvention).
  bool useBridges;
  String bridges;

  AppSettings({
    required this.accentColor,
    required this.themeMode,
    this.globalWallpaper,
    this.avatar,
    this.bio,
    this.headerColor,
    this.background,
    this.chatBackground,
    this.bubbleMine,
    this.bubbleTheirs,
    this.splashBackground,
    this.logoColor,
    this.mainText,
    this.secondaryText,
    this.chatHeader,
    this.membersText,
    this.membersHeader,
    this.membersBackground,
    this.membersIcon,
    this.membersWallpaper,
    this.headerText,
    this.chatHeaderText,
    this.mainWallpaper,
    this.inputBar,
    this.inputTextarea,
    this.inputButton,
    this.inputAttach,
    this.mainFont = '',
    this.mainFontSize = 14.0,
    this.chatFont = '',
    this.chatFontSize = 15.0,
    this.chatTextColor,
    this.socksPort = 9050,
    this.controlPort = 9051,
    this.notificationsEnabled = true,
    this.notifSound = true,
    this.notifVibrate = true,
    this.soundClick = true,
    this.soundSend = true,
    this.soundReceive = true,
    this.useBridges = false,
    this.bridges = '',
  });

  factory AppSettings.defaults() => AppSettings(
        accentColor: defaultAccent,
        themeMode: modeDark,
        logoColor: defaultLogoColor,
        chatBackground: 0xFF1A0F2E, // very dark purple
      );

  AppSettings copy() => AppSettings(
        accentColor: accentColor,
        themeMode: themeMode,
        globalWallpaper: globalWallpaper,
        avatar: avatar,
        bio: bio,
        headerColor: headerColor,
        background: background,
        chatBackground: chatBackground,
        bubbleMine: bubbleMine,
        bubbleTheirs: bubbleTheirs,
        splashBackground: splashBackground,
        logoColor: logoColor,
        mainText: mainText,
        secondaryText: secondaryText,
        chatHeader: chatHeader,
        membersText: membersText,
        membersHeader: membersHeader,
        membersBackground: membersBackground,
        membersIcon: membersIcon,
        membersWallpaper: membersWallpaper,
        headerText: headerText,
        chatHeaderText: chatHeaderText,
        mainWallpaper: mainWallpaper,
        inputBar: inputBar,
        inputTextarea: inputTextarea,
        inputButton: inputButton,
        inputAttach: inputAttach,
        mainFont: mainFont,
        mainFontSize: mainFontSize,
        chatFont: chatFont,
        chatFontSize: chatFontSize,
        chatTextColor: chatTextColor,
        socksPort: socksPort,
        controlPort: controlPort,
        notificationsEnabled: notificationsEnabled,
        notifSound: notifSound,
        notifVibrate: notifVibrate,
        soundClick: soundClick,
        soundSend: soundSend,
        soundReceive: soundReceive,
        useBridges: useBridges,
        bridges: bridges,
      );

  /// All appearance fields as a JSON map (used by the theme import/export).
  Map<String, dynamic> appearanceJson() => {
        'accent': accentColor,
        'themeMode': themeMode,
        'wallpaper': globalWallpaper,
        'avatar': avatar,
        'header': headerColor,
        'background': background,
        'chatBackground': chatBackground,
        'bubbleMine': bubbleMine,
        'bubbleTheirs': bubbleTheirs,
        'splashBackground': splashBackground,
        'logo': logoColor,
        'text': mainText,
        'secondaryText': secondaryText,
        'headerText': headerText,
        'chatHeaderText': chatHeaderText,
        'mainWallpaper': mainWallpaper,
        'inputBar': inputBar,
        'inputTextarea': inputTextarea,
        'inputButton': inputButton,
        'inputAttach': inputAttach,
        'chatHeader': chatHeader,
        'membersText': membersText,
        'membersHeader': membersHeader,
        'membersBackground': membersBackground,
        'membersIcon': membersIcon,
        'chatText': chatTextColor,
      };

  Map<String, dynamic> toJson() => {
        'accentColor': accentColor,
        'themeMode': themeMode,
        'globalWallpaper': globalWallpaper,
        'avatar': avatar,
        'bio': bio,
        'headerColor': headerColor,
        'background': background,
        'chatBackground': chatBackground,
        'bubbleMine': bubbleMine,
        'bubbleTheirs': bubbleTheirs,
        'splashBackground': splashBackground,
        'logoColor': logoColor,
        'mainText': mainText,
        'secondaryText': secondaryText,
        'chatHeader': chatHeader,
        'membersText': membersText,
        'membersHeader': membersHeader,
        'membersBackground': membersBackground,
        'membersIcon': membersIcon,
        'membersWallpaper': membersWallpaper,
        'headerText': headerText,
        'chatHeaderText': chatHeaderText,
        'mainWallpaper': mainWallpaper,
        'inputBar': inputBar,
        'inputTextarea': inputTextarea,
        'inputButton': inputButton,
        'inputAttach': inputAttach,
        'mainFont': mainFont,
        'mainFontSize': mainFontSize,
        'chatFont': chatFont,
        'chatFontSize': chatFontSize,
        'chatTextColor': chatTextColor,
        'socksPort': socksPort,
        'controlPort': controlPort,
        'notificationsEnabled': notificationsEnabled,
        'notifSound': notifSound,
        'notifVibrate': notifVibrate,
        'soundClick': soundClick,
        'soundSend': soundSend,
        'soundReceive': soundReceive,
        'useBridges': useBridges,
        'bridges': bridges,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        accentColor: json['accentColor'] as int? ?? defaultAccent,
        themeMode: json['themeMode'] as String? ?? modeDark,
        globalWallpaper: json['globalWallpaper'] as String?,
        avatar: json['avatar'] as String?,
        bio: json['bio'] as String?,
        headerColor: json['headerColor'] as int?,
        background: json['background'] as int?,
        chatBackground: json['chatBackground'] as int?,
        bubbleMine: json['bubbleMine'] as int?,
        bubbleTheirs: json['bubbleTheirs'] as int?,
        splashBackground: json['splashBackground'] as int?,
        logoColor: json['logoColor'] as int?,
        mainText: json['mainText'] as int?,
        secondaryText: json['secondaryText'] as int?,
        chatHeader: json['chatHeader'] as int?,
        membersText: json['membersText'] as int?,
        membersHeader: json['membersHeader'] as int?,
        membersBackground: json['membersBackground'] as int?,
        membersIcon: json['membersIcon'] as int?,
        membersWallpaper: json['membersWallpaper'] as String?,
        headerText: json['headerText'] as int?,
        chatHeaderText: json['chatHeaderText'] as int?,
        mainWallpaper: json['mainWallpaper'] as String?,
        inputBar: json['inputBar'] as int?,
        inputTextarea: json['inputTextarea'] as int?,
        inputButton: json['inputButton'] as int?,
        inputAttach: json['inputAttach'] as int?,
        mainFont: json['mainFont'] as String? ?? '',
        mainFontSize: (json['mainFontSize'] as num?)?.toDouble() ?? 14.0,
        chatFont: json['chatFont'] as String? ?? '',
        chatFontSize: (json['chatFontSize'] as num?)?.toDouble() ?? 15.0,
        chatTextColor: json['chatTextColor'] as int?,
        socksPort: json['socksPort'] as int? ?? 9050,
        controlPort: json['controlPort'] as int? ?? 9051,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        notifSound: json['notifSound'] as bool? ?? true,
        notifVibrate: json['notifVibrate'] as bool? ?? true,
        soundClick: json['soundClick'] as bool? ?? true,
        soundSend: json['soundSend'] as bool? ?? true,
        soundReceive: json['soundReceive'] as bool? ?? true,
        useBridges: json['useBridges'] as bool? ?? false,
        bridges: json['bridges'] as String? ?? '',
      );
}
