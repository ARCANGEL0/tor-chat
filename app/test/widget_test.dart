import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onionchat_mobile/models/chat_message.dart';
import 'package:onionchat_mobile/services/chat_protocol.dart';
import 'package:onionchat_mobile/services/onion_identity.dart';
import 'package:onionchat_mobile/services/room_store.dart';
import 'package:onionchat_mobile/utils/namegen.dart';

void main() {
  group('ChatMessage', () {
    test('parses server message with color index', () {
      final m = ChatMessage.fromJson({
        'username': 'alice',
        'color': '2',
        'text': 'hi',
      });
      expect(m.username, 'alice');
      expect(m.rawColor, '2');
      expect(m.text, 'hi');
      expect(m.isSystem, isFalse);
    });

    test('parses system messages', () {
      final m = ChatMessage.fromJson({'type': 'system', 'text': 'alice joined'});
      expect(m.isSystem, isTrue);
      expect(m.text, 'alice joined');
    });
  });

  group('Protocol palette', () {
    test('contains valid hex colors', () {
      for (final c in kUserColorPalette) {
        expect(c & 0xFF000000, 0xFF000000, reason: '$c must be opaque');
      }
    });
  });

  group('NameGen', () {
    test('produces unique namecodes', () {
      final a = NameGen.generate();
      final b = NameGen.generate();
      expect(a, isNot(b));
      expect(a, matches(r'^[a-z]+-[a-z]+-\d{2}$'));
    });

    test('produces passwords with enough entropy', () {
      final p = NameGen.randomPassword();
      expect(p.length, greaterThanOrEqualTo(8));
    });
  });

  group('OnionIdentity', () {
    const name = 'luna-003-secret';
    const pass = 'pass12345';
    // Verified against a real Tor daemon: the hostname file matches this.
    const expectedOnion = 'p4ijvyjduddyugdkhqajc2gb3omh6hnatxhyotmjvqmrr2xtgzhwobid.onion';

    test('derives the onion address deterministically', () async {
      final a = await OnionIdentity.onionAddress(name, pass);
      final b = await OnionIdentity.onionAddress(name, pass);
      expect(a, expectedOnion);
      expect(b, a);
    });

    test('different password -> different onion', () async {
      final a = await OnionIdentity.onionAddress(name, 'other');
      expect(a, isNot(expectedOnion));
    });

    test('secret key uses Tor\'s 64-byte expanded format', () async {
      final sk = await OnionIdentity.secretKey(name, pass);
      final pk = await OnionIdentity.publicKey(name, pass);
      expect(sk.length, 64); // scalar(32) || prefix(32)
      expect(pk.length, 32); // raw ed25519 public key
    });

    test('detects onion addresses', () {
      expect(OnionIdentity.isOnionAddress(expectedOnion), isTrue);
      expect(OnionIdentity.isOnionAddress('luna-003-secret'), isFalse);
      expect(OnionIdentity.isOnionAddress('not.a.onion'), isFalse);
    });
  });

  group('RoomStore message history', () {
    test('persists and reloads messages per room', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await RoomStore.load();

      expect(store.loadMessages('r1'), isEmpty);

      await store.addMessage(
        'r1',
        const ChatMessage(
          type: 'message',
          username: 'alice',
          text: 'hi',
          ts: 't1',
          rawColor: '2',
        ),
      );
      await store.addMessage(
        'r1',
        const ChatMessage(
          type: 'system',
          username: '',
          text: 'alice joined',
          ts: 't2',
        ),
      );

      final msgs = store.loadMessages('r1');
      expect(msgs.length, 2);
      expect(msgs[0].text, 'hi');
      expect(msgs[0].rawColor, '2');
      expect(msgs[0].mine, isFalse);
      expect(msgs[1].isSystem, isTrue);

      // Histories are isolated per room.
      expect(store.loadMessages('other'), isEmpty);
    });

    test('keeps messages marked as mine', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await RoomStore.load();
      await store.addMessage(
        'r1',
        const ChatMessage(
          type: 'message',
          username: 'host',
          text: 'mine',
          ts: 't1',
          mine: true,
        ),
      );
      final msgs = store.loadMessages('r1');
      expect(msgs.single.mine, isTrue);
    });
  });
}
