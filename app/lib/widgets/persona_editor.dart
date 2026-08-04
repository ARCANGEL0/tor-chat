import 'package:flutter/material.dart';

import '../screens/avatar_picker_screen.dart';
import 'profile_avatar.dart';

/// A combined "who am I" editor: a tappable profile picture (opens the picker),
/// a username text field and an optional bio field. Used when
/// creating/joining rooms (per-room persona) and on the global profile.
class PersonaEditor extends StatelessWidget {
  final TextEditingController nameController;

  /// Optional bio field; when null the bio input is hidden.
  final TextEditingController? bioController;
  final String? avatar;
  final ValueChanged<String?> onAvatarChanged;
  final String hint;
  final String? bioHint;
  final String avatarLabel;

  const PersonaEditor({
    super.key,
    required this.nameController,
    required this.avatar,
    required this.onAvatarChanged,
    this.bioController,
    this.hint = 'Pick a username…',
    this.bioHint,
    this.avatarLabel = 'Me',
  });

  Future<void> _pickAvatar(BuildContext context) async {
    final picked = await AvatarPickerScreen.pick(context, current: avatar);
    if (picked != null) onAvatarChanged(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => _pickAvatar(context),
              customBorder: const CircleBorder(),
              child: Stack(
                children: [
                  ProfileAvatar(
                    avatar: avatar,
                    initial: avatarLabel,
                    size: 64,
                    color: scheme.primary,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      child: Icon(Icons.photo_camera,
                          size: 14, color: scheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                enableSuggestions: false,
                autocorrect: false,
                maxLength: 32,
                decoration: InputDecoration(
                  labelText: 'Your username',
                  hintText: hint,
                  helperText: 'Shown to others in the chat',
                  prefixIcon: const Icon(Icons.person),
                  counterText: '',
                  // Disable the default underline to avoid double line
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (bioController != null) ...[
          const SizedBox(height: 14),
          TextField(
            controller: bioController,
            maxLength: 160,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Your bio',
              hintText: bioHint ?? 'Something about you…',
              helperText: 'Shown on your profile to others in the room',
              prefixIcon: const Icon(Icons.notes_outlined),
              counterText: '',
              // Disable the default underline to avoid double line
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
