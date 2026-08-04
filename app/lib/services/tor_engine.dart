import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tor_hidden_service/tor_hidden_service.dart';

import '../config.dart';
import '../state/theme_controller.dart';

/// One hidden service this device hosts (a room's deterministic identity).
class HostedService {
  final String roomId;
  final int port;

  const HostedService({
    required this.roomId,
    required this.port,
  });
}

/// Wraps the embedded Tor daemon (tor_hidden_service plugin). A single Tor
/// process serves both roles:
///  - hosting every active room (one hidden service per room), and
///  - a SOCKS proxy (127.0.0.1:9050) used by joined (client) rooms.
///
/// Because Tor reads its hidden services from torrc at startup, changing the
/// set of hosted rooms restarts the daemon with the combined config. The keys
/// are deterministic per room, so each room's `.onion` never changes; this
/// restart only happens when a room is created or removed, never while simply
/// chatting.
class TorEngine extends ChangeNotifier {
  TorEngine._();
  static final TorEngine instance = TorEngine._();

  final _logs = StreamController<String>.broadcast();

  StreamSubscription<String>? _logSub;
  bool _started = false;
  String _lastLog = '';
  final _lastLogNotifier = ValueNotifier<String>('');

  final List<HostedService> _hosted = [];
  final Map<String, String> _onions = {};
  int _clientUsers = 0;

  Future<void> _pendingRestart = Future.value();

  bool get started => _started;

  /// This device's own `.onion` address of the first hosted room.
  String? get onion => _hosted.isEmpty ? null : _onions[_hosted.first.roomId];

  /// `.onion` address for every currently hosted room (room id -> address).
  Map<String, String> get hostedOnions => Map.of(_onions);

  String get lastLog => _lastLog;

  ValueNotifier<String> get lastLogNotifier => _lastLogNotifier;

  Stream<String> get logs => _logs.stream;

  /// The version string of the bundled Tor binary (e.g. "Tor version 0.4.8.x").
  Future<String?> torVersion() => TorHiddenService.getTorVersion();

  /// The Tor log from the current run (used by the Tor logs screen).
  Future<String?> readTorLog() => TorHiddenService.readTorLog();

  /// Restarts Tor completely (stops and restarts with current hosted rooms).
  /// Can be called from UI when user wants to force a Tor restart.
  Future<void> restart() async {
    debugPrint('[TorEngine] Manual restart requested');
    await stop();
    // Re-add the currently hosted services and restart
    if (_hosted.isNotEmpty) {
      final services = List<HostedService>.from(_hosted);
      for (final service in services) {
        await startHosting(service);
      }
    } else if (_clientUsers > 0) {
      // If no hosted rooms but has client connections, just start for client
      await _restart();
    }
  }

  /// Starts the Android foreground service to keep Tor running in background.
  /// Only has effect on Android.
  Future<void> startBackgroundService() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('com.onionchat.onionchat_mobile/tor_background');
      await channel.invokeMethod('startBackgroundService');
      debugPrint('[TorEngine] Android foreground service started');
    } catch (e) {
      debugPrint('[TorEngine] Failed to start background service: $e');
    }
  }

  /// Stops the Android foreground service.
  /// Only has effect on Android.
  Future<void> stopBackgroundService() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('com.onionchat.onionchat_mobile/tor_background');
      await channel.invokeMethod('stopBackgroundService');
      debugPrint('[TorEngine] Android foreground service stopped');
    } catch (e) {
      debugPrint('[TorEngine] Failed to stop background service: $e');
    }
  }

  /// Adds (or updates) a hosted room's hidden service and restarts Tor with the
  /// full set. Returns the room's `.onion` address.
  Future<String> startHosting(HostedService service) async {
    final i = _hosted.indexWhere((h) => h.roomId == service.roomId);
    if (i >= 0) {
      _hosted[i] = service;
    } else {
      _hosted.add(service);
    }
    await _restart();
    return _onions[service.roomId] ?? '';
  }

  /// Removes a hosted room's hidden service. Tor stops when nothing else needs
  /// it (no hosted rooms and no joined rooms).
  Future<void> stopHosting(String roomId) async {
    _hosted.removeWhere((h) => h.roomId == roomId);
    _onions.remove(roomId);
    if (_hosted.isEmpty && _clientUsers == 0) {
      await stop();
      await stopBackgroundService();
    } else {
      await _restart();
    }
  }

  /// Ensures Tor is running for a joined (client) room. Tor is shared across
  /// all joined rooms, so this only starts it once.
  Future<void> startForClient() async {
    _clientUsers++;
    if (!_started) await _restart();
    // Start background service when there's at least one client connection
    // so Tor keeps running when app is backgrounded
    await startBackgroundService();
  }

  /// Releases one joined room's claim on Tor.
  Future<void> stopClient() async {
    if (_clientUsers > 0) _clientUsers--;
    if (_started && _hosted.isEmpty && _clientUsers == 0) {
      await stop();
      await stopBackgroundService();
    }
  }

  Future<void> stop() async {
    if (_started) {
      await TorHiddenService.stop();
      _started = false;
    }
    _hosted.clear();
    _clientUsers = 0;
    _onions.clear();
    await _logSub?.cancel();
    _logSub = null;
    notifyListeners();
  }

  /// Restarts (or first-starts) Tor with the current set of hosted rooms,
  /// serialized so concurrent calls don't race the daemon.
  Future<void> _restart() {
    final prev = _pendingRestart;
    final next = prev.then((_) => _doRestart());
    _pendingRestart = next;
    return next;
  }

  Future<void> _doRestart() async {
    await _stopProcessOnly();
    try {
      _logSub ??= TorHiddenService.onLog.listen((line) {
        _lastLog = line;
        _lastLogNotifier.value = line;
        _logs.add(line);
      });
      final services = [
        for (final h in _hosted)
          {
            'roomId': h.roomId,
            'port': h.port,
          },
      ];
      final hostnames = await TorHiddenService.startTor(
        services: services,
        useBridges: ThemeController.instance.settings.useBridges,
      ).timeout(AppConfig.torStartTimeout);
      _started = true;
      _onions.clear();
      for (var i = 0; i < _hosted.length && i < hostnames.length; i++) {
        _onions[_hosted[i].roomId] = hostnames[i];
      }
      notifyListeners();
    } catch (e) {
      // Make sure no half-started Tor keeps the ports busy on a retry.
      try {
        await TorHiddenService.stop();
      } catch (_) {}
      _started = false;
      rethrow;
    }
  }

  Future<void> _stopProcessOnly() async {
    if (!_started) return;
    await TorHiddenService.stop();
    _started = false;
    _onions.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _logs.close();
    super.dispose();
  }
}