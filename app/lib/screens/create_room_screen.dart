import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/image_pick.dart';
import '../services/app_assets.dart';
import '../models/room.dart';
import '../services/room_store.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../../utils/namegen.dart';
import '../services/onion_identity.dart';
import '../screens/chat_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _nameController = TextEditingController();
  final _passController = TextEditingController();
  final _userController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatar;
  String? _chatPicture;

  bool _creating = false;
  bool _showPass = false;
  String? _error;
  String _stage = '';

  @override
  void initState() {
    super.initState();
    _nameController.text = NameGen.generate();
    _passController.text = NameGen.randomPassword();
    _chatPicture = AppAssets.randomChatPicture();
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

  void _randomizeName() {
    setState(() {
      _nameController.text = NameGen.generate();
      _error = null;
    });
  }

  void _randomizePass() {
    setState(() {
      _passController.text = NameGen.randomPassword();
    });
  }

  Future<void> _uploadChatPicture() async {
    try {
      final path = await pickAndCropImage(context, circle: true);
      if (path == null || !mounted) return;
      setState(() => _chatPicture = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load that picture: $e')),
      );
    }
  }

  void _randomizeChatPicture() {
    setState(() => _chatPicture = AppAssets.randomChatPicture());
  }

  Future<void> _create() async {
    final namecode = _nameController.text.trim().toLowerCase();
    final password = _passController.text.trim();
    var username = _userController.text.trim();

    if (namecode.isEmpty) {
      setState(() => _error = 'Pick a namecode for your room.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Pick a password for your room.');
      return;
    }

    if (username.isEmpty) {
      username = 'host';
    }

    setState(() {
      _creating = true;
      _error = null;
      _stage = 'Starting Tor...';
    });

    final store = await RoomStore.load();
    await store.setUsername(username);

    // Deterministic room ID from namecode + password
    final roomId = OnionIdentity.roomId(namecode, password);

    final room = Room(
      id: roomId,
      namecode: namecode,
      onion: '',
      password: password,
      isOwner: true,
      username: username,
      createdAt: DateTime.now(),
      avatar: _avatar,
      chatPicture: _chatPicture,
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
    );

    try {
      setState(() => _stage = 'Deriving your anonymous address…');
      await RoomController.instance.startHost(room);

      if (RoomController.instance.error != null) {
        setState(() {
          _creating = false;
          _error = RoomController.instance.error;
        });
        return;
      }

      room.onion = RoomController.instance.room?.onion ?? '';
      await store.saveRoom(room);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
      );
    } catch (e) {
      setState(() {
        _creating = false;
        _error = 'Failed to create room: $e';
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
      setState(() => _error = "That QR doesn't look like an OnionChat invite.");
      return;
    }
    _nameController.text = name;
    _passController.text = pass;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passController.dispose();
    _userController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQr,
            tooltip: 'Scan QR invite',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create a private room',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 250.ms),
              const SizedBox(height: 8),
              Text(
                'Share the namecode + password with friends.\nNo servers, no accounts, just Tor.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 250.ms, delay: 50.ms),
              const SizedBox(height: 24),
              _AvatarPicker(
                avatar: _avatar,
                onTap: () async {
                  try {
                    final path = await pickAndCropImage(context, circle: true);
                    if (path != null && mounted) setState(() => _avatar = path);
                  } catch (_) {}
                },
              ).animate().fadeIn(duration: 250.ms, delay: 100.ms),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Room namecode',
                  hintText: 'e.g. golden-raccoon',
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.shuffle),
                    onPressed: _randomizeName,
                    tooltip: 'Randomize',
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ).animate().fadeIn(duration: 250.ms, delay: 150.ms),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passController,
                obscureText: !_showPass,
                decoration: InputDecoration(
                  labelText: 'Room password',
                  hintText: 'e.g. correct-horse-battery',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                      IconButton(
                        icon: const Icon(Icons.shuffle),
                        onPressed: _randomizePass,
                        tooltip: 'Randomize',
                      ),
                    ],
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ).animate().fadeIn(duration: 250.ms, delay: 200.ms),
              const SizedBox(height: 16),
              TextFormField(
                controller: _userController,
                decoration: InputDecoration(
                  labelText: 'Your username',
                  hintText: 'e.g. alice',
                  prefixIcon: const Icon(Icons.person),
                ),
              ).animate().fadeIn(duration: 250.ms, delay: 250.ms),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Bio (optional)',
                  hintText: 'A short description…',
                  prefixIcon: const Icon(Icons.info_outline),
                ),
              ).animate().fadeIn(duration: 250.ms, delay: 300.ms),
              const SizedBox(height: 16),
              _ChatPicturePicker(
                picture: _chatPicture,
                onTap: _uploadChatPicture,
                onRandomize: _randomizeChatPicture,
              ).animate().fadeIn(duration: 250.ms, delay: 350.ms),
              const SizedBox(height: 24),
              if (_error != null)
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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _creating ? null : _create,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_chart),
                label: const Text(
                  'Create Room',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final String? avatar;
  final VoidCallback onTap;

  const _AvatarPicker({required this.avatar, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Stack(
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: scheme.surfaceContainerHighest,
              backgroundImage: avatar != null ? FileImage(File(avatar!)) : null,
              child: avatar == null
                  ? Icon(Icons.person, size: 56, color: scheme.onSurfaceVariant)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 3),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPicturePicker extends StatelessWidget {
  final String? picture;
  final VoidCallback onTap;
  final VoidCallback onRandomize;

  const _ChatPicturePicker({
    required this.picture,
    required this.onTap,
    required this.onRandomize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: scheme.surfaceContainerHighest,
                image: picture != null && picture!.startsWith('asset:')
                    ? DecorationImage(
                        image: AppAssets.chatPictureProvider(
                          picture!,
                          AppAssets.avatarProvider('1'),
                        ),
                        fit: BoxFit.cover,
                      )
                    : (picture != null && !picture!.startsWith('asset:')
                        ? DecorationImage(image: FileImage(File(picture!)), fit: BoxFit.cover)
                        : null),
              ),
              child: picture == null || picture!.isEmpty
                  ? Center(
                      child: Icon(Icons.image, size: 48, color: scheme.onSurfaceVariant),
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.shuffle, color: Colors.white, size: 20),
                    onPressed: onRandomize,
                    tooltip: 'Random picture',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                    onPressed: onTap,
                    tooltip: 'Upload picture',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  MobileScannerController? _controller;
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null) {
      _detected = true;
      Navigator.pop(context);
      widget.onDetected(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Scan QR Invite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Point camera at a QR code containing namecode + password'),
          ),
        ],
      ),
    );
  }
}