import 'package:flutter/material.dart';

/// Chat-specific colors (message bubbles) exposed through the theme so the
/// user can restyle them independently of the Material scheme.
class ChatTheme extends ThemeExtension<ChatTheme> {
  final Color myBubble;
  final Color myBubbleText;
  final Color theirBubble;
  final Color theirBubbleText;
  final Color theirName;

  const ChatTheme({
    required this.myBubble,
    required this.myBubbleText,
    required this.theirBubble,
    required this.theirBubbleText,
    required this.theirName,
  });

  @override
  ChatTheme copyWith({
    Color? myBubble,
    Color? myBubbleText,
    Color? theirBubble,
    Color? theirBubbleText,
    Color? theirName,
  }) {
    return ChatTheme(
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
