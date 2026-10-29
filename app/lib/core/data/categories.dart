import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(Category.fromJson)
      .toList();
});
