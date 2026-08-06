import '../models/app_settings.dart';
import 'theme_style.dart';

/// A preset: a color palette plus a [ThemeStyle] that reshapes bubbles, the
/// input bar, buttons and cards across the app.
class ThemeTemplate {
  final ThemeStyle style;
  final AppSettings settings;

  const ThemeTemplate({required this.style, required this.settings});

  String get name => style.label;
  String get imageAsset => style.imageAsset;
}

/// Bundled templates, in display order. Applying one keeps the user's
/// wallpaper, avatar and non-appearance settings.
final List<ThemeTemplate> themeTemplates = <ThemeTemplate>[
  ThemeTemplate(style: ThemeStyle.def, settings: AppSettings.defaults().copy()),
  ThemeTemplate(
    style: ThemeStyle.midnight,
    settings: _palette(
      style: ThemeStyle.midnight,
      font: 'Comfortaa',
      accentColor: 0xFF4A6CF7,
      background: 0xFF070B1C,
      chatBackground: 0xFF0A1028,
      bubbleMine: 0xFF3B5BDB,
      bubbleTheirs: 0xFF1B2442,
      headerColor: 0xFF0D1430,
      chatHeader: 0xFF0D1430,
      membersBackground: 0xFF0D1430,
      membersHeader: 0xFFE3E9FF,
      membersText: 0xFFE3E9FF,
      inputBar: 0xFF131B3B,
      inputTextarea: 0xFF070B1C,
      inputButton: 0xFF5A7BF7,
      inputAttach: 0xFF5A7BF7,
      mainText: 0xFFFFFFFF,
      secondaryText: 0xFF8E9BD6,
      noticeColor: 0xFF1B2442,
      noticeText: 0xFFB9C4F5,
      toastBackground: 0xFF1B2442,
      toastText: 0xFFE3E9FF,
      profileBackground: 0xFF0D1430,
      profileText: 0xFFFFFFFF,
      profileSecondaryText: 0xFFAAB6E8,
      profileAccent: 0xFF4A6CF7,
      onlineText: 0xFF39FF14,
      offlineText: 0xFF6B7A9E,
      kickBackground: 0xFF1B2442,
      kickBorder: 0xFF4A6CF7,
      kickTitle: 0xFFFFFFFF,
      kickBody: 0xFFAAB6E8,
      kickIcon: 0xFFFF5A5A,
      kickButton: 0xFFE23A5E,
      kickCancel: 0xFFAAB6E8,
    ),
  ),
  ThemeTemplate(
    style: ThemeStyle.matrix,
    settings: _palette(
      style: ThemeStyle.matrix,
      font: 'ShareTechMono',
      accentColor: 0xFF00FF41,
      logoColor: 0xFF00FF41,
      headerText: 0xFF00FF41,
      chatHeaderText: 0xFF00FF41,
      background: 0xFF000000,
      chatBackground: 0xFF041008,
      bubbleMine: 0xFF003B1A,
      bubbleTheirs: 0xFF06230F,
      headerColor: 0xFF001105,
      chatHeader: 0xFF04150A,
      membersBackground: 0xFF04150A,
      membersHeader: 0xFFB7FFCB,
      membersText: 0xFFB7FFCB,
      inputBar: 0xFF0A2412,
      inputTextarea: 0xFF020804,
      inputButton: 0xFF00C853,
      inputAttach: 0xFF00C853,
      mainText: 0xFFE6FFEA,
      secondaryText: 0xFF5E9E73,
      noticeColor: 0xFF06230F,
      noticeText: 0xFF7CF29A,
      toastBackground: 0xFF06230F,
      toastText: 0xFFB7FFCB,
      profileBackground: 0xFF04150A,
      profileText: 0xFFFFFFFF,
      profileSecondaryText: 0xFF7CF29A,
      profileAccent: 0xFF00FF41,
      onlineText: 0xFF00FF41,
      offlineText: 0xFF2E5A3E,
      kickBackground: 0xFF06230F,
      kickBorder: 0xFF00FF41,
      kickTitle: 0xFFB7FFCB,
      kickBody: 0xFF7CF29A,
      kickIcon: 0xFFFF5A5A,
      kickButton: 0xFF00B336,
      kickCancel: 0xFF7CF29A,
    ),
  ),
  ThemeTemplate(
    style: ThemeStyle.lain,
    settings: _palette(
      style: ThemeStyle.lain,
      font: 'VT323',
      accentColor: 0xFFFF0066,
      background: 0xFF050508,
      chatBackground: 0xFF0B0912,
      bubbleMine: 0xFFE6005C,
      bubbleTheirs: 0xFF1E1E1E,
      headerColor: 0xFF12101A,
      chatHeader: 0xFF12101A,
      membersBackground: 0xFF12101A,
      membersHeader: 0xFFE6E6E6,
      membersText: 0xFFE6E6E6,
      inputBar: 0xFF16131E,
      inputTextarea: 0xFF050408,
      inputButton: 0xFFFF0066,
      inputAttach: 0xFF00FFFF,
      mainText: 0xFFFFFFFF,
      secondaryText: 0xFF8A8A8A,
      noticeColor: 0xFF1E1E1E,
      noticeText: 0xFF00FFFF,
      toastBackground: 0xFF1E1E1E,
      toastText: 0xFFE6E6E6,
      profileBackground: 0xFF12101A,
      profileText: 0xFFFFFFFF,
      profileSecondaryText: 0xFF9E9E9E,
      profileAccent: 0xFFFF0066,
      onlineText: 0xFF00FFFF,
      offlineText: 0xFF555555,
      kickBackground: 0xFF1E1E1E,
      kickBorder: 0xFFFF0066,
      kickTitle: 0xFFFFFFFF,
      kickBody: 0xFF9E9E9E,
      kickIcon: 0xFFFF0066,
      kickButton: 0xFFFF0066,
      kickCancel: 0xFF00FFFF,
    ),
  ),
  ThemeTemplate(
    style: ThemeStyle.cyberpunk,
    settings: _palette(
      style: ThemeStyle.cyberpunk,
      font: 'Orbitron',
      accentColor: 0xFFFCE300,
      background: 0xFF04050A,
      chatBackground: 0xFF080A12,
      bubbleMine: 0xFFDC143C,
      bubbleTheirs: 0xFF1A1B26,
      headerColor: 0xFF0E0F18,
      chatHeader: 0xFF0E0F18,
      membersBackground: 0xFF0E0F18,
      membersHeader: 0xFFFCE300,
      membersText: 0xFFFCE300,
      inputBar: 0xFF151924,
      inputTextarea: 0xFF05060B,
      inputButton: 0xFFFCE300,
      inputAttach: 0xFF00F0FF,
      mainText: 0xFFFFFFFF,
      secondaryText: 0xFF8E92A8,
      noticeColor: 0xFF1A1B26,
      noticeText: 0xFFFCE300,
      toastBackground: 0xFF1A1B26,
      toastText: 0xFFFCE300,
      profileBackground: 0xFF0E0F18,
      profileText: 0xFFFFFFFF,
      profileSecondaryText: 0xFFB9BDD6,
      profileAccent: 0xFFFCE300,
      onlineText: 0xFF00F0FF,
      offlineText: 0xFF5A5E75,
      kickBackground: 0xFF1A1B26,
      kickBorder: 0xFFFCE300,
      kickTitle: 0xFFFCE300,
      kickBody: 0xFFB9BDD6,
      kickIcon: 0xFFDC143C,
      kickButton: 0xFFDC143C,
      kickCancel: 0xFFFCE300,
    ),
  ),
  ThemeTemplate(
    style: ThemeStyle.bladerunner,
    settings: _palette(
      style: ThemeStyle.bladerunner,
      font: 'Michroma',
      accentColor: 0xFFFF2A6D,
      background: 0xFF0B0913,
      chatBackground: 0xFF0E0C17,
      bubbleMine: 0xFFC4496B,
      bubbleTheirs: 0xFF12282B,
      headerColor: 0xFF131020,
      chatHeader: 0xFF131020,
      membersBackground: 0xFF131020,
      membersHeader: 0xFFF3D9E5,
      membersText: 0xFFF3D9E5,
      inputBar: 0xFF1B1426,
      inputTextarea: 0xFF0B0913,
      inputButton: 0xFFFF2A6D,
      inputAttach: 0xFFFF6B35,
      mainText: 0xFFFFFFFF,
      secondaryText: 0xFF9C8FAE,
      noticeColor: 0xFF12282B,
      noticeText: 0xFFFF8FB0,
      toastBackground: 0xFF12282B,
      toastText: 0xFFF3D9E5,
      profileBackground: 0xFF131020,
      profileText: 0xFFFFFFFF,
      profileSecondaryText: 0xFFB3A3C4,
      profileAccent: 0xFFFF2A6D,
      onlineText: 0xFF7CF5A0,
      offlineText: 0xFF4C4658,
      kickBackground: 0xFF1A1430,
      kickBorder: 0xFFFF2A6D,
      kickTitle: 0xFFFF8FB0,
      kickBody: 0xFFB3A3C4,
      kickIcon: 0xFFFF5A5A,
      kickButton: 0xFFFF2A6D,
      kickCancel: 0xFFFFB48C,
    ),
  ),
];

AppSettings _palette({
  required ThemeStyle style,
  required int accentColor,
  int? logoColor,
  int? headerText,
  int? chatHeaderText,
  required int background,
  required int chatBackground,
  required int bubbleMine,
  required int bubbleTheirs,
  required int headerColor,
  required int chatHeader,
  required int membersBackground,
  required int membersHeader,
  required int membersText,
  required int inputBar,
  required int inputTextarea,
  required int inputButton,
  required int inputAttach,
  required int mainText,
  required int secondaryText,
  required int noticeColor,
  required int noticeText,
  required int toastBackground,
  required int toastText,
  required int profileBackground,
  required int profileText,
  required int profileSecondaryText,
  required int profileAccent,
  required int onlineText,
  required int offlineText,
  required int kickBackground,
  required int kickBorder,
  required int kickTitle,
  required int kickBody,
  required int kickIcon,
  required int kickButton,
  required int kickCancel,
  String font = '',
}) {
  final s = AppSettings.defaults().copy();
  s.themeStyle = style.id;
  s.mainFont = font;
  s.accentColor = accentColor;
  if (logoColor != null) s.logoColor = logoColor;
  if (headerText != null) s.headerText = headerText;
  if (chatHeaderText != null) s.chatHeaderText = chatHeaderText;
  s.background = background;
  s.chatBackground = chatBackground;
  s.bubbleMine = bubbleMine;
  s.bubbleTheirs = bubbleTheirs;
  s.headerColor = headerColor;
  s.chatHeader = chatHeader;
  s.membersBackground = membersBackground;
  s.membersHeader = membersHeader;
  s.membersText = membersText;
  s.inputBar = inputBar;
  s.inputTextarea = inputTextarea;
  s.inputButton = inputButton;
  s.inputAttach = inputAttach;
  s.mainText = mainText;
  s.secondaryText = secondaryText;
  s.noticeColor = noticeColor;
  s.noticeText = noticeText;
  s.toastBackground = toastBackground;
  s.toastText = toastText;
  s.profileBackground = profileBackground;
  s.profileText = profileText;
  s.profileSecondaryText = profileSecondaryText;
  s.profileAccent = profileAccent;
  s.onlineText = onlineText;
  s.offlineText = offlineText;
  s.kickBackground = kickBackground;
  s.kickBorder = kickBorder;
  s.kickTitle = kickTitle;
  s.kickBody = kickBody;
  s.kickIcon = kickIcon;
  s.kickButton = kickButton;
  s.kickCancel = kickCancel;
  return s;
}
