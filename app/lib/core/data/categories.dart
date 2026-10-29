import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/config/remote_config.dart';

/// One of the 10 tab categories bundled in `assets/data/categories.json`.
class Category {
  const new({required this.id, required this.name, required this.emoji});

  factory fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
  );

  final String id;
  final String name;
  final String emoji;
}

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/categories.json');
  return orderCategories(
    (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList(),
    ref.watch(appConfigProvider).categoryOrder,
  );
});

/// Remote Config `category_order`: those ids first, in that order, then
/// the rest as bundled. Unknown ids are skipped.
List<Category> orderCategories(List<Category> all, List<String> first) {
  final byId = {for (final c in all) c.id: c};
  final front = [for (final id in first) ?byId[id]];
  return [...front, ...all.where((c) => !front.contains(c))];
}
