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

/// Granular font families ('' = inherit from mainFont).
  String mainHeaderFont;
  String mainChatsFont;
  String chatHeaderFont;
  String chatBubblesFont;
  String memberListFont;
  String settingsFont;
  String splashFont;

  /// Granular font sizes (0 = inherit from mainFontSize).
  double mainHeaderFontSize;
  double mainChatsFontSize;
  double chatHeaderFontSize;
  double chatBubblesFontSize;
  double memberListFontSize;
  double settingsFontSize;
  double splashFontSize;

  /// Granular text colors (null = theme default).
  int? mainHeaderTextColor;
  int? mainChatsTextColor;
  int? chatHeaderTextColor;
  int? memberListTextColor;
  int? chatBubblesTextColor;
  int? settingsTextColor;
  int? splashTextColor;

  /// Optional override for the chat message text color (bubbles).
  int? chatTextColor;

  /// Profile card (the overlay shown when tapping a participant) colors.
  int? profileBackground; // card background
  int? profileText; // username text
  int? profileSecondaryText; // bio / joined time
  int? profileAccent; // avatar ring + icons

  /// Profile card font ('' = inherit from [mainFont]) and text size.
  String profileFont;
  double profileFontSize;

  /// Online/offline presence label colors in the member list.
  int? onlineText; // "ONLINE" label
  int? offlineText; // "OFFLINE" label

  /// System/notification "tips" bubble in the chat (e.g. "started the room",
  /// "has connected", "has disconnected").
  int? noticeColor; // bubble background
  int? noticeText; // bubble text color
  String noticeFont; // '' = inherit from chatFont
  double noticeFontSize;

  /// Custom top-left toast ("Profile saved", errors, etc.).
  int? toastBackground; // toast bubble background
  int? toastText; // toast text color
  String toastFont; // '' = inherit from mainFont
  double toastFontSize;

  /// Kick confirmation card (shown when the host kicks a member).
  int? kickBackground; // card background
  int? kickBorder; // card border
  int? kickTitle; // "Kick <name>?" heading
  int? kickBody; // explanatory text
  int? kickIcon; // warning icon color
  int? kickButton; // Kick button background
  int? kickButtonText; // text on the Kick button
  int? kickCancel; // Cancel button text
  String kickFont; // '' = inherit from mainFont
  double kickFontSize;

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
      this.mainHeaderFont = '',
      this.mainChatsFont = '',
      this.chatHeaderFont = '',
      this.chatBubblesFont = '',
      this.memberListFont = '',
      this.settingsFont = '',
      this.splashFont = '',
      this.mainHeaderFontSize = 0.0,
      this.mainChatsFontSize = 0.0,
      this.chatHeaderFontSize = 0.0,
      this.chatBubblesFontSize = 0.0,
      this.memberListFontSize = 0.0,
      this.settingsFontSize = 0.0,
      this.splashFontSize = 0.0,
      this.mainHeaderTextColor,
      this.mainChatsTextColor,
      this.chatHeaderTextColor,
      this.memberListTextColor,
      this.chatBubblesTextColor,
      this.settingsTextColor,
      this.splashTextColor,
      this.chatTextColor,
      this.profileBackground,
      this.profileText,
      this.profileSecondaryText,
      this.profileAccent,
      this.profileFont = '',
      this.profileFontSize = 15.0,
      this.onlineText,
      this.offlineText,
      this.noticeColor,
      this.noticeText,
      this.noticeFont = '',
      this.noticeFontSize = 12.0,
      this.toastBackground,
      this.toastText,
      this.toastFont = '',
      this.toastFontSize = 13.0,
      this.kickBackground,
      this.kickBorder,
      this.kickTitle,
      this.kickBody,
      this.kickIcon,
      this.kickButton,
      this.kickButtonText,
      this.kickCancel,
      this.kickFont = '',
      this.kickFontSize = 15.0,
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
        background: 0xFF140A1E, // even darker for main pages
        bubbleMine: 0xFF8B5CF6, // lighter indigo/purple sent bubbles
        bubbleTheirs: 0xFF2A1F4D, // dark purple received bubbles
        headerColor: 0xFF1A0F2E, // dark purple header
        chatHeader: 0xFF1A0F2E, // dark purple chat header
        membersBackground: 0xFF1A0F2E, // dark purple member list
        membersHeader: 0xFFE8DDF4, // light purple header, readable on dark
        membersText: 0xFFE8DDF4, // light purple text for members
        inputBar: 0xFF1A0F2E, // dark purple input footer
        inputTextarea: 0xFF140A1E, // even darker text field
        inputButton: 0xFF5B2DD3, // deep indigo send button
        inputAttach: 0xFF5B2DD3, // deep indigo attach
        mainHeaderFont: '',
        mainChatsFont: '',
        chatHeaderFont: '',
        chatBubblesFont: '',
        memberListFont: '',
        settingsFont: '',
        splashFont: '',
        mainHeaderFontSize: 0.0,
        mainChatsFontSize: 0.0,
        chatHeaderFontSize: 0.0,
        chatBubblesFontSize: 0.0,
        memberListFontSize: 0.0,
        settingsFontSize: 0.0,
        splashFontSize: 0.0,
        mainHeaderTextColor: 0xFFFFFFFF, // white
        mainChatsTextColor: 0xFFE8DDF4, // light purple
        chatHeaderTextColor: 0xFFFFFFFF, // white
        memberListTextColor: 0xFFFFFFFF, // white
        chatBubblesTextColor: 0xFFFFFFFF, // white
        settingsTextColor: 0xFFFFFFFF, // white
        splashTextColor: 0xFFFFFFFF, // white
        profileBackground: 0xFF1A0F2E, // deep dark purple card
        profileText: 0xFFFFFFFF, // white username
        profileSecondaryText: 0xFFCBB8E8, // light purple muted text
        profileAccent: 0xFF7C3FED, // tor purple accent
        profileFont: '',
        profileFontSize: 15.0,
        onlineText: 0xFF39FF14, // neon green ONLINE label
        offlineText: 0xFF9E9E9E, // greyed OUT OFFLINE label
        noticeColor: 0xFF2A1F4D, // dark purple system tips bubble
        noticeText: 0xFFE8DDF4, // light lavender tips text
        noticeFont: '',
        noticeFontSize: 12.0,
        toastBackground: 0xFF2A1F4D, // dark purple toast bubble
        toastText: 0xFFE8DDF4, // light lavender toast text
        toastFont: '',
        toastFontSize: 13.0,
        kickBackground: 0xFF2A1F4D, // dark purple kick card
        kickBorder: 0xFF8B5CF6, // light indigo border
        kickTitle: 0xFFE8DDF4, // light lavender heading
        kickBody: 0xFFBDB4D6, // muted lavender body
        kickIcon: 0xFFE23A5E, // light crimson red icon
        kickButton: 0xFFE23A5E, // light crimson red Kick button
        kickButtonText: 0xFFFFFFFF, // white button label
        kickCancel: 0xFFCBB8E8, // light purple Cancel
        kickFont: '',
        kickFontSize: 15.0,
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
        mainHeaderFont: mainHeaderFont,
        mainChatsFont: mainChatsFont,
        chatHeaderFont: chatHeaderFont,
        chatBubblesFont: chatBubblesFont,
        memberListFont: memberListFont,
        settingsFont: settingsFont,
        splashFont: splashFont,
        mainHeaderFontSize: mainHeaderFontSize,
        mainChatsFontSize: mainChatsFontSize,
        chatHeaderFontSize: chatHeaderFontSize,
        chatBubblesFontSize: chatBubblesFontSize,
        memberListFontSize: memberListFontSize,
        settingsFontSize: settingsFontSize,
        splashFontSize: splashFontSize,
        mainHeaderTextColor: mainHeaderTextColor,
        mainChatsTextColor: mainChatsTextColor,
        chatHeaderTextColor: chatHeaderTextColor,
        memberListTextColor: memberListTextColor,
        chatBubblesTextColor: chatBubblesTextColor,
        settingsTextColor: settingsTextColor,
        splashTextColor: splashTextColor,
        chatTextColor: chatTextColor,
        profileBackground: profileBackground,
        profileText: profileText,
        profileSecondaryText: profileSecondaryText,
        profileAccent: profileAccent,
        profileFont: profileFont,
        profileFontSize: profileFontSize,
        onlineText: onlineText,
        offlineText: offlineText,
        noticeColor: noticeColor,
        noticeText: noticeText,
        noticeFont: noticeFont,
        noticeFontSize: noticeFontSize,
        toastBackground: toastBackground,
        toastText: toastText,
        toastFont: toastFont,
        toastFontSize: toastFontSize,
        kickBackground: kickBackground,
        kickBorder: kickBorder,
        kickTitle: kickTitle,
        kickBody: kickBody,
        kickIcon: kickIcon,
        kickButton: kickButton,
        kickButtonText: kickButtonText,
        kickCancel: kickCancel,
        kickFont: kickFont,
        kickFontSize: kickFontSize,
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
        'mainFont': mainFont,
        'mainFontSize': mainFontSize,
        'chatFont': chatFont,
        'chatFontSize': chatFontSize,
        'mainHeaderFont': mainHeaderFont,
        'mainChatsFont': mainChatsFont,
        'chatHeaderFont': chatHeaderFont,
        'chatBubblesFont': chatBubblesFont,
        'memberListFont': memberListFont,
        'settingsFont': settingsFont,
        'splashFont': splashFont,
        'mainHeaderFontSize': mainHeaderFontSize,
        'mainChatsFontSize': mainChatsFontSize,
        'chatHeaderFontSize': chatHeaderFontSize,
        'chatBubblesFontSize': chatBubblesFontSize,
        'memberListFontSize': memberListFontSize,
        'settingsFontSize': settingsFontSize,
        'splashFontSize': splashFontSize,
        'mainHeaderTextColor': mainHeaderTextColor,
        'mainChatsTextColor': mainChatsTextColor,
        'chatHeaderTextColor': chatHeaderTextColor,
        'memberListTextColor': memberListTextColor,
        'chatBubblesTextColor': chatBubblesTextColor,
        'settingsTextColor': settingsTextColor,
        'splashTextColor': splashTextColor,
        'profileBackground': profileBackground,
        'profileText': profileText,
        'profileSecondaryText': profileSecondaryText,
        'profileAccent': profileAccent,
        'profileFont': profileFont,
        'profileFontSize': profileFontSize,
        'onlineText': onlineText,
        'offlineText': offlineText,
        'noticeColor': noticeColor,
        'noticeText': noticeText,
        'noticeFont': noticeFont,
        'noticeFontSize': noticeFontSize,
        'toastBackground': toastBackground,
        'toastText': toastText,
        'toastFont': toastFont,
        'toastFontSize': toastFontSize,
        'kickBackground': kickBackground,
        'kickBorder': kickBorder,
        'kickTitle': kickTitle,
        'kickBody': kickBody,
        'kickIcon': kickIcon,
        'kickButton': kickButton,
        'kickButtonText': kickButtonText,
        'kickCancel': kickCancel,
        'kickFont': kickFont,
        'kickFontSize': kickFontSize,
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
        'mainHeaderFont': mainHeaderFont,
        'mainChatsFont': mainChatsFont,
        'chatHeaderFont': chatHeaderFont,
        'chatBubblesFont': chatBubblesFont,
        'memberListFont': memberListFont,
        'settingsFont': settingsFont,
        'splashFont': splashFont,
        'mainHeaderFontSize': mainHeaderFontSize,
        'mainChatsFontSize': mainChatsFontSize,
        'chatHeaderFontSize': chatHeaderFontSize,
        'chatBubblesFontSize': chatBubblesFontSize,
        'memberListFontSize': memberListFontSize,
        'settingsFontSize': settingsFontSize,
        'splashFontSize': splashFontSize,
        'mainHeaderTextColor': mainHeaderTextColor,
        'mainChatsTextColor': mainChatsTextColor,
        'chatHeaderTextColor': chatHeaderTextColor,
        'memberListTextColor': memberListTextColor,
        'chatBubblesTextColor': chatBubblesTextColor,
        'settingsTextColor': settingsTextColor,
        'splashTextColor': splashTextColor,
        'chatTextColor': chatTextColor,
        'profileBackground': profileBackground,
        'profileText': profileText,
        'profileSecondaryText': profileSecondaryText,
        'profileAccent': profileAccent,
        'profileFont': profileFont,
        'profileFontSize': profileFontSize,
        'onlineText': onlineText,
        'offlineText': offlineText,
        'noticeColor': noticeColor,
        'noticeText': noticeText,
        'noticeFont': noticeFont,
        'noticeFontSize': noticeFontSize,
        'toastBackground': toastBackground,
        'toastText': toastText,
        'toastFont': toastFont,
        'toastFontSize': toastFontSize,
        'kickBackground': kickBackground,
        'kickBorder': kickBorder,
        'kickTitle': kickTitle,
        'kickBody': kickBody,
        'kickIcon': kickIcon,
        'kickButton': kickButton,
        'kickButtonText': kickButtonText,
        'kickCancel': kickCancel,
        'kickFont': kickFont,
        'kickFontSize': kickFontSize,
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
        mainHeaderFont: json['mainHeaderFont'] as String? ?? '',
        mainChatsFont: json['mainChatsFont'] as String? ?? '',
        chatHeaderFont: json['chatHeaderFont'] as String? ?? '',
        chatBubblesFont: json['chatBubblesFont'] as String? ?? '',
        memberListFont: json['memberListFont'] as String? ?? '',
        settingsFont: json['settingsFont'] as String? ?? '',
        splashFont: json['splashFont'] as String? ?? '',
        mainHeaderFontSize: (json['mainHeaderFontSize'] as num?)?.toDouble() ?? 0.0,
        mainChatsFontSize: (json['mainChatsFontSize'] as num?)?.toDouble() ?? 0.0,
        chatHeaderFontSize: (json['chatHeaderFontSize'] as num?)?.toDouble() ?? 0.0,
        chatBubblesFontSize: (json['chatBubblesFontSize'] as num?)?.toDouble() ?? 0.0,
        memberListFontSize: (json['memberListFontSize'] as num?)?.toDouble() ?? 0.0,
        settingsFontSize: (json['settingsFontSize'] as num?)?.toDouble() ?? 0.0,
        splashFontSize: (json['splashFontSize'] as num?)?.toDouble() ?? 0.0,
        mainHeaderTextColor: json['mainHeaderTextColor'] as int?,
        mainChatsTextColor: json['mainChatsTextColor'] as int?,
        chatHeaderTextColor: json['chatHeaderTextColor'] as int?,
        memberListTextColor: json['memberListTextColor'] as int?,
        chatBubblesTextColor: json['chatBubblesTextColor'] as int?,
        settingsTextColor: json['settingsTextColor'] as int?,
        splashTextColor: json['splashTextColor'] as int?,
        chatTextColor: json['chatTextColor'] as int?,
        profileBackground: json['profileBackground'] as int?,
        profileText: json['profileText'] as int?,
        profileSecondaryText: json['profileSecondaryText'] as int?,
        profileAccent: json['profileAccent'] as int?,
        profileFont: json['profileFont'] as String? ?? '',
        profileFontSize: (json['profileFontSize'] as num?)?.toDouble() ?? 15.0,
        onlineText: json['onlineText'] as int?,
        offlineText: json['offlineText'] as int?,
        noticeColor: json['noticeColor'] as int?,
        noticeText: json['noticeText'] as int?,
        noticeFont: json['noticeFont'] as String? ?? '',
        noticeFontSize: (json['noticeFontSize'] as num?)?.toDouble() ?? 12.0,
        toastBackground: json['toastBackground'] as int?,
        toastText: json['toastText'] as int?,
        toastFont: json['toastFont'] as String? ?? '',
        toastFontSize: (json['toastFontSize'] as num?)?.toDouble() ?? 13.0,
        kickBackground: json['kickBackground'] as int?,
        kickBorder: json['kickBorder'] as int?,
        kickTitle: json['kickTitle'] as int?,
        kickBody: json['kickBody'] as int?,
        kickIcon: json['kickIcon'] as int?,
        kickButton: json['kickButton'] as int?,
        kickButtonText: json['kickButtonText'] as int?,
        kickCancel: json['kickCancel'] as int?,
        kickFont: json['kickFont'] as String? ?? '',
        kickFontSize: (json['kickFontSize'] as num?)?.toDouble() ?? 15.0,
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
