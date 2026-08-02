import 'package:flutter/material.dart';

import '../services/room_store.dart';
import '../state/theme_controller.dart';
import '../widgets/persona_editor.dart';

/// Full-screen profile editor: change your display name, default profile
/// picture and bio. These are used as the placeholders whenever you create or
/// join a room (each room can then have its own persona).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatar;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await RoomStore.load();
    if (!mounted) return;
    _nameController.text = store.username ?? '';
    _bioController.text = store.bio ?? ThemeController.instance.settings.bio ?? '';
    _avatar = ThemeController.instance.settings.avatar;
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final store = await RoomStore.load();
    await store.setUsername(name);
    await store.setBio(_bioController.text.trim());
    await ThemeController.instance.setAvatar(_avatar);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        actions: [
          TextButton.icon(
            onPressed: _loaded ? _save : null,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: PersonaEditor(
                        nameController: _nameController,
                        bioController: _bioController,
                        avatar: _avatar,
                        onAvatarChanged: (v) => setState(() => _avatar = v),
                        avatarLabel: 'Me',
                        hint: 'Type a cool username…',
                        bioHint: 'Write something about yourself…',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'This is your default identity. When you create or join '
                      'a room you can pick a different name, picture and bio '
                      'just for that room.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
