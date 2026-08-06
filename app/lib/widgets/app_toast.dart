import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../state/theme_controller.dart';

enum AppToastStyle { info, error }

/// Themed toast pile, top-left, over everything. Newest lands on top and the
/// older ones get shoved down. Each auto-hides after 5 seconds; if the pile
/// gets too tall the oldest just drops off the bottom.
/// Colors/font are customizable in Settings > Theme > Toasts.
class AppToast {
  static final _ToastHost _host = _ToastHost();

  static void show(
    BuildContext context,
    String message, {
    AppToastStyle style = AppToastStyle.info,
    Duration duration = const Duration(seconds: 5),
  }) {
    _host.show(context, message, style: style, duration: duration);
  }
}

class _ToastItem {
  final String message;
  final AppToastStyle style;
  final Duration duration;
  Timer? timer;

  _ToastItem(this.message, this.style, this.duration);
}

/// Everything lives in one AnimatedList so the pile can animate as a unit.
class _ToastHost {
  static const int _maxVisible = 4;

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<_ToastItem> _items = [];

  OverlayState? _overlay;
  OverlayEntry? _entry;

  // How many items the list has actually been told about. Stays ahead of
  // _items only if we announced more than we removed; used to sync the list
  // once its state is live after the first frame.
  int _announced = 0;
  bool _syncScheduled = false;

  void show(
    BuildContext context,
    String message, {
    required AppToastStyle style,
    required Duration duration,
  }) {
    // Never touch the overlay while the tree is mid-build (e.g. a toast fired
    // from initState). Defer to right after the frame instead.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        show(context, message, style: style, duration: duration);
      });
      return;
    }

    _overlay ??= Overlay.of(context, rootOverlay: true);
    if (_entry == null) {
      _entry = _buildEntry();
      _overlay!.insert(_entry!);
    }

    final item = _ToastItem(message, style, duration);
    _items.insert(0, item);
    _announceOne();

    // Too many piled up: kick the oldest off the bottom.
    while (_items.length > _maxVisible) {
      _remove(_items.last, instant: true);
    }

    item.timer = Timer(duration, () => _remove(item));
  }

  OverlayEntry _buildEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 12,
        child: AnimatedList(
          key: _listKey,
          shrinkWrap: true,
          itemBuilder: (context, index, animation) =>
              _ToastAnimated(item: _items[index], animation: animation),
        ),
      ),
    );
  }

  void _announceOne() {
    final state = _listKey.currentState;
    if (state == null) {
      _scheduleSync();
      return;
    }
    state.insertItem(0);
    _announced++;
  }

  // First toasts can arrive before the entry's first frame, when there's no
  // list state yet. Just tell the list how many items exist once it builds.
  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      final state = _listKey.currentState;
      if (state == null) return;
      final delta = _items.length - _announced;
      if (delta > 0) {
        state.insertAllItems(0, delta, isAsync: true);
        _announced += delta;
      }
    });
  }

  void _remove(_ToastItem item, {bool instant = false}) {
    final index = _items.indexOf(item);
    if (index < 0) return;
    item.timer?.cancel();
    _items.removeAt(index);

    final state = _listKey.currentState;
    if (state == null) {
      // Nothing rendered yet, so nothing to animate out.
      return;
    }
    state.removeItem(
      index,
      (context, animation) =>
          _ToastAnimated(item: item, animation: animation, exiting: true),
      duration: instant ? Duration.zero : const Duration(milliseconds: 300),
    );
    _announced--;

    if (_items.isEmpty && _entry != null) {
      final entry = _entry!;
      _entry = null;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (entry.mounted) entry.remove();
      });
    }
  }
}

class _ToastAnimated extends StatelessWidget {
  final _ToastItem item;
  final Animation<double> animation;
  final bool exiting;

  const _ToastAnimated({
    required this.item,
    required this.animation,
    this.exiting = false,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    Widget child = _ToastVisual(item: item);
    if (!exiting) {
      child = SlideTransition(
        position: Tween<Offset>(begin: const Offset(-0.4, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
        child: child,
      );
    }
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

class _ToastVisual extends StatelessWidget {
  final _ToastItem item;

  const _ToastVisual({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = ThemeController.instance.settings;
    final scheme = Theme.of(context).colorScheme;
    final isError = item.style == AppToastStyle.error;
    final bg = isError
        ? scheme.errorContainer
        : (s.toastBackground != null
            ? Color(s.toastBackground!)
            : const Color(0xFF2A1F4D));
    final fg = isError
        ? scheme.onErrorContainer
        : (s.toastText != null ? Color(s.toastText!) : onColor(bg));
    final font = s.toastFont.trim();
    final size = s.toastFontSize;
    final width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: width - 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 18,
                color: isError
                    ? fg
                    : (s.toastBackground != null
                        ? fg
                        : const Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.message,
                  style: TextStyle(
                    color: fg,
                    fontSize: size,
                    fontWeight: FontWeight.w600,
                    fontFamily: font.isEmpty ? null : font,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
