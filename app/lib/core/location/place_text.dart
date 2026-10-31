import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/location/location_service.dart';

/// Where a tab happened, in words: its place name once known, otherwise its
/// coordinates.
class PlaceText extends ConsumerWidget {
  const new({required this.point, super.key});

  final MapPoint point;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(placeNameProvider((point.lat, point.lng))).value;
    return Text(
      '📍 ${name ?? point.label}',
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
