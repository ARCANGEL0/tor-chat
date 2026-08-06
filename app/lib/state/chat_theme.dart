import 'package:flutter/material.dart';

import '../themes/theme_style.dart';

/// Chat-specific colors (message bubbles) exposed through the theme so the
/// user can restyle them independently of the Material scheme. Also carries the
/// active [ThemeStyle] so widgets can derive their shape language.
class ChatTheme extends ThemeExtension<ChatTheme> {
  /// The active shape style for bubbles and surfaces.
  final ThemeStyle style;
  final Color myBubble;
  final Color myBubbleText;
  final Color theirBubble;
  final Color theirBubbleText;
  final Color theirName;

  const ChatTheme({
    this.style = ThemeStyle.def,
    required this.myBubble,
    required this.myBubbleText,
    required this.theirBubble,
    required this.theirBubbleText,
    required this.theirName,
  });

  @override
  ChatTheme copyWith({
    ThemeStyle? style,
    Color? myBubble,
    Color? myBubbleText,
    Color? theirBubble,
    Color? theirBubbleText,
    Color? theirName,
  }) {
    return ChatTheme(
      style: style ?? this.style,
      myBubble: myBubble ?? this.myBubble,
      myBubbleText: myBubbleText ?? this.myBubbleText,
      theirBubble: theirBubble ?? this.theirBubble,
      theirBubbleText: theirBubbleText ?? this.theirBubbleText,
      theirName: theirName ?? this.theirName,
    );
  }

  @override
  ChatTheme lerp(ThemeExtension<ChatTheme>? other, double t) {
    if (other is! ChatTheme) return this;
    return ChatTheme(
      style: other.style,
      myBubble: Color.lerp(myBubble, other.myBubble, t)!,
      myBubbleText: Color.lerp(myBubbleText, other.myBubbleText, t)!,
      theirBubble: Color.lerp(theirBubble, other.theirBubble, t)!,
      theirBubbleText: Color.lerp(theirBubbleText, other.theirBubbleText, t)!,
      theirName: Color.lerp(theirName, other.theirName, t)!,
    );
  }

  static ChatTheme of(BuildContext context) {
    return Theme.of(context).extension<ChatTheme>() ?? _fallback(context);
  }

  static ChatTheme _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChatTheme(
      myBubble: scheme.primary,
      myBubbleText: scheme.onPrimary,
      theirBubble: scheme.surfaceContainerHigh,
      theirBubbleText: scheme.onSurface,
      theirName: scheme.tertiary,
    );
  }
}
