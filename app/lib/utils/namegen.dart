import 'dart:math';

/// Generates human-friendly, memorable namecodes like `quiet-octopus-42`.
class NameGen {
  NameGen._();

  static const _adjectives = [
    'quiet', 'swift', 'cosmic', 'brave', 'hidden', 'silent', 'golden',
    'neon', 'vivid', 'lucky', 'crimson', 'frozen', 'jolly', 'mellow',
    'noble', 'onion', 'purple', 'radiant', 'shadow', 'amber', 'velvet',
    'wandering', 'sunny', 'misty', 'echoing', 'lunar', 'solar', 'tiny',
    'violet', 'bright', 'clever', 'daring', 'epic', 'fierce', 'glowing',
    'heroic', 'iron', 'jade', 'kingly', 'lively', 'magic', 'nifty',
    'orange', 'pearl', 'quaint', 'royal', 'sable', 'titan', 'united',
  ];

  static const _nouns = [
    'panda', 'falcon', 'octopus', 'tiger', 'wolf', 'dragon', 'raccoon',
    'otter', 'lion', 'fox', 'bear', 'eagle', 'owl', 'phoenix', 'turtle',
    'penguin', 'shark', 'whale', 'koala', 'lemur', 'bison', 'cheetah',
    'deer', 'ferret', 'gecko', 'heron', 'ibex', 'jaguar', 'kiwi', 'llama',
    'manta', 'newt', 'orca', 'puma', 'quokka', 'rhino', 'stork', 'tapir',
    'urchin', 'viper', 'walrus', 'yak', 'zebra', 'badger', 'cougar',
    'dolphin', 'elk', 'flamingo', 'gazelle', 'hedgehog',
  ];

  static final _rng = Random.secure();

  static String generate() {
    final a = _adjectives[_rng.nextInt(_adjectives.length)];
    final n = _nouns[_rng.nextInt(_nouns.length)];
    final num = _rng.nextInt(90) + 10;
    return '$a-$n-$num';
  }

  static String randomPassword({int length = 8}) {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return String.fromCharCodes(List.generate(
      length,
      (_) => chars.codeUnitAt(_rng.nextInt(chars.length)),
    ));
  }
}
