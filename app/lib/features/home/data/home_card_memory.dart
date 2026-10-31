import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Whether Home's adventure card was left expanded (spec UC-5). It stays on
/// the phone.
abstract interface class HomeCardMemory {
  Future<bool> readExpanded();
  Future<void> writeExpanded({required bool expanded});
}

/// [HomeCardMemory] as a JSON file in the app's support folder. Failing to
/// read or write stays quiet: the worst case is the card starting collapsed.
class FileHomeCardMemory implements HomeCardMemory {
  new({this._folder = getApplicationSupportDirectory});

  final Future<Directory> Function() _folder;

  Future<File> get _file async =>
      File('${(await _folder()).path}/home_card.json');

  @override
  Future<bool> readExpanded() async {
    try {
      final data = jsonDecode(await (await _file).readAsString()) as Map;
      return data['expanded'] == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> writeExpanded({required bool expanded}) async {
    try {
      await (await _file).writeAsString(jsonEncode({'expanded': expanded}));
    } on Object {
      // Next time it starts collapsed.
    }
  }
}

final homeCardMemoryProvider = Provider<HomeCardMemory>(
  (ref) =>
      throw UnimplementedError('homeCardMemoryProvider must be overridden'),
);
