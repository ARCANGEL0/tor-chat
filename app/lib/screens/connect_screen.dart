import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/room.dart';
import '../services/onion_identity.dart';
import '../services/room_store.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/persona_editor.dart';
import '../widgets/tor_progress_card.dart';
import 'chat_screen.dart';

/// Connect to a friend's room by namecode + password.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _nameController = TextEditingController();
  final _passController = TextEditingController();
  final _userController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatar;

  bool _connecting = false;
  bool _showPass = false;
  String? _error;
  String _stage = '';

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
    final rawName = _nameController.text.trim().toLowerCase();
    final password = _passController.text.trim();
    var username = _userController.text.trim();

    if (rawName.isEmpty) {
      setState(() => _error = 'Enter the room namecode.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Enter the room password.');
      return;
    }
    if (username.isEmpty) {
      username = 'friend';
    }

    setState(() {
      _connecting = true;
      _error = null;
      _stage = 'Starting Tor...';
    });

    final store = await RoomStore.load();
    await store.setUsername(username);

    // A raw .onion address can be entered directly (e.g. a chat.js server),
    // otherwise the onion is derived from the namecode + password.
    final rawOnion = OnionIdentity.isOnionAddress(rawName) ? rawName : '';
    final roomId = rawOnion.isNotEmpty ? rawOnion : OnionIdentity.roomId(rawName, password);
    final room = Room(
      id: roomId,
      namecode: rawOnion.isNotEmpty ? rawOnion : rawName,
      onion: rawOnion,
      password: password,
      isOwner: false,
      username: username,
      createdAt: DateTime.now(),
      avatar: _avatar,
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
    );

    try {
      setState(() => _stage = 'Booting Tor…');
      await RoomController.instance.startClient(room);

      // Wait for the session to establish (ready or error).
      final controller = RoomController.instance;
      if (controller.error != null) {
        setState(() {
          _connecting = false;
          _error = controller.error;
        });
        return;
      }
      if (!controller.connected) {
        // give the async handshake a moment
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (controller.error != null) {
          setState(() {
            _connecting = false;
            _error = controller.error;
          });
          return;
        }
      }

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

  void _handleQr(String raw) {
    String name = '';
    String pass = '';
    try {
      final uri = Uri.tryParse(raw.trim());
      if (uri != null) {
        final params = uri.queryParameters;
        name = (params['name'] ?? '').trim().toLowerCase();
        pass = (params['pass'] ?? '').trim();
      }
    } catch (_) {}
    if (name.isEmpty && pass.isEmpty) {
      setState(() => _error = 'That QR doesn\'t look like an OnionChat invite.');
      return;
    }
    _nameController.text = name;
    _passController.text = pass;
  }

  Future<void> _scanQr() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _QrScanner(onDetected: _handleQr),
    );
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
      padding: const EdgeInsets.only(top: 60),
      child: TorProgressCard(
        title: 'Connecting…',
        subtitle: _stage,
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildForm(ColorScheme scheme) {
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
                'Enter the namecode and password your friend shared with you, '
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
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Room namecode',
            prefixIcon: const Icon(Icons.alternate_email),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passController,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          obscureText: !_showPass,
          decoration: InputDecoration(
            labelText: 'Room password',
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              tooltip: _showPass ? 'Hide password' : 'Show password',
              icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
              borderRadius: BorderRadius.circular(14),
            ),
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
              borderRadius: BorderRadius.circular(16),
            ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _passController.dispose();
    _userController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

/// Full-screen QR scanner that pops on the first detected invite.
class _QrScanner extends StatefulWidget {
  final ValueChanged<String> onDetected;
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
