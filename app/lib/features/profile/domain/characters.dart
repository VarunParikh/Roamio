/// The sections of the character picker.
enum CharacterGroup {
  travellers('Travellers'),
  fantasy('Fantasy'),
  animals('Animals');

  new(this.title);

  final String title;
}

/// A display picture a person can choose (spec UC-28). The images ship with
/// the app, on an opaque white background; profiles store only the [id].
class Character {
  const new(this.id, this.label, this.group);

  final String id;

  /// What TalkBack reads out.
  final String label;
  final CharacterGroup group;

  String get asset => 'assets/characters/$id.webp';
}

const CharacterGroup _t = CharacterGroup.travellers;
const CharacterGroup _f = CharacterGroup.fantasy;
const CharacterGroup _a = CharacterGroup.animals;

/// Ids are saved on profiles, so never rename or reuse one.
const List<Character> characters = [
  Character('traveller_01', 'Traveller 1', _t),
  Character('traveller_02', 'Traveller 2', _t),
  Character('traveller_03', 'Traveller 3', _t),
  Character('traveller_04', 'Traveller 4', _t),
  Character('traveller_05', 'Traveller 5', _t),
  Character('traveller_06', 'Traveller 6', _t),
  Character('traveller_07', 'Traveller 7', _t),
  Character('traveller_08', 'Traveller 8', _t),
  Character('traveller_09', 'Traveller 9', _t),
  Character('traveller_10', 'Traveller 10', _t),
  Character('traveller_11', 'Traveller 11', _t),
  Character('traveller_12', 'Traveller 12', _t),
  Character('traveller_13', 'Traveller 13', _t),
  Character('traveller_14', 'Traveller 14', _t),
  Character('traveller_15', 'Traveller 15', _t),
  Character('traveller_16', 'Traveller 16', _t),
  Character('traveller_17', 'Traveller 17', _t),
  Character('astronaut', 'Astronaut', _f),
  Character('robot', 'Robot', _f),
  Character('alien', 'Alien', _f),
  Character('dinosaur', 'Dinosaur', _f),
  Character('unicorn', 'Unicorn', _f),
  Character('cool_smiley', 'Smiley in sunglasses', _f),
  Character('cowboy', 'Cowboy', _f),
  Character('witch', 'Witch', _f),
  Character('samurai', 'Samurai', _f),
  Character('ninja', 'Ninja', _f),
  Character('monkey', 'Monkey', _a),
  Character('sloth', 'Sloth', _a),
  Character('owl', 'Owl', _a),
  Character('bunny', 'Bunny', _a),
  Character('shiba', 'Shiba', _a),
  Character('husky', 'Husky', _a),
  Character('raccoon', 'Raccoon', _a),
  Character('red_panda', 'Red panda', _a),
  Character('lion', 'Lion', _a),
  Character('giraffe', 'Giraffe', _a),
  Character('panda', 'Panda', _a),
  Character('fox', 'Fox', _a),
  Character('bear', 'Bear', _a),
  Character('frog', 'Frog', _a),
  Character('cat', 'Cat', _a),
  Character('dog', 'Dog', _a),
  Character('koala', 'Koala', _a),
  Character('penguin', 'Penguin', _a),
  Character('elephant', 'Elephant', _a),
  Character('tiger', 'Tiger', _a),
];

/// How many characters a default can be. Fixed, so adding characters to the
/// list never changes anyone's default.
const _defaultPool = 47;

/// The character someone has until they choose: always the same for an id.
/// Not Dart's `hashCode`, which can differ between runs.
Character defaultCharacterFor(String uid) {
  var hash = 0;
  for (final unit in uid.codeUnits) {
    hash = (hash * 31 + unit) & 0x3fffffff;
  }
  return characters[hash % _defaultPool];
}

/// Who [uid] appears as: their chosen character, or else their default.
Character characterFor(String uid, String? chosenId) =>
    characterById(chosenId) ?? defaultCharacterFor(uid);

/// The character with this id; null when there's none or this version of the
/// app doesn't know it (their default is shown instead).
Character? characterById(String? id) {
  for (final c in characters) {
    if (c.id == id) return c;
  }
  return null;
}
