import '../models/app_settings.dart';
import 'theme_style.dart';

class ThemeTemplate {
  final ThemeStyle style;
  final AppSettings settings;

  const ThemeTemplate({required this.style, required this.settings});

  String get name => style.label;
  String get imageAsset => style.imageAsset;
}

AppSettings palette({
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