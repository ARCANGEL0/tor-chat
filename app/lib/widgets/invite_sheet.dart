import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/room.dart';
import 'app_toast.dart';

/// Bottom sheet showing the room's invite details: onion address, optional password, and a scannable QR code.
class InviteSheet extends StatelessWidget {
  final Room room;

  const InviteSheet({super.key, required this.room});

  String get _qrPayload => 'onionchat://join?onion=${Uri.encodeQueryComponent(room.onion)}'
      '${room.password != null ? '&pass=${Uri.encodeQueryComponent(room.password!)}' : ''}'
      '${room.name.isNotEmpty ? '&name=${Uri.encodeQueryComponent(room.name)}' : ''}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Invite friends',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Share this onion address and optional password.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: QrImageView(
                  data: _qrPayload,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                  curve: Curves.easeOutBack),
              const SizedBox(height: 20),
              _CopyRow(
                icon: Icons.link,
                label: 'Onion address',
                value: room.onion,
                monospace: true,
              ),
              const SizedBox(height: 10),
              if (room.password != null)
                _CopyRow(
                  icon: Icons.key,
                  label: 'Password (optional)',
                  value: room.password!,
                  monospace: true,
                ),
              const SizedBox(height: 10),
              _CopyRow(
                icon: Icons.alternate_email,
                label: 'Room name',
                value: room.name,
              ),
              const SizedBox(height: 10),
              _CopyRow(
                icon: Icons.link,
                label: 'Share link',
                value: _qrPayload,
                monospace: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  const _CopyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: monospace ? 'monospace' : null,
                    letterSpacing: monospace ? 0.5 : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              AppToast.show(context, '$label copied');
            },
          ),
        ],
      ),
    );
  }
}