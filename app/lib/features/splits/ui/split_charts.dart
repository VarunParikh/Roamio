import 'dart:math';

import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/splits/domain/category_shares.dart';

// Chartreuse is for the one primary button, not for graphs.
const List<Color> _sliceColors = [
  RoamioColors.cobalt,
  RoamioColors.mint,
  RoamioColors.muted,
  RoamioColors.slate,
];

/// The narrowest a slice's share of the bar can be, so a tiny category shows.
const _minSliceFlex = 3;

/// Spend by category (spec UC-25): the total, a coloured bar and a 2×2 legend.
/// The bar is only a picture: every number is in the legend's text.
class SpendByCategory extends StatelessWidget {
  const new({
    required this.total,
    required this.shares,
    required this.nameOf,
    required this.moneyOf,
    this.title = 'Spend by category',
    this.totalLabel = 'Total spend',
    super.key,
  });

  final String title;
  final String totalLabel;
  final String total;
  final List<CategoryShare> shares;

  /// A category's name, from its id.
  final String Function(String id) nameOf;
  final String Function(int minor) moneyOf;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = [
      for (var i = 0; i < shares.length; i += 2)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = i; j < i + 2; j++)
              Expanded(
                child: j < shares.length
                    ? CategoryLegendEntry(
                        color: _sliceColors[j],
                        name: switch (shares[j].category) {
                          final id? => nameOf(id),
                          null => 'Other',
                        },
                        percent: shares[j].percent,
                        money: moneyOf(shares[j].minor),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: text.headlineSmall),
        const SizedBox(height: 2),
        Text(
          '$totalLabel $total',
          style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: ClipRRect(
                    key: const ValueKey('category-bar'),
                    borderRadius: BorderRadius.circular(RoamioRadii.full),
                    child: SizedBox(
                      height: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 2,
                        children: [
                          for (final (i, s) in shares.indexed)
                            Expanded(
                              key: ValueKey('category-slice-$i'),
                              flex: max(s.percent, _minSliceFlex),
                              child: ColoredBox(color: _sliceColors[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final row in rows) ...[const SizedBox(height: 16), row],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One slice's dot, name, percentage and amount, read as one by TalkBack.
class CategoryLegendEntry extends StatelessWidget {
  const new({
    required this.color,
    required this.name,
    required this.percent,
    required this.money,
    super.key,
  });

  final Color color;
  final String name;
  final int percent;
  final String money;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: RoamioColors.slate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('$percent%', style: text.headlineSmall),
            Text(
              money,
              style: text.bodySmall?.copyWith(color: RoamioColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spending as a bar per day, latest at the right with earlier days a swipe
/// away. The latest stands out in blue, with its day and amount under the
/// chart.
/// Without [visibleDays], tapping a bar moves that to the bar tapped; with it,
/// each bar is a [visibleDays]th of the width, too narrow to tap.
class DayBars extends StatefulWidget {
  const new({
    required this.days,
    required this.amountOf,
    required this.dayName,
    required this.moneyOf,
    this.visibleDays,
    super.key,
  });

  /// Oldest first; must not be empty.
  final List<DateTime> days;
  final int Function(DateTime day) amountOf;

  /// "Tue, 27 Oct 2026".
  final String Function(DateTime day) dayName;
  final String Function(int minor) moneyOf;
  final int? visibleDays;

  @override
  State<DayBars> createState() => _DayBarsState();
}

class _DayBarsState extends State<DayBars> {
  DateTime? _picked;

  static const _barsHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = widget.days;
    final latest = days.last;
    final selected = days.contains(_picked) ? _picked! : latest;
    final top = days.map(widget.amountOf).reduce(max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('day-bars'),
          height: _barsHeight + 28,
          child: LayoutBuilder(
            builder: (context, box) => ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemExtent: switch (widget.visibleDays) {
                final n? => box.maxWidth / n,
                null => 48,
              },
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[days.length - 1 - i];
                final amount = widget.amountOf(day);
                final interactive = widget.visibleDays == null;
                final bar = Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      // A day with spending always shows, however small.
                      height: amount <= 0
                          ? 2
                          : max(4, _barsHeight * amount / top),
                      decoration: BoxDecoration(
                        color: day == selected
                            ? RoamioColors.cobalt
                            : amount <= 0
                            ? RoamioColors.hairline
                            : RoamioColors.muted,
                        borderRadius: BorderRadius.circular(RoamioRadii.sm),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${day.day}', style: text.bodySmall),
                  ],
                );
                return Semantics(
                  key: ValueKey('day-${_iso(day)}'),
                  container: true,
                  button: interactive,
                  selected: day == selected,
                  label: '${widget.dayName(day)}: ${widget.moneyOf(amount)}',
                  onTap: interactive
                      ? () => setState(() => _picked = day)
                      : null,
                  excludeSemantics: true,
                  child: interactive
                      ? InkWell(
                          borderRadius: BorderRadius.circular(RoamioRadii.sm),
                          onTap: () => setState(() => _picked = day),
                          child: bar,
                        )
                      : bar,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.dayName(selected)} · '
          '${widget.moneyOf(widget.amountOf(selected))}',
          style: text.bodyMedium,
        ),
      ],
    );
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
