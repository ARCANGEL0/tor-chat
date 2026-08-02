// Integration smoke test for the TorChat networking stack.
//
// Spins up a real Tor daemon (system `tor`) with a hidden service, hosts a
// ChatHost inside, then connects a ChatClient THROUGH TOR via the SOCKS proxy
// and exercises the full protocol. Run from the app/ directory:
//
//   dart run tool/smoke.dart [torBinary]
//
// Exit code 0 = all checks passed.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lib/services/chat_client.dart';
import '../lib/services/chat_host.dart';
import '../lib/models/chat_message.dart';
import '../lib/services/onion_identity.dart';

const int hostPort = 18080;
const int socksPort = 19050;
const String roomNamecode = 'luna-003-secret';
const String roomPassword = 'cs12345';

int passed = 0;
int failed = 0;

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    passed++;
    print('  \x1b[32m[PASS]\x1b[0m $name');
  } else {
    failed++;
    print('  \x1b[31m[FAIL]\x1b[0m $name${detail != null ? '  -> $detail' : ''}');
  }
}

Future<void> main(List<String> args) async {
  final torBin = args.isNotEmpty ? args.first : '/usr/bin/tor';
  if (!File(torBin).existsSync()) {
    stderr.writeln('Tor binary not found: $torBin');
    exit(2);
  }

  final tmpDir = await Directory.systemTemp.createTemp('torchat-smoke');
  final dataDir = await Directory('${tmpDir.path}/data').create();
  final hsDir = await Directory('${tmpDir.path}/hs').create();
  // Tor requires its HiddenServiceDir to be owner-only.
  await Process.run('chmod', ['700', dataDir.path]);
  await Process.run('chmod', ['700', hsDir.path]);

  final torrc = File('${tmpDir.path}/torrc');
  await torrc.writeAsString('''
DataDirectory ${dataDir.path}
SOCKSPort $socksPort
HiddenServiceDir ${hsDir.path}
HiddenServicePort 80 127.0.0.1:$hostPort
Log notice stdout
''');

  print('\x1b[1m=== TorChat smoke test ===\x1b[0m');
  print('[..] Deriving deterministic onion from "$roomNamecode" + password...');
  final expectedOnion = await OnionIdentity.onionAddress(roomNamecode, roomPassword);
  final secretKey = await OnionIdentity.secretKey(roomNamecode, roomPassword);
  check('derived onion is a valid v3 address', OnionIdentity.isOnionAddress(expectedOnion), expectedOnion);
  print('  derived onion: $expectedOnion');

  // Tor hosts exactly the derived identity when the key is pre-seeded. Tor's
  // v3 key files are TEXT files: a header line + a base64 line (the same
  // format the Android plugin writes).
  final keyFile = File('${hsDir.path}/hs_ed25519_secret_key');
  await keyFile.writeAsString(
    '== ed25519v1-secret: type0 ==\n${base64Encode(secretKey)}\n',
  );
  final pubFile = File('${hsDir.path}/hs_ed25519_public_key');
  await pubFile.writeAsString(
    '== ed25519v1-public: type0 ==\n'
    '${base64Encode(await OnionIdentity.publicKey(roomNamecode, roomPassword))}\n',
  );

  print('[..] Starting Tor daemon: $torBin');
  final torProc = await Process.start(torBin, ['-f', torrc.path]);
  final torLog = StringBuffer();
  torProc.stdout.listen((d) => torLog.write(utf8.decode(d, allowMalformed: true)));
  torProc.stderr.listen((d) => torLog.write(utf8.decode(d, allowMalformed: true)));

  // Wait for the onion hostname file (appears once the hidden service is up).
  final hostnameFile = File('${hsDir.path}/hostname');
  String? onion;
  for (var i = 0; i < 120; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (hostnameFile.existsSync()) {
      onion = hostnameFile.readAsStringSync().trim();
      break;
    }
  }

  if (onion == null || !onion.endsWith('.onion')) {
    print('\x1b[31m[FAIL] Timed out waiting for hidden service hostname\x1b[0m');
    print('  --- tor log tail ---');
    print(torLog.toString().split('\n').where((l) => l.trim().isNotEmpty).toList().take(15).join('\n'));
    torProc.kill();
    await tmpDir.delete(recursive: true);
    exit(1);
  }
  print('  \x1b[32m[PASS]\x1b[0m hidden service online: $onion');
  check(
    'Tor hosted the derived onion (deterministic identity)',
    onion == expectedOnion,
    'expected $expectedOnion',
  );

  final host = ChatHost(port: hostPort, password: roomPassword, ownerUsername: 'owner');
  await host.start();

  // A freshly created hidden service descriptor takes ~30-60s to propagate
  // through the Tor network; wait before connecting from the outside.
  print('[..] Waiting for hidden service descriptor propagation...');
  await Future<void>.delayed(const Duration(seconds: 30));

  // ---- client 1: happy path ------------------------------------------------
  print('[..] Connecting client through Tor (SOCKS $socksPort)...');
  // The client derives the onion independently from the namecode + password.
  final client = ChatClient(
    socksHost: '127.0.0.1',
    socksPort: socksPort,
    targetHost: expectedOnion,
    targetPort: 80,
  );

  final hostMessages = <ChatMessage>[];
  host.messages.listen(hostMessages.add);
  final hostJoinRequests = <Map<String, dynamic>>[];
  host.onJoinRequest.listen(hostJoinRequests.add);

  await client.connect(password: roomPassword);
  print('  \x1b[32m[PASS]\x1b[0m SOCKS + WebSocket handshake through Tor');

  final gotPrompt = await waitFor(client.onPrompt, 30000);
  check('auth accepted -> server prompts for username', gotPrompt);

  client.sendUsername('alice');
  final gotJoinRequest = await waitForValue(
    () => hostJoinRequests.any((m) => m['username'] == 'alice'),
    15000,
  );
  check('host sees alice join request awaiting approval', gotJoinRequest);
  host.approveClient('alice');
  final gotReady = await waitFor(client.onReady, 15000);
  check('username accepted -> ready after approval', gotReady);

  client.sendMessage('hello from alice');
  final gotBroadcast = await waitForValue(
    () => hostMessages.any((m) => m.type == 'message' && m.text == 'hello from alice'),
    15000,
  );
  check('host received alice message', gotBroadcast);

  final clientEcho = <ChatMessage>[];
  client.messages.listen(clientEcho.add);
  final gotEcho = await waitForValue(
    () => clientEcho.any((m) => m.type == 'message' && m.text == 'hello from alice'),
    15000,
  );
  check('client received broadcast of its own message', gotEcho);

  // ---- client 2: wrong password --------------------------------------------
  print('[..] Connecting second client with WRONG password...');
  final badClient = ChatClient(
    socksHost: '127.0.0.1',
    socksPort: socksPort,
    targetHost: onion,
    targetPort: 80,
  );
  await badClient.connect(password: 'nope-wrong');
  final gotAuthFailed = await waitFor(badClient.onAuthFailed, 30000);
  check('wrong password -> auth_failed', gotAuthFailed);

  // ---- system notices ------------------------------------------------------
  final hostAnnounce = await waitForValue(
    () => hostMessages.any((m) => m.type == 'system'),
    15000,
  );
  check('system notices flow to host logs', hostAnnounce);

  // ---- edit / delete (silent, own-messages-only) ---------------------------
  print('[..] Testing edit / delete...');
  final aliceMsgId =
      hostMessages.lastWhere((m) => m.type == 'message').id;
  final clientOnEdit = <ChatMessage>[];
  client.onEdit.listen(clientOnEdit.add);
  client.sendEdit(aliceMsgId, 'edited by alice');
  final gotEdit = await waitForValue(
    () => clientOnEdit
        .any((m) => m.id == aliceMsgId && m.text == 'edited by alice'),
    15000,
  );
  check('edit reaches everyone (same id, new text)', gotEdit);

  final clientOnDelete = <String>[];
  client.onDelete.listen(clientOnDelete.add);
  client.sendDelete(aliceMsgId);
  final gotDelete =
      await waitForValue(() => clientOnDelete.contains(aliceMsgId), 15000);
  check('delete reaches everyone', gotDelete);

  // ---- host room controls --------------------------------------------------
  print('[..] Testing host room controls...');
  final clientOnDeleteAllMedia = <void>[];
  client.onDeleteAllMedia.listen(clientOnDeleteAllMedia.add);
  final clientOnDeleteAllMessages = <void>[];
  client.onDeleteAllMessages.listen(clientOnDeleteAllMessages.add);

  host.deleteAllMedia();
  final gotDeleteAllMedia =
      await waitForValue(() => clientOnDeleteAllMedia.isNotEmpty, 15000);
  check('host "delete all media" reaches clients', gotDeleteAllMedia);

  host.deleteAllMessages();
  final gotDeleteAllMessages =
      await waitForValue(() => clientOnDeleteAllMessages.isNotEmpty, 15000);
  check('host "delete all messages" reaches clients', gotDeleteAllMessages);

  host.disconnectEveryone();
  final gotDisconnected = await waitFor(client.onClose, 15000);
  check('host "disconnect everyone" closes client sockets', gotDisconnected);

  // cleanup
  await badClient.close();
  await client.close();
  await host.stop();
  torProc.kill();
  await tmpDir.delete(recursive: true);

  print('');
  print('\x1b[1mResults: $passed passed, $failed failed\x1b[0m');
  exit(failed == 0 ? 0 : 1);
}

Future<bool> waitFor(Stream<void> stream, int ms) async {
  final completer = Completer<void>();
  final sub = stream.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  try {
    await completer.future.timeout(Duration(milliseconds: ms));
    return true;
  } catch (_) {
    return false;
  } finally {
    sub.cancel();
  }
}

Future<bool> waitForValue(bool Function() predicate, int ms) async {
  final deadline = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return predicate();
}
