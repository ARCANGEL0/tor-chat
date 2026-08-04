import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sticker.dart';

/// Service for managing stickers and sticker packs, including WhatsApp import.
class StickerService extends ChangeNotifier {
  StickerService._();
  static final StickerService instance = StickerService._();

  static const _stickersKey = 'sticker_packs';
  static const _whatsAppImportedKey = 'whatsapp_stickers_imported';

  final List<StickerPack> _packs = [];
  bool _initialized = false;
  bool _importing = false;

  List<StickerPack> get packs => List.unmodifiable(_packs);
  bool get initialized => _initialized;
  bool get importing => _importing;

  /// Initialize the sticker service and load saved packs.
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stickersKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _packs.addAll(
            list.map((e) => StickerPack.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    _initialized = true;
    notifyListeners();
  }

  /// Save packs to persistent storage.
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _stickersKey, jsonEncode(_packs.map((p) => p.toJson()).toList()));
  }

  /// Add a new sticker pack.
  Future<void> addPack(StickerPack pack) async {
    _packs.removeWhere((p) => p.id == pack.id);
    _packs.insert(0, pack);
    await _save();
    notifyListeners();
  }

  /// Remove a sticker pack.
  Future<void> removePack(String packId) async {
    _packs.removeWhere((p) => p.id == packId);
    await _save();
    notifyListeners();
  }

  /// Get a pack by ID.
  StickerPack? getPack(String packId) {
    try {
      return _packs.firstWhere((p) => p.id == packId);
    } catch (_) {
      return null;
    }
  }

  /// Import WhatsApp stickers from the device.
  /// Returns the number of packs imported.
  Future<int> importWhatsAppStickers() async {
    if (!Platform.isAndroid) return 0;
    if (_importing) return 0;

    _importing = true;
    notifyListeners();

    int importedCount = 0;
    try {
      const channel = MethodChannel('com.onionchat.onionchat_mobile/stickers');
      final result = await channel.invokeMethod('getWhatsAppStickerPacks');
      
      if (result is List) {
        for (final packData in result) {
          if (packData is Map) {
            final packId = packData['id'] as String? ?? '';
            final packName = packData['name'] as String? ?? 'WhatsApp Pack';
            final trayIcon = packData['trayIcon'] as String?; // base64 encoded
            final stickersData = packData['stickers'] as List? ?? [];

            // Check if already imported
            if (_packs.any((p) => p.id == packId && p.isWhatsApp)) {
              continue;
            }

            final stickers = <Sticker>[];
            for (final stickerData in stickersData) {
              if (stickerData is Map) {
                stickers.add(Sticker(
                  id: stickerData['id'] as String? ?? '',
                  packId: packId,
                  imagePath: stickerData['path'] as String? ?? '',
                  name: stickerData['name'] as String?,
                ));
              }
            }

            if (stickers.isNotEmpty) {
              final pack = StickerPack(
                id: packId,
                name: packName,
                author: 'WhatsApp',
                imagePath: trayIcon,
                stickers: stickers,
                addedAt: DateTime.now(),
                isWhatsApp: true,
              );
              await addPack(pack);
              importedCount++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[StickerService] WhatsApp import failed: $e');
    } finally {
      _importing = false;
      notifyListeners();
    }

    // Mark as imported so we don't auto-import repeatedly
    if (importedCount > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_whatsAppImportedKey, true);
    }

    return importedCount;
  }

  /// Check if WhatsApp stickers have been imported before.
  Future<bool> hasImportedWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_whatsAppImportedKey) ?? false;
  }

  /// Trigger WhatsApp import if not already done (call on app start).
  Future<void> maybeAutoImportWhatsApp() async {
    if (await hasImportedWhatsApp()) return;
    await importWhatsAppStickers();
  }

  /// Send a sticker message through the chat.
  Future<void> sendSticker(String packId, String stickerId) async {
    // This would be implemented to send the sticker through the chat protocol
    // For now, we'll handle it in the chat screen
  }
}