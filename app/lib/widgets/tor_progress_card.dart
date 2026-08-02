import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tor_engine.dart';

/// Shows live Tor bootstrap progress (reads the daemon's log lines) with a
/// pulsing onion icon.
class TorProgressCard extends StatefulWidget {
  final String title;
  final String? subtitle;

  const TorProgressCard({super.key, required this.title, this.subtitle});

  @override
  State<TorProgressCard> createState() => _TorProgressCardState();
}

class _TorProgressCardState extends State<TorProgressCard> {
  final List<String> _recentLogs = [];
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = TorEngine.instance.logs.listen((line) {
      if (!mounted) return;
      setState(() {
        _recentLogs.insert(0, line);
        if (_recentLogs.length > 6) _recentLogs.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BouncingOnion(size: 46),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(6),
                minHeight: 4,
              ),
            ),
            if (_recentLogs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _recentLogs.take(3).map((l) {
                    final cleaned = l
                        .replaceFirst(RegExp(r'^.*?\[notice\]\s*'), '')
                        .trim();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        cleaned,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BouncingOnion extends StatefulWidget {
  final double size;
  const _BouncingOnion({required this.size});

  @override
  State<_BouncingOnion> createState() => _BouncingOnionState();
}

class _BouncingOnionState extends State<_BouncingOnion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Transform.scale(
          scale: 0.9 + 0.2 * t,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.55),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 18 + 14 * t,
                ),
              ],
            ),
            child: Icon(Icons.wifi_tethering,
                size: widget.size * 0.55, color: scheme.onPrimary),
          ),
        );
      },
    );
  }
}
