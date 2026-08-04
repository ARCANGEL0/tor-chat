/// Sticker model representing a single sticker
class Sticker {
  final String id;
  final String packId;
  final String imagePath; // asset path or file path
  final String? name;

  const Sticker({
    required this.id,
    required this.packId,
    required this.imagePath,
    this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'packId': packId,
        'imagePath': imagePath,
        'name': name,
      };

  factory Sticker.fromJson(Map<String, dynamic> json) => Sticker(
        id: json['id'] as String,
        packId: json['packId'] as String,
        imagePath: json['imagePath'] as String,
        name: json['name'] as String?,
      );
}

/// Sticker pack model containing multiple stickers
class StickerPack {
  final String id;
  final String name;
  final String? author;
  final String? imagePath; // pack cover/tray icon
  final List<Sticker> stickers;
  final DateTime addedAt;
  final bool isWhatsApp; // true if imported from WhatsApp

  const StickerPack({
    required this.id,
    required this.name,
    this.author,
    this.imagePath,
    required this.stickers,
    required this.addedAt,
    this.isWhatsApp = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author': author,
        'imagePath': imagePath,
        'stickers': stickers.map((s) => s.toJson()).toList(),
        'addedAt': addedAt.toIso8601String(),
        'isWhatsApp': isWhatsApp,
      };

  factory StickerPack.fromJson(Map<String, dynamic> json) => StickerPack(
        id: json['id'] as String,
        name: json['name'] as String,
        author: json['author'] as String?,
        imagePath: json['imagePath'] as String?,
        stickers: (json['stickers'] as List<dynamic>?)
                ?.map((e) => Sticker.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
            DateTime.now(),
        isWhatsApp: json['isWhatsApp'] as bool? ?? false,
      );
}