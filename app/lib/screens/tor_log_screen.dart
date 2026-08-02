import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tor_engine.dart';

/// Shows the Tor daemon's log from the current run, live-updated.
class TorLogScreen extends StatefulWidget {
  const TorLogScreen({super.key});

  @override
  State<TorLogScreen> createState() => _TorLogScreenState();
}

class _TorLogScreenState extends State<TorLogScreen> {
  final List<String> _lines = [];
  StreamSubscription<String>? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = TorEngine.instance.logs.listen((line) {
      if (!mounted) return;
      setState(() => _lines.add(line));
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final text = await TorEngine.instance.readTorLog();
    if (!mounted) return;
    setState(() {
      _lines
        ..clear()
        ..addAll((text ?? '').split('\n').where((l) => l.isNotEmpty));
      _loading = false;
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
    final isRunning = TorEngine.instance.started;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tor logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: _lines.join('\n')),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: scheme.tertiaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              isRunning
                  ? '● Tor is running — live log'
                  : '○ Tor is stopped — showing last log',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _lines.isEmpty
                    ? Center(
                        child: Text(
                          'No Tor log yet.\nStart or join a room to generate one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _lines.length,
                        itemBuilder: (context, i) {
                          final line = _lines[i];
                          final color = line.contains('Error') ||
                                  line.contains('Fatal')
                              ? scheme.error
                              : line.contains('Bootstrapped 100%')
                                  ? Colors.green.shade400
                                  : scheme.onSurfaceVariant;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: SelectableText(
                              line,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
