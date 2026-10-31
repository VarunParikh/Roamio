import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/auth/data/auth_service.dart';

/// Renews [todayProvider] when the app comes back to the front and at each
/// midnight, so days left, trip status and tab dates follow the real day.
class TodayRefresher extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TodayRefresher> createState() => _TodayRefresherState();
}

class _TodayRefresherState extends ConsumerState<TodayRefresher>
    with WidgetsBindingObserver {
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _renew();
  }

  void _renew() {
    ref.invalidate(todayProvider);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = ref.read(clockProvider)();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(nextMidnight.difference(now), _renew);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
