import 'package:flutter/material.dart';

import '../services/app_assets.dart';
import '../services/image_pick.dart';
import '../widgets/profile_avatar.dart';

const _avatarCanceled = Object();
const _avatarDefault = Object();

/// Result of picking an avatar. `null` value means "use the default picture".
class AvatarPick {
  final String? value;
  const AvatarPick(this.value);
}

/// Full-screen picker for profile pictures. Returns `null` if the user backs
/// out, otherwise an [AvatarPick].
class AvatarPickerScreen extends StatelessWidget {
  final String? current;

  const AvatarPickerScreen({super.key, this.current});

  static Future<AvatarPick?> pick(BuildContext context, {String? current}) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => AvatarPickerScreen(current: current),
      ),
    );
    if (result == null || identical(result, _avatarCanceled)) return null;
    if (identical(result, _avatarDefault)) return const AvatarPick(null);
    return AvatarPick(result as String);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile picture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pick a picture, or use your own:',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _PfpTile(
                avatar: 'asset:${AppAssets.pfp.first}',
                selected:
                    current == null || current == 'asset:${AppAssets.pfp.first}',
                onTap: () => Navigator.of(context).pop(_avatarDefault),
              ),
              for (final name in AppAssets.pfp.skip(1))
                _PfpTile(
                  avatar: 'asset:$name',
                  selected: current == 'asset:$name',
                  onTap: () => Navigator.of(context).pop('asset:$name'),
                ),
              if (current != null && !AppAssets.isAsset(current!))
                _PfpTile(
                  avatar: current,
                  selected: true,
                  onTap: () => Navigator.of(context).pop(current),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () async {
              try {
                final path =
                    await pickAndCropImage(context, circle: true);
                if (path != null && context.mounted) {
                  Navigator.of(context).pop(path);
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not load that picture: $e')),
                );
              }
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Choose from gallery (crop to circle)'),
          ),
        ],
      ),
    );
  }
}

class _PfpTile extends StatelessWidget {
  final String? avatar;
  final bool selected;
  final VoidCallback onTap;

  const _PfpTile({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: Stack(
          children: [
            ProfileAvatar(
              avatar: avatar,
              initial: '',
              size: 56,
              color: scheme.tertiary,
            ),
            if (selected)
              const Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.check_circle,
                    color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
