import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/digests/sha3.dart';
import 'package:pointycastle/digests/sha512.dart';

/// Deterministically derives a Tor v3 hidden service identity from a
/// namecode + password, so the `.onion` address is computable on any device
/// with no third-party server involved.
///
/// - The host writes [secretKey] into the hidden service directory before Tor
///   starts, so Tor hosts exactly this identity.
/// - Clients call [onionAddress] to compute the address and connect directly.
class OnionIdentity {
  OnionIdentity._();

  static Uint8List _sha3_256(List<int> input) {
    final digest = SHA3Digest(256);
    digest.update(Uint8List.fromList(input), 0, input.length);
    final out = Uint8List(32);
    digest.doFinal(out, 0);
    return out;
  }

  /// 32-byte ed25519 seed derived from `namecode:password`.
  static List<int> seedFor(String namecode, String password) =>
      _sha3_256(utf8.encode('$namecode:$password'));

  /// The 64-byte expanded ed25519 secret key (scalar || prefix).
  ///
  /// Tor stores the *expanded* secret key, not the raw seed:
  /// `scalar = clamp(SHA512(seed)[0:32])`, `prefix = SHA512(seed)[32:64]`.
  /// On disk Tor writes this as a text file: a `== ed25519v1-secret: type0 ==`
  /// header line followed by a base64 line (the plugin builds that file).
  static Future<Uint8List> secretKey(
    String namecode,
    String password,
  ) async {
    final seed = seedFor(namecode, password);
    final digest = SHA512Digest();
    digest.update(Uint8List.fromList(seed), 0, seed.length);
    final h = Uint8List(64);
    digest.doFinal(h, 0);
    h[0] &= 248;
    h[31] &= 127;
    h[31] |= 64;
    return Uint8List.fromList([...h.sublist(0, 32), ...h.sublist(32, 64)]);
  }

  /// The 32-byte ed25519 public key derived from the same seed. Tor writes it
  /// on disk as a `== ed25519v1-public: type0 ==` header line + a base64 line.
  static Future<Uint8List> publicKey(
    String namecode,
    String password,
  ) async {
    final seed = seedFor(namecode, password);
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    final pub = await pair.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }

  /// The v3 `.onion` address for this namecode + password.
  static Future<String> onionAddress(
    String namecode,
    String password,
  ) async {
    final seed = seedFor(namecode, password);
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    final pub = await pair.extractPublicKey();
    final pubBytes = pub.bytes;

    final checksum = _sha3_256([
      ...utf8.encode('.onion checksum'),
      ...pubBytes,
      _version,
    ]).sublist(0, 2);

    final raw = <int>[...pubBytes, ...checksum, _version];
    final b32 = _base32Encode(Uint8List.fromList(raw)).toLowerCase();
    return '$b32.onion';
  }

  /// True when [value] looks like a Tor v3 onion address.
  static bool isOnionAddress(String value) =>
      RegExp(r'^[a-z2-7]{56}\.onion$').hasMatch(value.trim());

  static const _version = 0x03;

  /// Deterministic room ID (directory name) derived from namecode + password.
  /// Same namecode+password on any device = same directory = Tor reuses same keys = same .onion
  static String roomId(String namecode, String password) {
    final seed = seedFor(namecode, password);
    // Use first 16 bytes of seed as hex for directory name
    return 'room_${_toHex(seed.sublist(0, 16))}';
  }

  static String _toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

final _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

String _base32Encode(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bitsLeft = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | (b & 0xff);
    bitsLeft += 8;
    while (bitsLeft >= 5) {
      out.write(_base32Alphabet[(buffer >> (bitsLeft - 5)) & 0x1f]);
      bitsLeft -= 5;
    }
  }
  if (bitsLeft > 0) {
    out.write(_base32Alphabet[(buffer << (5 - bitsLeft)) & 0x1f]);
  }
  return out.toString();
}
