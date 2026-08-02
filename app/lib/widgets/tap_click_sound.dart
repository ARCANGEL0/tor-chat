import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/sound_service.dart';

/// Plays the UI click sound only when a tap lands on an interactive widget
/// (buttons, list tiles, tappable items) — never for plain scrolling or taps
/// on empty background space.
///
/// It sits at the very top of the widget tree as a translucent [Listener] and,
/// on every pointer-down, re-runs the hit test to see whether the deepest hit
/// widget (or any of its ancestors) handles a tap. If so, the click plays.
class TapClickSound extends StatefulWidget {
  final Widget child;

  const TapClickSound({super.key, required this.child});

  @override
  State<TapClickSound> createState() => _TapClickSoundState();
}

class _TapClickSoundState extends State<TapClickSound> {
  void _onPointerDown(PointerDownEvent event) {
    if (_hitsInteractive(event)) {
      SoundService.instance.click();
    }
  }

  bool _hitsInteractive(PointerDownEvent event) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      event.position,
      event.viewId,
    );
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderObject) continue;
      final creator = target.debugCreator;
      if (creator is DebugCreator) {
        // Walk up from the element that owns this render object to find an
        // enclosing interactive widget.
        var tappable = false;
        creator.element.visitAncestorElements((e) {
          if (_isTappable(e.widget)) {
            tappable = true;
            return false;
          }
          return true;
        });
        if (tappable) return true;
      }
    }
    return false;
  }

  static bool _isTappable(Widget widget) {
    if (widget is GestureDetector) {
      return widget.onTap != null ||
          widget.onTapDown != null ||
          widget.onLongPress != null;
    }
    if (widget is InkWell) return widget.onTap != null;
    if (widget is InkResponse) {
      return widget.onTap != null || widget.onLongPress != null;
    }
    if (widget is ButtonStyleButton) return widget.onPressed != null;
    if (widget is IconButton) return widget.onPressed != null;
    if (widget is ListTile) return widget.onTap != null;
    if (widget is DropdownButton) return widget.onChanged != null;
    if (widget is PopupMenuButton) return true;
    if (widget is Switch) return widget.onChanged != null;
    if (widget is Checkbox) return widget.onChanged != null;
    if (widget is Slider) return widget.onChanged != null;
    if (widget is ChoiceChip) return widget.onSelected != null;
    if (widget is FilterChip) return widget.onSelected != null;
    if (widget is ActionChip) return widget.onPressed != null;
    if (widget is InputChip) {
      return widget.onPressed != null || widget.onDeleted != null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }
}
