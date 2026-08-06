import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/room.dart';
import '../services/room_store.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../state/theme_style.dart';
import '../widgets/persona_editor.dart';
import '../widgets/tor_progress_card.dart';
import '../services/tor_engine.dart';
import '../services/chat_client.dart';
import 'chat_screen.dart';

/// Connect to a friend's room by .onion address + optional password.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _onionController = TextEditingController();
  final _passController = TextEditingController();
  final _userController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatar;

  bool _connecting = false;
  bool _showPass = false;
  String? _error;
  String _stage = '';
  String? _qrOnion;

  @override
  void initState() {
    super.initState();
    _loadPersona();
  }

  Future<void> _loadPersona() async {
    final store = await RoomStore.load();
    final tc = ThemeController.instance;
    if (!mounted) return;
    _userController.text = store.username ?? '';
    _bioController.text = store.bio ?? tc.settings.bio ?? '';
    _avatar = tc.settings.avatar;
    setState(() {});
  }

  Future<void> _connect() async {
    final onion = _onionController.text.trim().toLowerCase();
    final password = _passController.text.trim();
    var username = _userController.text.trim();

    if (onion.isEmpty) {
      setState(() => _error = 'Enter the .onion address.');
      return;
    }
    if (!onion.endsWith('.onion')) {
      setState(() => _error = 'Invalid .onion address.');
      return;
    }
    // password is optional

    if (username.isEmpty) {
      username = 'friend';
    }

    setState(() {
      _connecting = true;
      _error = null;
      _stage = 'Connecting…';
    });

    final store = await RoomStore.load();
    await store.setUsername(username);

    final roomId = onion;
    final room = Room(
      id: roomId,
      name: onion,
      onion: onion,
      password: password.isEmpty ? null : password,
      isOwner: false,
      username: username,
      createdAt: DateTime.now(),
      avatar: _avatar,
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
    );

    try {
      setState(() => _stage = 'Connecting to $onion…');
      await RoomController.instance.startClient(room);

      if (RoomController.instance.error != null) {
        setState(() {
          _connecting = false;
          _error = RoomController.instance.error;
        });
        return;
      }
      final controller = RoomController.instance;
      if (controller.error != null) {
        setState(() {
          _connecting = false;
          _error = controller.error;
        });
        return;
      }
      if (!controller.connected) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (controller.error != null) {
          setState(() {
            _connecting = false;
            _error = controller.error;
          });
          return;
        }
      }
      room.onion = controller.room?.onion ?? roomId;
      await store.saveRoom(room);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
      );
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = 'Connection failed: $e';
      });
    }
  }

  Future<void> _scanQr() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _QrScanner(onDetected: _handleQr),
    );
  }

  void _handleQr(String raw) {
    String onion = '';
    String pass = '';
    String name = '';
    try {
      final uri = Uri.tryParse(raw.trim());
      if (uri != null) {
        final params = uri.queryParameters;
        onion = (params['onion'] ?? '').trim().toLowerCase();
        pass = (params['pass'] ?? '').trim();
        name = (params['name'] ?? '').trim();
      }
    } catch (_) {}
    if (onion.isEmpty) {
      if (raw.trim().endsWith('.onion')) {
        onion = raw.trim().toLowerCase();
      }
    }
    if (onion.isEmpty) {
      setState(() => _error = "That QR doesn't look like an OnionChat invite.");
      return;
    }
    _onionController.text = onion;
    _passController.text = pass;
    _qrOnion = onion;
  }

  Future<void> _connectFromQr() async {
    if (_qrOnion == null) return;
    final password = _passController.text.trim();
    var username = _userController.text.trim();

    if (username.isEmpty) {
      username = 'friend';
    }

    setState(() {
      _connecting = true;
      _error = null;
      _stage = 'Connecting…';
    });

    final store = await RoomStore.load();
    await store.setUsername(username);

    final roomId = _qrOnion!;
    final room = Room(
      id: roomId,
      name: roomId,
      onion: roomId,
      password: password.isEmpty ? null : password,
      isOwner: false,
      username: username,
      createdAt: DateTime.now(),
      avatar: _avatar,
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
    );

    try {
      setState(() => _stage = 'Connecting to $_qrOnion…');
      await RoomController.instance.startClient(room);

      if (RoomController.instance.error != null) {
        setState(() {
          _connecting = false;
          _error = RoomController.instance.error;
        });
        return;
      }
      final controller = RoomController.instance;
      if (controller.error != null) {
        setState(() {
          _connecting = false;
          _error = controller.error;
        });
        return;
      }
      if (!controller.connected) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (controller.error != null) {
          setState(() {
            _connecting = false;
            _error = controller.error;
          });
          return;
        }
      }
      room.onion = controller.room?.onion ?? roomId;
      await store.saveRoom(room);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
      );
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = 'Connection failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _onionController.dispose();
    _passController.dispose();
    _userController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _connecting ? _buildProgress() : _buildForm(scheme),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TorProgressCard(
            title: 'Connecting…',
            subtitle: _stage,
          ),
          const SizedBox(height: 16),
          _AppLogView(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildForm(ColorScheme scheme) {
    final style =
        ThemeStyle.fromId(ThemeController.instance.settings.themeStyle);
    final matrix = style == ThemeStyle.matrix;
    final fieldBorder = inputFieldBorder(style, 14,
        width: style.borderWidth > 0 ? style.borderWidth : 1.2);
    final fieldFocused = inputFieldBorder(style, 14, width: 1.8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.call_merge_rounded, color: scheme.tertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enter the .onion address your friend shared with you, '
                'or scan their invite QR code. The app routes your connection '
                'through Tor.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _onionController,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '.onion address',
            hintText: 'e.g. abc123def456ghi789jkl.onion',
            prefixIcon: const Icon(Icons.link),
            border: fieldBorder,
            enabledBorder: fieldBorder,
            focusedBorder: fieldFocused,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passController,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          obscureText: !_showPass,
          decoration: InputDecoration(
            labelText: 'Password (optional)',
            hintText: 'Leave empty if no password',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              tooltip: _showPass ? 'Hide password' : 'Show password',
              icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
            border: fieldBorder,
            enabledBorder: fieldBorder,
            focusedBorder: fieldFocused,
          ),
        ),
        const SizedBox(height: 16),
        PersonaEditor(
          nameController: _userController,
          bioController: _bioController,
          avatar: _avatar,
          onAvatarChanged: (v) => setState(() => _avatar = v),
          avatarLabel: 'friend',
          hint: 'Pick a cool username…',
          bioHint: 'Tell people a bit about yourself…',
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _connecting ? null : _scanQr,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: matrix
                  ? BorderRadius.zero
                  : const BorderRadius.all(Radius.circular(14)),
            ),
            foregroundColor: matrix ? const Color(0xFF00FF41) : null,
            side: matrix
                ? const BorderSide(color: Color(0xFF00FF41), width: 1.2)
                : null,
          ),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Read QR code'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _connecting ? null : _connect,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: matrix
                  ? BorderRadius.zero
                  : const BorderRadius.all(Radius.circular(16)),
            ),
            backgroundColor: matrix ? Colors.transparent : null,
            foregroundColor: matrix ? const Color(0xFF00FF41) : null,
            side: matrix
                ? const BorderSide(color: Color(0xFF00FF41), width: 1.2)
                : null,
          ),
          icon: const Icon(Icons.call_merge_rounded),
          label: const Text(
            'Connect',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AppLogView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String>(
      valueListenable: TorEngine.instance.lastLogNotifier,
      builder: (context, lastLog, _) {
        if (lastLog.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Log',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lastLog
                    .replaceFirst(RegExp(r'^.*?\[notice\]\s*'), '')
                    .trim(),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QrScanner extends StatefulWidget {
  final void Function(String) onDetected;

  const _QrScanner({required this.onDetected});

  @override
  State<_QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<_QrScanner> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.white),
                const SizedBox(width: 10),
                const Text(
                  'Scan invite QR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  if (_handled) return;
                  for (final b in capture.barcodes) {
                    final raw = b.rawValue;
                    if (raw == null || raw.isEmpty) continue;
                    _handled = true;
                    widget.onDetected(raw);
                    Navigator.of(context).pop();
                    break;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}